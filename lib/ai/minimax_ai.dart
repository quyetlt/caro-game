import 'package:flutter/foundation.dart';
import '../models/game_state.dart';

/// Độ khó của AI. Ảnh hưởng tới độ sâu tìm kiếm và quỹ thời gian suy nghĩ.
enum AIDifficulty { easy, medium, hard }

/// Engine Gomoku cải tiến: minimax + cắt tỉa alpha-beta với
/// - Đào sâu lặp (iterative deepening) + giới hạn thời gian → luôn phản hồi nhanh.
/// - Sắp xếp nước đi (move ordering) để cắt tỉa hiệu quả.
/// - Hàm lượng giá theo "đường chạy" (run) có phân biệt thế mở/bị chặn.
/// - Bắt nước thắng ngay & chặn nước thua ngay (fast-path).
/// - Chạy trong isolate qua [getBestMove] nên KHÔNG làm đơ giao diện.
class MinimaxAI {
  final Player aiPlayer;
  final Player humanPlayer;
  final AIDifficulty difficulty;

  MinimaxAI({required this.aiPlayer, this.difficulty = AIDifficulty.hard})
      : humanPlayer = aiPlayer == Player.X ? Player.O : Player.X;

  /// Tính nước đi tốt nhất trong một isolate riêng (không chặn UI thread).
  Future<List<int>> getBestMove(List<List<Player?>> board) {
    final size = GameState.boardSize;
    // Chuyển bàn cờ sang mảng phẳng int để gửi qua isolate cho nhẹ & nhanh.
    // 0 = trống, 1 = AI, 2 = người.
    final flat = Uint8List(size * size);
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final cell = board[r][c];
        flat[r * size + c] =
            cell == null ? 0 : (cell == aiPlayer ? 1 : 2);
      }
    }
    return compute(
      _solve,
      _AIRequest(board: flat, size: size, difficulty: difficulty),
    );
  }
}

// ---------------------------------------------------------------------------
// Phần dưới đây chạy trong isolate. Dùng int thay vì enum cho gọn & nhanh.
// 0 = trống, 1 = AI, 2 = người.
// ---------------------------------------------------------------------------

class _AIRequest {
  final Uint8List board;
  final int size;
  final AIDifficulty difficulty;
  const _AIRequest({
    required this.board,
    required this.size,
    required this.difficulty,
  });
}

const int _ai = 1;
const int _human = 2;

// Điểm cho các thế cờ.
const int _five = 10000000;
const int _openFour = 500000; // _ X X X X _  → gần như thắng chắc
const int _four = 50000; // X X X X _   → buộc đối thủ phải chặn
const int _openThree = 20000; // _ X X X _    → đe doạ tạo open four
const int _closedThree = 1000;
const int _openTwo = 200;
const int _closedTwo = 20;

const int _winThreshold = _five ~/ 2;

List<int> _solve(_AIRequest req) {
  final engine = _Engine(req.size, req.difficulty);
  return engine.bestMove(req.board);
}

class _Engine {
  final int size;
  final AIDifficulty difficulty;
  final Stopwatch _sw = Stopwatch();
  late final int _maxDepth;
  late final int _timeBudgetMs;
  late final int _branching;

  _Engine(this.size, this.difficulty) {
    switch (difficulty) {
      case AIDifficulty.easy:
        _maxDepth = 2;
        _timeBudgetMs = 250;
        _branching = 8;
      case AIDifficulty.medium:
        _maxDepth = 4;
        _timeBudgetMs = 600;
        _branching = 10;
      case AIDifficulty.hard:
        _maxDepth = 6;
        _timeBudgetMs = 1000;
        _branching = 12;
    }
  }

  int _idx(int r, int c) => r * size + c;
  bool _inBounds(int r, int c) => r >= 0 && r < size && c >= 0 && c < size;

