// PLACEHOLDER — sẽ bị `flutterfire configure` GHI ĐÈ bằng cấu hình thật.
//
// File này chỉ tồn tại để dự án biên dịch được khi chưa cấu hình Firebase.
// Nó chỉ được dùng khi kFirebaseEnabled = true (xem firebase_config.dart).
//
// Cách tạo cấu hình thật:
//   dart pub global activate flutterfire_cli
//   flutterfire configure
// Lệnh trên sẽ thay thế toàn bộ nội dung file này.
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase chưa được cấu hình. Hãy chạy `flutterfire configure` rồi '
      'đặt kFirebaseEnabled = true trong lib/firebase_config.dart.',
    );
  }
}
