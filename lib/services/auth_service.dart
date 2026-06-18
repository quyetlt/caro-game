import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/online_models.dart';

/// Xác thực ẩn danh + quản lý hồ sơ người chơi.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  bool _available = false;

  /// Firebase đã khởi tạo thành công hay chưa.
  bool get isAvailable => _available;
  void markAvailable() => _available = true;

  UserProfile? _current;
  UserProfile? get current => _current;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _friendCodes =>
      _db.collection('friendCodes');

  static const _kNameKey = 'display_name';

  /// Tên hiển thị đã lưu (nếu có) để gợi ý sẵn.
  Future<String?> savedDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kNameKey);
  }

  /// Đăng nhập ẩn danh và tạo/cập nhật hồ sơ với [displayName].
  Future<UserProfile> signIn(String displayName) async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser ?? (await auth.signInAnonymously()).user!;
    final uid = user.uid;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNameKey, displayName);

    final ref = _users.doc(uid);
    final snap = await ref.get();
    String friendCode;
    if (snap.exists && (snap.data()?['friendCode'] is String)) {
      friendCode = snap.data()!['friendCode'] as String;
    } else {
      friendCode = _generateFriendCode();
    }

    await ref.set({
      'displayName': displayName,
      'friendCode': friendCode,
      'online': true,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Bảng tra cứu công khai để kết bạn bằng mã (rules khóa đọc /users).
    await _friendCodes.doc(friendCode).set({
      'uid': uid,
      'displayName': displayName,
    }, SetOptions(merge: true));

    _current = UserProfile(
      uid: uid,
      displayName: displayName,
      friendCode: friendCode,
      online: true,
    );
    return _current!;
  }

  /// Cập nhật trạng thái online (gọi khi app vào/ra nền).
  Future<void> setOnline(bool online) async {
    final c = _current;
    if (c == null) return;
    await _users.doc(c.uid).set({
      'online': online,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _generateFriendCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // bỏ ký tự dễ nhầm
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