  List<int> bestMove(Uint8List board) {
    _sw.start();

    final candidates = _candidates(board);
    if (candidates.isEmpty) {
      final mid = size ~/ 2;
      return [mid, mid];
    }

    // Fast-path 1: nếu AI có nước thắng ngay → đánh luôn.
    for (final m in candidates) {
      board[m] = _ai;
      final win = _makesFive(board, m, _ai);
      board[m] = 0;
      if (win) return [m ~/ size, m % size];
    }

    // Fast-path 2: nếu đối thủ sắp thắng → chặn (nếu nhiều, search sẽ chọn tốt nhất).
    final blocking = <int>[];
    for (final m in candidates) {
      board[m] = _human;
      final win = _makesFive(board, m, _human);
      board[m] = 0;
      if (win) blocking.add(m);
    }
    if (blocking.length == 1) {
      final m = blocking.first;
      return [m ~/ size, m % size];
    }

    // Đào sâu lặp với quỹ thời gian: luôn giữ kết quả của độ sâu hoàn tất gần nhất.
    int bestIdx = candidates.first;
    for (int depth = 2; depth <= _maxDepth; depth += 2) {
      final ordered = _ordered(board, candidates, _ai);
      int bestScore = -_five * 2;
      int localBest = ordered.first;
      bool aborted = false;

      for (final m in ordered) {
        board[m] = _ai;
        final score =
            _minimax(board, depth - 1, false, -_five * 2, _five * 2);
        board[m] = 0;
        if (score > bestScore) {
          bestScore = score;
          localBest = m;
        }
        if (_sw.elapsedMilliseconds > _timeBudgetMs) {
          aborted = true;
          break;
        }
      }

      if (!aborted) bestIdx = localBest;
      if (aborted || bestScore >= _winThreshold) break;
      if (_sw.elapsedMilliseconds > _timeBudgetMs) break;
    }

    return [bestIdx ~/ size, bestIdx % size];
  }

  int _minimax(Uint8List board, int depth, bool isMax, int alpha, int beta) {
    final score = _evaluate(board);
    if (score.abs() >= _winThreshold || depth == 0) return score;
    if (_sw.elapsedMilliseconds > _timeBudgetMs) return score;

    final candidates = _candidates(board);
    if (candidates.isEmpty) return score;
    final player = isMax ? _ai : _human;
    final ordered = _ordered(board, candidates, player);

    if (isMax) {
      int best = -_five * 2;
      for (final m in ordered) {
        board[m] = _ai;
        final val = _minimax(board, depth - 1, false, alpha, beta);
        board[m] = 0;
        if (val > best) best = val;
        if (best > alpha) alpha = best;
        if (beta <= alpha) break;
      }
      return best;
    } else {
      int best = _five * 2;
      for (final m in ordered) {
        board[m] = _human;
        final val = _minimax(board, depth - 1, true, alpha, beta);
        board[m] = 0;
        if (val < best) best = val;
        if (best < beta) beta = best;
        if (beta <= alpha) break;
      }
      return best;
    }
  }

