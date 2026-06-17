import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_state.dart';
import '../models/online_models.dart';
import 'auth_service.dart';

/// Tạo/tham gia ván & đồng bộ nước đi real-time qua Firestore.
class MatchService {
  MatchService._();
  static final MatchService instance = MatchService._();

  /// Thời gian cho mỗi lượt đi (giây).
  static const int turnSeconds = 30;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _matches =>
      _db.collection('matches');

  UserProfile get _me => AuthService.instance.current!;

  // ---- Tạo ván ----------------------------------------------------------

  Future<String> _createMatch({required String mode, String? roomCode}) async {
    final ref = await _matches.add({
      'mode': mode,
      'roomCode': roomCode,
      'status': MatchStatus.waiting.name,
      'hostUid': _me.uid,
      'hostName': _me.displayName,
      'guestUid': null,
      'guestName': null,
      'moves': <Map<String, dynamic>>[],
      'turn': 'X',
      'winner': null,
      'rematchHost': false,
      'rematchGuest': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Tạo phòng có mã 6 ký tự để mời bạn.
  Future<({String matchId, String code})> createRoom() async {
    final code = _generateRoomCode();
    final id = await _createMatch(mode: 'room', roomCode: code);
    return (matchId: id, code: code);
  }

  /// Tạo ván để mời một người bạn (mode 'friend').
  Future<String> createFriendMatch() => _createMatch(mode: 'friend');

  // ---- Tham gia ván -----------------------------------------------------

  /// Tham gia phòng bằng mã. Trả về matchId, hoặc null nếu không tìm thấy.
  Future<String?> joinRoom(String code) async {
    final q = await _matches
        .where('roomCode', isEqualTo: code.toUpperCase())
        .where('status', isEqualTo: MatchStatus.waiting.name)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    final ok = await _tryJoin(q.docs.first.reference);
    return ok ? q.docs.first.id : null;
  }

  /// Ghép trận ngẫu nhiên: tham gia ván đang chờ, hoặc tạo ván mới rồi chờ.
  Future<String> quickMatch() async {
    final q = await _matches
        .where('mode', isEqualTo: 'random')
        .where('status', isEqualTo: MatchStatus.waiting.name)
        .limit(10)
        .get();
    for (final doc in q.docs) {
      if ((doc.data()['hostUid'] as String?) == _me.uid) continue;
      if (await _tryJoin(doc.reference)) return doc.id;
    }
    return _createMatch(mode: 'random');
  }

  /// Tham gia một ván theo id (dùng khi chấp nhận lời mời).
  Future<bool> joinMatch(String matchId) =>
      _tryJoin(_matches.doc(matchId));

  /// Gắn người chơi hiện tại làm guest trong transaction (chống tranh chấp).
  Future<bool> _tryJoin(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      return await _db.runTransaction<bool>((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return false;
        final m = OnlineMatch.fromDoc(snap);
        if (m.status != MatchStatus.waiting || m.guestUid != null) return false;
        if (m.hostUid == _me.uid) return false;
        tx.update(ref, {
          'guestUid': _me.uid,
          'guestName': _me.displayName,
          'status': MatchStatus.playing.name,
          'turnStartedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
    } catch (_) {
      return false;
    }
  }

  // ---- Theo dõi & đánh ---------------------------------------------------

  Stream<OnlineMatch> watch(String matchId) => _matches
      .doc(matchId)
      .snapshots()
      .where((s) => s.exists)
      .map(OnlineMatch.fromDoc);

  /// Đánh một nước. Tự kiểm tra lượt đi, ô trống, thắng/hòa trong transaction.
  Future<void> makeMove(String matchId, int row, int col) async {
    final ref = _matches.doc(matchId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final m = OnlineMatch.fromDoc(snap);
      if (m.status != MatchStatus.playing) return;

      final mySymbol = m.symbolFor(_me.uid);
      if (mySymbol == null || m.turn != mySymbol) return; // không phải lượt
      if (m.moves.any((mv) => mv.row == row && mv.col == col)) return; // đã có quân

      final moves = [...m.moves, OnlineMove(row, col, mySymbol)];
      final win = _checkWin(moves, row, col, mySymbol);
      final draw = !win && moves.length >= GameState.boardSize * GameState.boardSize;

      tx.update(ref, {
        'moves': moves.map((mv) => mv.toMap()).toList(),
        'turn': mySymbol == 'X' ? 'O' : 'X',
        'winner': win ? mySymbol : (draw ? 'draw' : null),
        'status': (win || draw)
            ? MatchStatus.finished.name
            : MatchStatus.playing.name,
        'turnStartedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Người đang chờ tuyên bố thắng khi đối thủ hết giờ.
  Future<void> claimTimeoutWin(String matchId) async {
    final ref = _matches.doc(matchId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final m = OnlineMatch.fromDoc(snap);
      if (m.status != MatchStatus.playing) return;

      final mySymbol = m.symbolFor(_me.uid);
      if (mySymbol == null || m.turn == mySymbol) return; // chỉ khi tới lượt đối thủ
      final start = m.turnStartedAt;
      if (start == null) return;
      if (DateTime.now().difference(start).inSeconds < turnSeconds) return;

      tx.update(ref, {
        'winner': mySymbol,
        'status': MatchStatus.finished.name,
      });
    });
  }

  /// Yêu cầu chơi lại. Khi cả hai đồng ý → reset bàn cờ.
  Future<void> requestRematch(String matchId) async {
    final ref = _matches.doc(matchId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final m = OnlineMatch.fromDoc(snap);
      final isHost = m.hostUid == _me.uid;
      final hostWants = isHost || m.rematchHost;
      final guestWants = !isHost || m.rematchGuest;

      if (hostWants && guestWants) {
        tx.update(ref, {
          'moves': <Map<String, dynamic>>[],
          'turn': 'X',
          'winner': null,
          'status': MatchStatus.playing.name,
          'rematchHost': false,
          'rematchGuest': false,
          'turnStartedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.update(ref, {
          (isHost ? 'rematchHost' : 'rematchGuest'): true,
        });
      }
    });
  }

  /// Rời ván → đánh dấu bỏ cuộc.
  Future<void> leave(String matchId) async {
    try {
      await _matches.doc(matchId).update({'status': MatchStatus.abandoned.name});
    } catch (_) {}
  }

  // ---- Tiện ích ----------------------------------------------------------

  bool _checkWin(List<OnlineMove> moves, int row, int col, String player) {
    final size = GameState.boardSize;
    final grid = List.generate(size, (_) => List<String?>.filled(size, null));
    for (final mv in moves) {
      grid[mv.row][mv.col] = mv.player;
    }
    const dirs = [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, -1],
    ];
    for (final d in dirs) {
      int count = 1;
      for (final sign in [-1, 1]) {
        int r = row + sign * d[0];
        int c = col + sign * d[1];
        while (r >= 0 &&
            r < size &&
            c >= 0 &&
            c < size &&
            grid[r][c] == player) {
          count++;
          r += sign * d[0];
          c += sign * d[1];
        }
      }
      if (count >= GameState.winCount) return true;
    }
    return false;
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
