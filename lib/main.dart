import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:with_platform/core/auth/auth_repository.dart';
import 'package:with_platform/core/services/donation_service.dart';
import 'package:with_platform/core/services/with_pay_service.dart';
import 'package:with_platform/features/splash/splash_screen.dart';
import 'package:with_platform/core/navigation/app_route_observer.dart';
import 'package:with_platform/shared/widgets/app_error_page.dart';
import 'package:with_platform/shared/widgets/approved_posts_feed.dart';
import 'package:with_platform/features/auth/login_screen.dart';
import 'package:with_platform/features/main/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[SYSTEM] : Firebase 초기화 완료');
  } catch (e) {
    debugPrint('[SYSTEM] : Firebase 초기화 실패 - $e');
    // Firebase 초기화 실패 시에도 앱은 계속 실행 (에러 페이지 표시 가능)
  }

  // Firestore 설정: 웹 환경에서 캐시 충돌 방지
  // persistenceEnabled: false로 설정하여 웹 환경에서 캐시 충돌 방지
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false, // 웹 환경에서 캐시 충돌 방지
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    debugPrint('[SYSTEM] : Firestore 설정 완료 - persistenceEnabled: false (웹 환경 캐시 충돌 방지)');
  } catch (e) {
    debugPrint('[SYSTEM] : Firestore 설정 실패 - $e');
    // 설정 실패 시에도 기본 설정으로 계속 진행
  }

  // WITH Pay 서비스 초기화 (스트림 중복 구독 방지)
  try {
    initializeWithPayService();
    debugPrint('[SYSTEM] : WITH Pay 서비스 초기화 완료');
  } catch (e) {
    debugPrint('[SYSTEM] : WITH Pay 서비스 초기화 실패 - $e');
  }
  
  // 피드 스트림 초기화 (스트림 중복 구독 방지)
  try {
    initializeApprovedPostsStream();
    debugPrint('[SYSTEM] : 피드 스트림 초기화 완료');
  } catch (e) {
    debugPrint('[SYSTEM] : 피드 스트림 초기화 실패 - $e');
    // 초기화 실패 시 재시도
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      initializeApprovedPostsStream();
      debugPrint('[SYSTEM] : 피드 스트림 초기화 재시도 완료');
    } catch (e2) {
      debugPrint('[SYSTEM] : 피드 스트림 초기화 재시도 실패 - $e2');
    }
  }
  
  try {
    await AuthRepository.instance.loadCurrentUser();
    debugPrint('[SYSTEM] : AuthRepository 사용자 로드 완료');
  } catch (e) {
    debugPrint('[SYSTEM] : AuthRepository 사용자 로드 실패 - $e');
  }

  ensurePlatformStats().then((_) {
    debugPrint('[SYSTEM] : platform_stats 초기화 완료');
  }).catchError((e) {
    debugPrint('[SYSTEM] : platform_stats 초기화 실패 $e');
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // AuthRepository의 상태 변화를 감지하여 UI 업데이트
    AuthRepository.instance.addListener(_onAuthStateChanged);
    debugPrint('🚩 [LOG] MyApp 초기화 완료 - AuthRepository 리스너 등록');
  }

  @override
  void dispose() {
    AuthRepository.instance.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    debugPrint('🚩 [LOG] MyApp - AuthRepository 상태 변화 감지됨. 현재 유저: ${AuthRepository.instance.currentUser?.id ?? "null"}');
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WITH Platform',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: true,
      ),
      // 최상단 분기: 로그아웃 시 AuthRepository의 상태 변화를 감지하여 자동으로 UI 업데이트
      // 유저가 있든 없든 SplashScreen으로 이동 (비로그인 상태의 MainScreen이 진짜 초기 상태)
      home: ListenableBuilder(
        listenable: AuthRepository.instance,
        builder: (context, _) {
          final user = AuthRepository.instance.currentUser;
          debugPrint('🚩 [LOG] MyApp ListenableBuilder - 유저 상태: ${user?.id ?? "null"}');
          
          // 유저가 있든 없든 SplashScreen으로 이동 (SplashScreen이 MainScreen으로 전환)
          // 비로그인 상태의 MainScreen이 우리 앱의 진짜 초기 상태
          debugPrint('🚩 [LOG] MyApp - SplashScreen으로 이동 (유저: ${user?.id ?? "null"})');
          return const SplashScreen();
        },
      ),
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => const AppErrorPage(message: '잘못된 경로입니다.'),
        );
      },
    );
  }
}