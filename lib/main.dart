import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_config.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Khởi tạo Firebase nếu đã cấu hình. Nếu lỗi → vẫn chạy app ở chế độ offline.
  if (kFirebaseEnabled) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      AuthService.instance.markAvailable();
    } catch (e) {
      debugPrint('Firebase init failed, chạy chế độ offline: $e');
    }
  }

  runApp(const CaroGameApp());
}

class CaroGameApp extends StatelessWidget {
  const CaroGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cờ Caro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
