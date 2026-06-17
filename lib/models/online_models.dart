import 'package:cloud_firestore/cloud_firestore.dart';

/// Hồ sơ người chơi (lưu ở Firestore: users/{uid}).
class UserProfile {
  final String uid;
  final String displayName;
  final String friendCode;
  final bool online;
  final DateTime? lastSeen;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.friendCode,
    this.online = false,
    this.lastSeen,
  });

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return UserProfile(
      uid: doc.id,
      displayName: (d['displayName'] ?? 'Người chơi') as String,
      friendCode: (d['friendCode'] ?? '') as String,
      online: (d['online'] ?? false) as bool,
      lastSeen: (d['lastSeen'] as Timestamp?)?.toDate(),
    );
  }
}

/// Một nước đi đã đánh.
class OnlineMove {
  final int row;
  final int col;
  final String player; // 'X' hoặc 'O'

  const OnlineMove(this.row, this.col, this.player);

  Map<String, dynamic> toMap() => {'r': row, 'c': col, 'p': player};

  factory OnlineMove.fromMap(Map<String, dynamic> m) =>
      OnlineMove(m['r'] as int, m['c'] as int, m['p'] as String);
}

enum MatchStatus { waiting, playing, finished, abandoned }

/// Một ván đấu online (Firestore: matches/{id}).
class OnlineMatch {
  final String id;
  final String? roomCode;
  final String mode; // 'room' | 'random' | 'friend'
  final MatchStatus status;
  final String? hostUid; // người chơi X (tạo ván)
  final String? hostName;
  final String? guestUid; // người chơi O
  final String? guestName;
  final List<OnlineMove> moves;
  final String turn; // 'X' | 'O'
  final String? winner; // 'X' | 'O' | 'draw' | null
  final bool rematchHost;
  final bool rematchGuest;
  final DateTime? turnStartedAt;

  const OnlineMatch({
    required this.id,
    this.roomCode,
    required this.mode,
    required this.status,
    this.hostUid,
    this.hostName,
    this.guestUid,
    this.guestName,
    this.moves = const [],
    this.turn = 'X',
    this.winner,
    this.rematchHost = false,
    this.rematchGuest = false,
    this.turnStartedAt,
  });

  factory OnlineMatch.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return OnlineMatch(
      id: doc.id,
      roomCode: d['roomCode'] as String?,
      mode: (d['mode'] ?? 'room') as String,
      status: MatchStatus.values.firstWhere(
        (s) => s.name == d['status'],
        orElse: () => MatchStatus.waiting,
      ),
      hostUid: d['hostUid'] as String?,
      hostName: d['hostName'] as String?,
      guestUid: d['guestUid'] as String?,
      guestName: d['guestName'] as String?,
      moves: ((d['moves'] ?? []) as List)
          .map((m) => OnlineMove.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList(),
      turn: (d['turn'] ?? 'X') as String,
      winner: d['winner'] as String?,
      rematchHost: (d['rematchHost'] ?? false) as bool,
      rematchGuest: (d['rematchGuest'] ?? false) as bool,
      turnStartedAt: (d['turnStartedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Người chơi X là host, O là guest. Trả về 'X'/'O' cho [uid].
  String? symbolFor(String uid) {
    if (uid == hostUid) return 'X';
    if (uid == guestUid) return 'O';
    return null;
  }

  String? opponentNameFor(String uid) {
    if (uid == hostUid) return guestName;
    if (uid == guestUid) return hostName;
    return null;
  }

  bool get hasOpponent => hostUid != null && guestUid != null;
}

/// Lời mời chơi (Firestore: users/{uid}/invites/{id}).
class GameInvite {
  final String id;
  final String matchId;
  final String fromUid;
  final String fromName;

  const GameInvite({
    required this.id,
    required this.matchId,
    required this.fromUid,
    required this.fromName,
  });

  factory GameInvite.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return GameInvite(
      id: doc.id,
      matchId: (d['matchId'] ?? '') as String,
      fromUid: (d['fromUid'] ?? '') as String,
      fromName: (d['fromName'] ?? 'Người chơi') as String,
    );
  }
}