  /// Các ô trống nằm trong bán kính 2 quanh một quân đã đặt.
  List<int> _candidates(Uint8List board) {
    const range = 2;
    final seen = <int>{};
    final result = <int>[];
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (board[_idx(r, c)] == 0) continue;
        for (int dr = -range; dr <= range; dr++) {
          for (int dc = -range; dc <= range; dc++) {
            final nr = r + dr;
            final nc = c + dc;
            if (!_inBounds(nr, nc)) continue;
            final ni = _idx(nr, nc);
            if (board[ni] != 0) continue;
            if (seen.add(ni)) result.add(ni);
          }
        }
      }
    }
    return result;
  }

  /// Sắp xếp ứng viên theo điểm cục bộ giảm dần và lấy top [_branching].
  List<int> _ordered(Uint8List board, List<int> candidates, int player) {
    final opp = player == _ai ? _human : _ai;
    final scored = candidates.map((m) {
      final r = m ~/ size;
      final c = m % size;
      // Cân nhắc cả tấn công (player) lẫn phòng thủ (chặn opp).
      final atk = _localScore(board, r, c, player);
      final def = _localScore(board, r, c, opp);
      return MapEntry(m, atk > def ? atk : def);
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final n = scored.length < _branching ? scored.length : _branching;
    return [for (int i = 0; i < n; i++) scored[i].key];
  }

  /// Điểm khi đặt [player] vào (r,c): xét 4 đường đi qua ô đó.
  int _localScore(Uint8List board, int r, int c, int player) {
    const dirs = [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, -1],
    ];
    board[_idx(r, c)] = player;
    int total = 0;
    for (final d in dirs) {
      total += _runScoreAt(board, r, c, d[0], d[1], player);
    }
    board[_idx(r, c)] = 0;
    return total;
  }

  /// Tính điểm của đường chạy chứa (r,c) theo hướng (dr,dc) cho [player].
  int _runScoreAt(Uint8List board, int r, int c, int dr, int dc, int player) {
    int len = 1;
    // đếm về phía trước
    int rr = r + dr, cc = c + dc;
    while (_inBounds(rr, cc) && board[_idx(rr, cc)] == player) {
      len++;
      rr += dr;
      cc += dc;
    }
    final afterOpen = _inBounds(rr, cc) && board[_idx(rr, cc)] == 0;
    // đếm về phía sau
    rr = r - dr;
    cc = c - dc;
    while (_inBounds(rr, cc) && board[_idx(rr, cc)] == player) {
      len++;
      rr -= dr;
      cc -= dc;
    }
    final beforeOpen = _inBounds(rr, cc) && board[_idx(rr, cc)] == 0;
    final openEnds = (afterOpen ? 1 : 0) + (beforeOpen ? 1 : 0);
    return _runScore(len, openEnds);
  }

  /// Lượng giá toàn bàn = điểm AI - điểm người.
  int _evaluate(Uint8List board) {
    return _scoreFor(board, _ai) - _scoreFor(board, _human);
  }

  /// Tổng điểm các đường chạy của [player] trên toàn bàn.
  int _scoreFor(Uint8List board, int player) {
    const dirs = [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, -1],
    ];
    int total = 0;
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (board[_idx(r, c)] != player) continue;
        for (final d in dirs) {
          final dr = d[0], dc = d[1];
          // Chỉ tính từ điểm đầu của đường chạy để tránh đếm trùng.
          final pr = r - dr, pc = c - dc;
          if (_inBounds(pr, pc) && board[_idx(pr, pc)] == player) continue;
          int len = 0;
          int rr = r, cc = c;
          while (_inBounds(rr, cc) && board[_idx(rr, cc)] == player) {
            len++;
            rr += dr;
            cc += dc;
          }
          final afterOpen = _inBounds(rr, cc) && board[_idx(rr, cc)] == 0;
          final beforeOpen = _inBounds(pr, pc) && board[_idx(pr, pc)] == 0;
          final openEnds = (afterOpen ? 1 : 0) + (beforeOpen ? 1 : 0);
          total += _runScore(len, openEnds);
        }
      }
    }
    return total;
  }

  int _runScore(int len, int openEnds) {
    if (len >= 5) return _five;
    if (openEnds == 0) return 0; // bị chặn hai đầu → vô dụng
    switch (len) {
      case 4:
        return openEnds == 2 ? _openFour : _four;
      case 3:
        return openEnds == 2 ? _openThree : _closedThree;
      case 2:
        return openEnds == 2 ? _openTwo : _closedTwo;
      case 1:
        return openEnds == 2 ? 2 : 1;
    }
    return 0;
  }

  /// Có tạo thành 5 quân liên tiếp qua ô [m] cho [player] không.
  bool _makesFive(Uint8List board, int m, int player) {
    final r = m ~/ size;
    final c = m % size;
    const dirs = [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, -1],
    ];
    for (final d in dirs) {
      final dr = d[0], dc = d[1];
      int count = 1;
      int rr = r + dr, cc = c + dc;
      while (_inBounds(rr, cc) && board[_idx(rr, cc)] == player) {
        count++;
        rr += dr;
        cc += dc;
      }
      rr = r - dr;
      cc = c - dc;
      while (_inBounds(rr, cc) && board[_idx(rr, cc)] == player) {
        count++;
        rr -= dr;
        cc -= dc;
      }
      if (count >= 5) return true;
    }
    return false;
  }
}
