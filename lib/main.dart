import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'package:with_platform/core/navigation/app_navigator.dart';

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

  // Firestore 설정: 웹 환경(kIsWeb)에서만 ca9·b815 방지 (IndexedDB 캐시 충돌)
  if (kIsWeb) {
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      debugPrint('[SYSTEM] : Firestore 설정 - persistenceEnabled: false (웹 ca9/b815 방지)');
    } catch (e) {
      debugPrint('[SYSTEM] : Firestore 설정 실패 - $e');
    }
  }

  // 스트림 순차 로딩: 피드 먼저, 500ms 후 WITH Pay (Firestore 웹 스트림 엔진 충돌 방지)
  try {
    initializeApprovedPostsStream();
    debugPrint('[SYSTEM] : 피드 스트림 초기화 완료');
  } catch (e) {
    debugPrint('[SYSTEM] : 피드 스트림 초기화 실패 - $e');
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      initializeApprovedPostsStream();
      debugPrint('[SYSTEM] : 피드 스트림 초기화 재시도 완료');
    } catch (e2) {
      debugPrint('[SYSTEM] : 피드 스트림 초기화 재시도 실패 - $e2');
    }
  }
  await Future.delayed(const Duration(milliseconds: 500));
  try {
    initializeWithPayService();
    debugPrint('[SYSTEM] : WITH Pay 서비스 초기화 완료');
  } catch (e) {
    debugPrint('[SYSTEM] : WITH Pay 서비스 초기화 실패 - $e');
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
  bool _hasCheckedAuth = false; // 무한 루프 방지: 한 번만 체크
  
  @override
  void initState() {
    super.initState();
    // 초기화가 완료된 후에만 리스너 등록 (무한 루프 방지)
    if (AuthRepository.instance.isInitialized) {
      AuthRepository.instance.addListener(_onAuthStateChanged);
      debugPrint('🚩 [LOG] MyApp 초기화 완료 - AuthRepository 리스너 등록 (이미 초기화됨)');
    } else {
      // 초기화가 안 되어 있으면 초기화 완료 후 리스너 등록
      _waitForInitialization();
    }
  }

  Future<void> _waitForInitialization() async {
    // 초기화가 완료될 때까지 대기 (최대 3초)
    int attempts = 0;
    while (!AuthRepository.instance.isInitialized && attempts < 30) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
    
    if (mounted && AuthRepository.instance.isInitialized) {
      AuthRepository.instance.addListener(_onAuthStateChanged);
      debugPrint('🚩 [LOG] MyApp - AuthRepository 초기화 완료 후 리스너 등록');
      setState(() {}); // UI 업데이트
    }
  }

  @override
  void dispose() {
    AuthRepository.instance.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    // 초기화가 완료된 후에만 상태 변화 반영 (무한 루프 방지)
    if (!AuthRepository.instance.isInitialized) {
      debugPrint('🚩 [LOG] MyApp - 초기화 미완료 상태 변화 무시 (무한 루프 방지)');
      return;
    }
    
    debugPrint('🚩 [LOG] MyApp - AuthRepository 상태 변화 감지됨. 현재 유저: ${AuthRepository.instance.currentUser?.id ?? "null"}');
    if (mounted) {
      setState(() {});
    }
  }

  /// 무한 루프 방지: 인증 상태를 딱 한 번만 체크하는 Stream 생성
  Stream<bool> _createAuthCheckStream() async* {
    if (_hasCheckedAuth) {
      debugPrint('🚩 [LOG] MyApp - 이미 인증 체크 완료, 스킵 (무한 루프 방지)');
      return;
    }
    
    _hasCheckedAuth = true;
    debugPrint('🚩 [LOG] MyApp - 인증 상태 체크 시작 (한 번만 실행)');
    
    try {
      // 초기화가 완료될 때까지 대기
      int attempts = 0;
      while (!AuthRepository.instance.isInitialized && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      
      if (!AuthRepository.instance.isInitialized) {
        debugPrint('🚩 [LOG] MyApp - 초기화 타임아웃, LoginScreen으로 이동');
        yield false; // 에러로 처리하여 LoginScreen으로 이동
        return;
      }
      
      debugPrint('🚩 [LOG] MyApp - 인증 상태 체크 완료');
      yield true; // 성공
    } catch (e) {
      debugPrint('🚩 [LOG] MyApp - 인증 체크 중 에러: $e');
      yield false; // 에러 발생 시 LoginScreen으로 이동
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WITH Platform',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey, // 전역 Navigator Key 설정
      navigatorObservers: [routeObserver],
      // 다국어 지원 설정 (DatePicker 등 위젯에서 필요)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'), // 한국어
        Locale('en', 'US'), // 영어
      ],
      locale: const Locale('ko', 'KR'), // 기본 로케일을 한국어로 설정
      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: true,
        // 한글 폰트 지원 (웹 환경에서 한글 텍스트가 깨지지 않도록)
        fontFamily: null, // 시스템 기본 폰트 사용 (한글 지원)
        textTheme: const TextTheme(
          // 기본 텍스트 테마는 시스템 폰트 사용
        ),
      ),
      // 최상단 분기: 무한 루프 방지를 위해 StreamBuilder로 한 번만 체크
      // 에러 발생 시 LoginScreen으로 보내서 사용자가 수동으로 로그인할 수 있게 탈출구 제공
      home: StreamBuilder<bool>(
        stream: _createAuthCheckStream(),
        builder: (context, snapshot) {
          // 에러 발생 시 LoginScreen으로 이동 (탈출구)
          if (snapshot.hasError) {
            debugPrint('🚩 [LOG] MyApp - 인증 확인 중 에러 발생, LoginScreen으로 이동: ${snapshot.error}');
            return const LoginScreen();
          }
          
          // 로딩 중이면 SplashScreen 표시
          if (!snapshot.hasData) {
            debugPrint('🚩 [LOG] MyApp - 인증 확인 중, SplashScreen 표시');
            return const SplashScreen();
          }
          
          // 초기화 완료 후 화면 결정
          final user = AuthRepository.instance.currentUser;
          debugPrint('🚩 [LOG] MyApp StreamBuilder - 유저 상태: ${user?.id ?? "null"}');
          
          // 유저가 있으면 MainScreen으로, 없으면 SplashScreen으로 (SplashScreen이 최종 결정)
          if (user != null) {
            debugPrint('🚩 [LOG] MyApp - 유저 있음, MainScreen으로 이동');
            return const MainScreen();
          } else {
            debugPrint('🚩 [LOG] MyApp - 유저 없음, SplashScreen으로 이동');
            return const SplashScreen();
          }
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