import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/online_models.dart';
import 'auth_service.dart';

/// Kết bạn bằng mã, danh sách bạn bè + hiện diện, và lời mời chơi.
class FriendService {
  FriendService._();
  static final FriendService instance = FriendService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  UserProfile get _me => AuthService.instance.current!;

  CollectionReference<Map<String, dynamic>> _friendsOf(String uid) =>
      _users.doc(uid).collection('friends');
  CollectionReference<Map<String, dynamic>> _invitesOf(String uid) =>
      _users.doc(uid).collection('invites');

  /// Kết bạn bằng mã. Trả về hồ sơ bạn nếu thành công, null nếu không tìm thấy.
  Future<UserProfile?> addFriendByCode(String code) async {
    final c = code.trim().toUpperCase();
    if (c.isEmpty || c == _me.friendCode) return null;

    final q = await _users
        .where('friendCode', isEqualTo: c)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;

    final friend = UserProfile.fromDoc(q.docs.first);
    final batch = _db.batch();
    batch.set(_friendsOf(_me.uid).doc(friend.uid), {
      'name': friend.displayName,
      'addedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_friendsOf(friend.uid).doc(_me.uid), {
      'name': _me.displayName,
      'addedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return friend;
  }

  /// Danh sách uid bạn bè (real-time).
  Stream<List<String>> watchFriendIds() => _friendsOf(_me.uid)
      .snapshots()
      .map((s) => s.docs.map((d) => d.id).toList());

  /// Theo dõi hồ sơ (gồm trạng thái online) của một người dùng.
  Stream<UserProfile> watchUser(String uid) =>
      _users.doc(uid).snapshots().where((s) => s.exists).map(UserProfile.fromDoc);

  // ---- Lời mời chơi ------------------------------------------------------

  Future<void> sendInvite(String friendUid, String matchId) async {
    await _invitesOf(friendUid).add({
      'matchId': matchId,
      'fromUid': _me.uid,
      'fromName': _me.displayName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<GameInvite>> watchInvites() => _invitesOf(_me.uid)
      .snapshots()
      .map((s) => s.docs.map(GameInvite.fromDoc).toList());

  Future<void> deleteInvite(String inviteId) async {
    try {
      await _invitesOf(_me.uid).doc(inviteId).delete();
    } catch (_) {}
  }
}
