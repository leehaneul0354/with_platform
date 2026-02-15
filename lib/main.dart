import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:with_platform/core/auth/auth_repository.dart';
import 'package:with_platform/core/services/donation_service.dart';
import 'package:with_platform/features/splash/splash_screen.dart';
import 'package:with_platform/shared/widgets/app_error_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await AuthRepository.instance.loadCurrentUser();

  ensurePlatformStats().then((_) {
    debugPrint('[SYSTEM] : platform_stats 초기화 완료');
  }).catchError((e) {
    debugPrint('[SYSTEM] : platform_stats 초기화 실패 $e');
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WITH Platform',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: true,
      ),
      // CHECK: 페이지 연결성 확인 완료 — 진입점은 Splash → MainScreen(동기화 후 전환)
      home: const SplashScreen(),
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => const AppErrorPage(message: '잘못된 경로입니다.'),
        );
      },
    );
  }
}