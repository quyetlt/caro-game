import '../models/game_state.dart';

class MinimaxAI {
  static const int _maxDepth = 3;
  static const int _win = 1000000;

  final Player aiPlayer;
  final Player humanPlayer;

  MinimaxAI({required this.aiPlayer})
      : humanPlayer = aiPlayer == Player.X ? Player.O : Player.X;

  List<int> getBestMove(List<List<Player?>> board) {
    final candidates = _getCandidates(board);
    if (candidates.isEmpty) {
      return [GameState.boardSize ~/ 2, GameState.boardSize ~/ 2];
    }

    int bestScore = -_win * 2;
    List<int> bestMove = candidates.first;

    for (final move in candidates) {
      board[move[0]][move[1]] = aiPlayer;
      final score = _minimax(board, _maxDepth - 1, false, -_win * 2, _win * 2);
      board[move[0]][move[1]] = null;
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }
    return bestMove;
  }

  int _minimax(List<List<Player?>> board, int depth, bool isMax, int alpha, int beta) {
    final score = _evaluate(board);
    if (score.abs() >= _win || depth == 0) return score;

    final candidates = _getCandidates(board);
    if (candidates.isEmpty) return 0;

    if (isMax) {
      int best = -_win * 2;
      for (final move in candidates) {
        board[move[0]][move[1]] = aiPlayer;
        final val = _minimax(board, depth - 1, false, alpha, beta);
        if (val > best) best = val;
        board[move[0]][move[1]] = null;
        if (best > alpha) alpha = best;
        if (beta <= alpha) break;
      }
      return best;
    } else {
      int best = _win * 2;
      for (final move in candidates) {
        board[move[0]][move[1]] = humanPlayer;
        final val = _minimax(board, depth - 1, true, alpha, beta);
        best = best < val ? best : val;
        board[move[0]][move[1]] = null;
        beta = beta < best ? beta : best;
        if (beta <= alpha) break;
      }
      return best;
    }
  }

  List<List<int>> _getCandidates(List<List<Player?>> board) {
    final Set<String> seen = {};
    final List<List<int>> result = [];
    const range = 2;
    final size = GameState.boardSize;

    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (board[r][c] == null) continue;
        for (int dr = -range; dr <= range; dr++) {
          for (int dc = -range; dc <= range; dc++) {
            final nr = r + dr;
            final nc = c + dc;
            if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
            if (board[nr][nc] != null) continue;
            final key = '$nr,$nc';
            if (!seen.contains(key)) {
              seen.add(key);
              result.add([nr, nc]);
            }
          }
        }
      }
    }
    return result;
  }

  int _evaluate(List<List<Player?>> board) {
    int score = 0;
    final directions = [[0, 1], [1, 0], [1, 1], [1, -1]];
    final size = GameState.boardSize;

    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        for (final dir in directions) {
          score += _scoreLine(board, r, c, dir[0], dir[1]);
        }
      }
    }
    return score;
  }

  int _scoreLine(List<List<Player?>> board, int r, int c, int dr, int dc) {
    final size = GameState.boardSize;
    if (r + dr * 4 >= size || r + dr * 4 < 0) return 0;
    if (c + dc * 4 >= size || c + dc * 4 < 0) return 0;

    int aiCount = 0;
    int humanCount = 0;
    for (int i = 0; i < 5; i++) {
      final cell = board[r + dr * i][c + dc * i];
      if (cell == aiPlayer) {
        aiCount++;
      } else if (cell == humanPlayer) {
        humanCount++;
      }
    }

    if (aiCount > 0 && humanCount > 0) return 0;
    if (aiCount == 5) return _win;
    if (humanCount == 5) return -_win;

    final score = {1: 10, 2: 100, 3: 1000, 4: 10000};
    if (aiCount > 0) return score[aiCount] ?? 0;
    if (humanCount > 0) return -(score[humanCount] ?? 0);
    return 0;
  }
}
