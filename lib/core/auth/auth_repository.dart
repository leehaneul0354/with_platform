import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../constants/firestore_keys.dart';
import '../constants/test_accounts.dart';
import '../constants/assets.dart';
import '../util/birth_date_util.dart';
import '../services/with_pay_service.dart';
import '../../shared/widgets/approved_posts_feed.dart';
import 'user_model.dart';

class AuthRepository extends ChangeNotifier {
  AuthRepository._();
  static final AuthRepository _instance = AuthRepository._();
  static AuthRepository get instance => _instance;

  static const String _keyCurrentUser = 'with_current_user';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _currentUser;
  
  /// 현재 유저 반환 (로그아웃 중이면 무조건 null 반환)
  UserModel? get currentUser {
    if (_isLoggingOut) {
      debugPrint('🚩 [LOG] currentUser getter - 로그아웃 진행 중이므로 null 반환');
      return null;
    }
    return _currentUser;
  }
  
  /// 로그아웃 플래그: 로그아웃 중에는 자동 로그인 로직이 실행되지 않도록 차단
  bool _isLoggingOut = false;
  
  /// 로그아웃 진행 중인지 확인 (외부에서 접근 가능)
  bool get isLoggingOut => _isLoggingOut;
  
  /// 초기화 완료 플래그: 초기화가 끝난 후에는 인증 스트림이 화면을 강제로 전환하지 않도록 방어
  bool _isInitialized = false;
  
  /// 초기화 완료 여부 확인 (외부에서 접근 가능)
  bool get isInitialized => _isInitialized;

  Future<void> loadCurrentUser() async {
    // 로그아웃 중이면 자동 로그인 차단
    if (_isLoggingOut) {
      debugPrint('🚩 [LOG] loadCurrentUser 차단됨 - 로그아웃 진행 중');
      _isInitialized = true; // 초기화는 완료로 표시 (로그아웃 중이어도)
      return;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_keyCurrentUser);
      
      // 데이터가 없으면 즉시 종료하고 메모리도 null로 설정 (이전 값 복구 방지)
      if (json == null || json.isEmpty) {
        debugPrint('🚩 [LOG] loadCurrentUser - SharedPreferences에 유저 데이터 없음, 메모리 캐시 null로 설정');
        _currentUser = null;
        _isInitialized = true; // 초기화 완료
        return;
      }
      
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) {
        debugPrint('🚩 [LOG] loadCurrentUser - 잘못된 데이터 형식, 메모리 캐시 null로 설정');
        _currentUser = null;
        _isInitialized = true; // 초기화 완료
        return;
      }
      
      // 데이터가 있을 때만 복구
      _currentUser = UserModel.fromJson(decoded);
      debugPrint('🚩 [LOG] loadCurrentUser - 유저 복구됨: ${_currentUser?.id}');
      _isInitialized = true; // 초기화 완료
    } catch (e) {
      debugPrint('🚩 [LOG] loadCurrentUser - 에러 발생: $e, 메모리 캐시 null로 설정');
      _currentUser = null;
      _isInitialized = true; // 에러 발생해도 초기화 완료로 표시 (무한 루프 방지)
    }
  }

  /// 모든 페이지 진입 시 호출 가능. SharedPreferences 기준으로 현재 로그인 상태를 다시 불러와 동기화.
  /// 단, 로그아웃 중이면 실행되지 않음.
  /// 초기화가 완료된 후에는 화면 전환을 강제하지 않음 (무한 루프 방지)
  Future<void> ensureAuthSync() async {
    if (_isLoggingOut) {
      debugPrint('🚩 [LOG] ensureAuthSync 차단됨 - 로그아웃 진행 중');
      return;
    }
    
    // 이미 초기화가 완료되었으면 배경에서만 동기화 (화면 전환 없음)
    if (_isInitialized) {
      debugPrint('🚩 [LOG] ensureAuthSync - 이미 초기화 완료, 배경 동기화만 수행');
      // 배경에서 Firestore 데이터만 업데이트 (화면 전환 없음)
      if (_currentUser != null) {
        try {
          await fetchUserFromFirestore(_currentUser!.id);
        } catch (e) {
          debugPrint('🚩 [LOG] ensureAuthSync - 배경 동기화 실패 (무시): $e');
        }
      }
      return;
    }
    
    await loadCurrentUser();
  }

  Future<void> setCurrentUser(UserModel? user) async {
    // 로그아웃 중이면 setCurrentUser도 차단 (중복 호출 방지)
    if (_isLoggingOut && user == null) {
      debugPrint('🚩 [LOG] setCurrentUser(null) 차단됨 - 이미 logout()에서 처리 중');
      return;
    }
    
    // 로그아웃 중에는 유저 설정도 차단 (세션 부활 방지)
    if (_isLoggingOut) {
      debugPrint('🚩 [LOG] setCurrentUser 차단됨 - 로그아웃 진행 중');
      return;
    }
    
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    if (user == null) {
      // 로그아웃 시: 모든 유저 관련 키를 명시적으로 제거
      await prefs.remove(_keyCurrentUser);
      // 추가로 다른 가능한 키들도 제거 (안전장치)
      await prefs.remove('user');
      await prefs.remove('userId');
      await prefs.remove('token');
      await prefs.remove('auth_token');
      await prefs.remove('session');
      await prefs.remove('current_user');
      await prefs.remove('logged_in_user');
      
      debugPrint('🚩 [LOG] AuthRepository 유저 데이터 null로 설정됨 - 모든 키 제거 완료');
      
      // SharedPreferences가 완전히 비워졌는지 확인
      final remaining = prefs.getString(_keyCurrentUser);
      if (remaining != null && remaining.isNotEmpty) {
        debugPrint('🚩 [LOG] 경고: SharedPreferences에 여전히 데이터가 남아있음!');
        await prefs.clear(); // 최후의 수단: 전체 클리어
      }
      
      notifyListeners(); // 상태 변화 알림
      return; // 로그아웃 시 이전 사용자 데이터 완전 제거
    }
    await prefs.setString(_keyCurrentUser, jsonEncode(user.toJson()));
    notifyListeners(); // 상태 변화 알림
  }

  // --- 에러 해결 구간 ---

  /// 회원가입. 호출 전 프론트엔드에서 비밀번호 4~20자·생년월일 6자리 검증 완료된 경우에만 요청됨.
  /// CHECK: 생년월일 기반 비밀번호 초기화 로직 적용 완료 — Firestore 필드명 'birthDate'
  Future<UserModel> signUp(UserModel user) async {
    // 로그아웃 중이면 차단
    if (_isLoggingOut) {
      debugPrint('🚩 [LOG] signUp 차단됨 - 로그아웃 진행 중');
      throw StateError('Cannot sign up while logging out');
    }
    
    try {
      await _firestore.collection(FirestoreCollections.users).doc(user.id).set({
        FirestoreUserKeys.userId: user.id,
        FirestoreUserKeys.id: user.id,
        FirestoreUserKeys.email: user.email,
        FirestoreUserKeys.password: user.password,
        FirestoreUserKeys.nickname: user.nickname,
        FirestoreUserKeys.role: user.type.name,
        FirestoreUserKeys.type: user.type.name,
        FirestoreUserKeys.trustScore: 0,
        FirestoreUserKeys.createdAt: FieldValue.serverTimestamp(),
        FirestoreUserKeys.birthDate: user.birthDate ?? '',
        // profileImage는 파일명만 저장 (전체 경로가 아닌)
        FirestoreUserKeys.profileImage: user.profileImage != null && user.profileImage!.isNotEmpty
            ? (user.profileImage!.contains('assets/images/')
                ? AppAssets.getFileName(user.profileImage!)
                : user.profileImage!.trim())
            : AppAssets.getFileName(AppAssets.defaultProfile),
      });
      await setCurrentUser(user);
      return user;
    } catch (e, stackTrace) {
      debugPrint('AuthRepository.signUp error: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  /// CHECK: 생년월일 기반 비밀번호 초기화 로직 적용 완료 — 아이디·생년월일 일치 시 비밀번호를 생년월일로 갱신
  /// (Firestore 기반. Firebase Auth updatePassword 사용 시 백엔드/Cloud Function 필요.)
  /// 저장값이 YYYY-MM-DD면 6자리 입력을 ISO로 변환해 비교, 레거시 6자리면 그대로 비교.
  Future<bool> resetPasswordByIdAndBirthDate(String id, String birthDate) async {
    final doc = await _firestore.collection(FirestoreCollections.users).doc(id).get();
    if (!doc.exists) return false;
    final data = doc.data()!;
    final storedBirth = (data[FirestoreUserKeys.birthDate]?.toString().trim() ?? '').trim();
    if (storedBirth.isEmpty) return false;
    final inputTrimmed = birthDate.trim();
    final storedIsIso = storedBirth.length == 10 && storedBirth[4] == '-' && storedBirth[7] == '-';
    final match = storedIsIso
        ? (BirthDateUtil.yymmddToIso(inputTrimmed) == storedBirth)
        : (storedBirth == inputTrimmed);
    if (!match) return false;
    await _firestore.collection(FirestoreCollections.users).doc(id).update({FirestoreUserKeys.password: inputTrimmed});
    return true;
  }

  /// 테스트 계정에 생년월일을 부여해 Firestore에 존재하도록 시드. 비밀번호 찾기 테스트용.
  /// CHECK: 생년월일 기반 비밀번호 초기화 로직 적용 완료
  Future<void> seedTestAccountsWithBirthDateIfNeeded() async {
    final list = <(DocumentReference, String, String, String, String, String)>[
      (_firestore.collection(FirestoreCollections.users).doc('0000'), '0000', '0000', '테스트환자', 'patient', '000000'),
      (_firestore.collection(FirestoreCollections.users).doc('1111'), '1111', '1111', '테스트후원자', 'donor', '111101'),
      (_firestore.collection(FirestoreCollections.users).doc('2222'), '2222', '2222', '테스트일반', 'donor', '222202'),
      (_firestore.collection(FirestoreCollections.users).doc('admin'), 'admin', 'admin0000', '관리자', 'admin', '010101'),
    ];
    final batch = _firestore.batch();
    for (final r in list) {
      final ref = r.$1;
      final snap = await ref.get();
      if (!snap.exists) {
        final birthIso = BirthDateUtil.yymmddToIso(r.$6) ?? r.$6;
        batch.set(ref, {
          FirestoreUserKeys.userId: r.$2,
          FirestoreUserKeys.id: r.$2,
          FirestoreUserKeys.email: '',
          FirestoreUserKeys.password: r.$3,
          FirestoreUserKeys.nickname: r.$4,
          FirestoreUserKeys.role: r.$5,
          FirestoreUserKeys.type: r.$5,
          FirestoreUserKeys.trustScore: 0,
          FirestoreUserKeys.birthDate: birthIso,
          FirestoreUserKeys.createdAt: FieldValue.serverTimestamp(),
        });
      }
    }
    try {
      await batch.commit();
    } catch (_) {}
  }

  /// 기존 화면(Admin 등)에서 에러가 나지 않도록 함수 부활
  Future<List<UserModel>> getUsers() async {
    final snapshot = await _firestore.collection(FirestoreCollections.users).get();
    return snapshot.docs.map((doc) => UserModel.fromJson(doc.data())).toList();
  }

  Future<void> updateUser(UserModel user) async {
    await _firestore.collection(FirestoreCollections.users).doc(user.id).update(user.toJson());
  }

  /// 온보딩 정보 업데이트 (생년월일, 회원 유형, 프로필 이미지)
  Future<void> updateUserOnboardingInfo({
    required String userId,
    required String birthDate,
    required UserType userType,
    String? profileImage,
  }) async {
    // 로그아웃 중이면 차단
    if (_isLoggingOut) {
      debugPrint('🚩 [LOG] updateUserOnboardingInfo 차단됨 - 로그아웃 진행 중');
      return;
    }

    try {
      final updateData = <String, dynamic>{
        FirestoreUserKeys.birthDate: birthDate,
        FirestoreUserKeys.role: userType.name,
        FirestoreUserKeys.type: userType.name,
      };
      
      // 프로필 이미지가 제공된 경우에만 업데이트
      if (profileImage != null && profileImage.isNotEmpty) {
        updateData[FirestoreUserKeys.profileImage] = profileImage;
      }
      
      await _firestore.collection(FirestoreCollections.users).doc(userId).update(updateData);
      
      debugPrint('🚩 [LOG] 온보딩 정보 업데이트 완료 - userId: $userId, birthDate: $birthDate, type: ${userType.name}, profileImage: ${profileImage ?? "기본값"}');
    } catch (e, stackTrace) {
      debugPrint('🚩 [LOG] 온보딩 정보 업데이트 실패 - $e');
      debugPrint('🚩 [LOG] 스택 트레이스: $stackTrace');
      rethrow;
    }
  }

  /// Firestore에서 최신 유저 문서를 불러와 동기화. 회원정보 수정 화면 등에서 실시간 반영용.
  /// 이미 admin인 경우 서버 응답에서 role이 누락/기본값이어도 admin 유지(강등 방지).
  Future<UserModel?> fetchUserFromFirestore(String userId) async {
    // 로그아웃 중이면 무조건 차단 (세션 부활 방지)
    if (_isLoggingOut) {
      debugPrint('🚩 [LOG] fetchUserFromFirestore 차단됨 - 로그아웃 진행 중 (세션 부활 방지)');
      return null;
    }
    
    // _currentUser가 null이면 fetch하지 않음 (로그아웃 후 세션 부활 방지)
    if (_currentUser == null) {
      debugPrint('🚩 [LOG] fetchUserFromFirestore 차단됨 - _currentUser가 null (로그아웃 상태)');
      return null;
    }
    
    try {
      final doc = await _firestore.collection(FirestoreCollections.users).doc(userId).get();
      final data = doc.data();
      if (doc.exists && data != null) {
        // 로그아웃 중이면 중간에 차단
        if (_isLoggingOut) {
          debugPrint('🚩 [LOG] fetchUserFromFirestore 중간 차단 - 로그아웃 진행 중');
          return null;
        }
        
        final user = UserModel.fromJson(data);
        final wasAdmin = _currentUser?.type == UserType.admin;
        final isNowAdmin = user.type == UserType.admin;
        if (wasAdmin && !isNowAdmin) {
          final preserved = user.copyWith(type: UserType.admin);
          await setCurrentUser(preserved);
          return preserved;
        }
        await setCurrentUser(user);
        return user;
      }
    } catch (e) {
      debugPrint('AuthRepository.fetchUserFromFirestore: $e');
    }
    return null;
  }

  /// 현재 비밀번호 확인 후 새 비밀번호로 Firestore 업데이트 (재인증).
  /// currentPassword가 저장된 값과 일치해야만 성공.
  Future<bool> updatePasswordReauth(String userId, String currentPassword, String newPassword) async {
    // 로그아웃 중이면 차단
    if (_isLoggingOut) {
      debugPrint('🚩 [LOG] updatePasswordReauth 차단됨 - 로그아웃 진행 중');
      return false;
    }
    
    try {
      final doc = await _firestore.collection(FirestoreCollections.users).doc(userId).get();
      final data = doc.data();
      if (!doc.exists || data == null) return false;
      final user = UserModel.fromJson(data);
      if (user.password != currentPassword) return false;
      await _firestore.collection(FirestoreCollections.users).doc(userId).update({FirestoreUserKeys.password: newPassword});
      await setCurrentUser(user.copyWith(password: newPassword));
      return true;
    } catch (e) {
      debugPrint('AuthRepository.updatePasswordReauth: $e');
      return false;
    }
  }

  /// 구글 소셜 로그인 (Web)
  /// 로그인 성공 시 Firestore users 컬렉션에 자동 저장/업데이트, 기본 role은 sponsor
  Future<UserModel?> signInWithGoogle() async {
    // 로그아웃 중이면 차단
    if (_isLoggingOut) {
      debugPrint('🚩 [LOG] signInWithGoogle 차단됨 - 로그아웃 진행 중');
      return null;
    }

    try {
      // 웹 환경에서 Google Sign-In 최적화
      // clientId는 index.html의 메타 태그에서 자동으로 읽어옴
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        // 웹 환경에서 명시적으로 설정 (선택사항)
        // clientId는 메타 태그에서 자동으로 읽어오므로 생략 가능
      );

      debugPrint('🚩 [LOG] 구글 로그인 시작 - 팝업 호출');
      
      // 약간의 지연을 추가하여 클릭 이벤트가 완전히 처리되도록 함
      await Future.delayed(const Duration(milliseconds: 50));
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        debugPrint('🚩 [LOG] 구글 로그인 취소됨');
        return null; // 사용자가 로그인 취소
      }
      
      // 구글 계정 정보 추출
      final String email = googleUser.email;
      final String displayName = googleUser.displayName ?? '이름없음';
      final String photoUrl = googleUser.photoUrl ?? '';
      final String userId = email.split('@')[0]; // 이메일 앞부분을 userId로 사용

      debugPrint('🚩 [LOG] 구글 로그인 성공 - email: $email, name: $displayName');

      // Firestore에서 기존 유저 확인
      final userDoc = await _firestore.collection(FirestoreCollections.users).doc(userId).get();
      
      UserModel user;
      
      if (userDoc.exists) {
        // 기존 유저: 정보 업데이트
        final existingData = userDoc.data()!;
        user = UserModel.fromJson(existingData);
        
        // 프로필 정보 업데이트 (이름만, 프로필 이미지는 온보딩에서 선택하므로 업데이트 안 함)
        user = user.copyWith(
          nickname: displayName,
          email: email,
          // profileImage는 기존 값 유지 (온보딩에서 선택한 마스코트 유지)
        );
        
        // Firestore 업데이트 (프로필 이미지는 업데이트 안 함 - 온보딩에서 선택한 값 유지)
        await _firestore.collection(FirestoreCollections.users).doc(userId).update({
          FirestoreUserKeys.nickname: displayName,
          FirestoreUserKeys.email: email,
          // profileImage는 업데이트 안 함 (온보딩에서 선택한 마스코트 유지)
        });
        
        debugPrint('🚩 [LOG] 기존 유저 정보 업데이트 완료');
      } else {
        // 신규 유저: 생성 (기본 role은 viewer로 설정하여 온보딩 필요 상태로 표시)
        // 프로필 이미지는 온보딩에서 선택하므로 null로 설정 (구글 프로필 이미지 사용 안 함)
        user = UserModel(
          id: userId,
          email: email,
          password: '', // 소셜 로그인은 비밀번호 없음
          nickname: displayName,
          type: UserType.viewer, // 기본 role은 viewer (온보딩 필요 상태)
          trustScore: 0,
          isVerified: true, // 소셜 로그인은 자동 인증
          profileImage: null, // 온보딩에서 선택하도록 null로 설정 (구글 프로필 이미지 사용 안 함)
          birthDate: null, // 생년월일 없음 (온보딩 필요)
        );

        // Firestore에 저장
        // 프로필 이미지는 온보딩에서 선택하므로 기본값 사용 (구글 프로필 이미지 URL 저장 안 함)
        await _firestore.collection(FirestoreCollections.users).doc(userId).set({
          FirestoreUserKeys.userId: userId,
          FirestoreUserKeys.id: userId,
          FirestoreUserKeys.email: email,
          FirestoreUserKeys.password: '', // 소셜 로그인은 비밀번호 없음
          FirestoreUserKeys.nickname: displayName,
          FirestoreUserKeys.role: UserType.viewer.name, // 기본 role은 viewer (온보딩 필요)
          FirestoreUserKeys.type: UserType.viewer.name,
          FirestoreUserKeys.trustScore: 0,
          FirestoreUserKeys.createdAt: FieldValue.serverTimestamp(),
          FirestoreUserKeys.joinedAt: FieldValue.serverTimestamp(),
          FirestoreUserKeys.isVerified: true,
          FirestoreUserKeys.birthDate: '', // 생년월일 없음 (온보딩 필요)
          FirestoreUserKeys.profileImage: 'profile_yellow.png', // 기본값 사용 (온보딩에서 변경 가능)
          FirestoreUserKeys.withPayBalance: 0,
        });
        
        debugPrint('🚩 [LOG] 신규 유저 생성 완료 (온보딩 필요)');
      }

      // 현재 유저로 설정
      await setCurrentUser(user);
      
      // 로그인 성공 시 스트림 순차 로딩: 피드 먼저, 500ms 후 WITH Pay (Firestore ca9 충돌 방지)
      initializeApprovedPostsStream();
      await Future.delayed(const Duration(milliseconds: 500));
      initializeWithPayService();
      
      // 상태 변화 즉시 알림 (로그인 루프 방지)
      notifyListeners();
      debugPrint('🚩 [LOG] 구글 로그인 완료 - notifyListeners() 호출');
      
      return user;
    } catch (e, stackTrace) {
      debugPrint('🚩 [LOG] 구글 로그인 실패 - $e');
      debugPrint('🚩 [LOG] 스택 트레이스: $stackTrace');
      return null;
    }
  }

  /// 로그인. 호출 전 프론트엔드에서 비밀번호 4~20자 검증 완료된 경우에만 요청됨. (CHECK: 비밀번호 규칙 (4-20자) 적용 완료)
  Future<UserModel?> login(String id, String password) async {
    // 로그아웃 중이면 차단
    if (_isLoggingOut) {
      debugPrint('🚩 [LOG] login 차단됨 - 로그아웃 진행 중');
      return null;
    }
    
    final admin = TestAccounts.resolveAdmin(id, password);
    if (admin != null) { 
      await setCurrentUser(admin);
      // 스트림 순차 로딩: 피드 먼저, 500ms 후 WITH Pay (Firestore ca9 방지)
      initializeApprovedPostsStream();
      await Future.delayed(const Duration(milliseconds: 500));
      initializeWithPayService();
      return admin; 
    }

    final testUser = TestAccounts.resolveTestUser(id, password);
    if (testUser != null) { 
      await setCurrentUser(testUser);
      initializeApprovedPostsStream();
      await Future.delayed(const Duration(milliseconds: 500));
      initializeWithPayService();
      return testUser; 
    }

    final doc = await _firestore.collection(FirestoreCollections.users).doc(id).get();
    final data = doc.data();
    if (doc.exists && data != null) {
      final user = UserModel.fromJson(data);
      if (user.password == password) {
        await setCurrentUser(user);
        initializeApprovedPostsStream();
        await Future.delayed(const Duration(milliseconds: 500));
        initializeWithPayService();
        return user;
      }
    }
    return null;
  }

  /// 로그아웃 시 현재 사용자만 제거. 이전 사용자 데이터가 남지 않도록 setCurrentUser(null)로 초기화.
  /// Firebase Auth signOut도 호출 (사용 중인 경우).
  /// 참고: 이 프로젝트는 Firestore 기반 인증을 사용하므로 Firebase Auth는 선택적입니다.
  Future<void> logout() async {
    debugPrint('🚩 [LOG] AuthRepository.logout() 호출됨');
    
    // 로그아웃 플래그 설정 - 자동 로그인 로직 차단 (가장 먼저 설정)
    _isLoggingOut = true;
    debugPrint('🚩 [LOG] 로그아웃 플래그 설정됨 - 자동 로그인 차단');
    
    // Firebase Auth signOut 호출 (사용 중인 경우)
    // 현재 프로젝트는 Firestore 기반 인증을 사용하므로 아래 코드는 주석 처리
    // 필요시 firebase_auth 패키지를 추가하고 아래 주석을 해제하세요:
    // try {
    //   await FirebaseAuth.instance.signOut();
    // } catch (_) {
    //   // Firebase Auth가 사용되지 않는 경우 무시
    // }
    
    // 1단계: 메모리 내 모든 내부 변수 강제 초기화 (모든 가능한 변수명 확인)
    _currentUser = null;
    debugPrint('🚩 [LOG] 메모리 내 _currentUser 강제 초기화 완료');
    
    // 2단계: SharedPreferences에서 모든 유저 관련 데이터 완전 삭제
    final prefs = await SharedPreferences.getInstance();
    
    // 모든 가능한 키를 명시적으로 제거
    await prefs.remove(_keyCurrentUser);
    await prefs.remove('user');
    await prefs.remove('userId');
    await prefs.remove('token');
    await prefs.remove('auth_token');
    await prefs.remove('session');
    await prefs.remove('current_user');
    await prefs.remove('logged_in_user');
    
    // 삭제 확인 - _keyCurrentUser가 확실히 삭제되었는지 체크
    final remaining = prefs.getString(_keyCurrentUser);
    if (remaining != null && remaining.isNotEmpty) {
      debugPrint('🚩 [LOG] 경고: SharedPreferences에 여전히 데이터가 남아있음! 전체 클리어 실행');
      await prefs.clear(); // 최후의 수단: 전체 클리어
      debugPrint('🚩 [LOG] SharedPreferences 전체 클리어 완료');
    }
    
    // 최종 확인 - 모든 키가 삭제되었는지 재확인
    final finalCheck = prefs.getString(_keyCurrentUser);
    if (finalCheck != null && finalCheck.isNotEmpty) {
      debugPrint('🚩 [LOG] 심각: SharedPreferences 삭제 실패! 재시도');
      await prefs.clear();
    }
    
    debugPrint('🚩 [LOG] SharedPreferences 완전 삭제 완료 - 최종 확인: ${prefs.getString(_keyCurrentUser) ?? "null"}');
    
    // 3단계: 메모리 캐시 재확인 및 강제 초기화 (이중 안전장치)
    _currentUser = null;
    
    // 3-1단계: 모든 Firestore 스트림 캐시 완전 삭제 (세션 부활 방지 및 Firestore 스트림 충돌 방지)
    clearWithPayStreamCache();
    clearApprovedPostsStreamCache();
    debugPrint('🚩 [LOG] 모든 Firestore 스트림 캐시 완전 삭제 완료 (Firestore 스트림 충돌 방지)');
    
    // 4단계: notifyListeners() 단 한 번만 호출 (모든 데이터 삭제 후)
    notifyListeners();
    debugPrint('🚩 [LOG] notifyListeners() 호출 완료 - 상태 변화 알림');
    
    // 5단계: 화면 전환이 완료될 때까지 충분한 지연 후 플래그 해제
    // Repository 계층에서는 addPostFrameCallback 대신 Future.delayed 사용 (권장 방식)
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 6단계: 플래그 해제 전 최종 확인: _currentUser가 확실히 null인지 재확인
    if (_currentUser != null) {
      debugPrint('🚩 [LOG] 경고: _currentUser가 null이 아님! 강제 초기화 실행');
      _currentUser = null;
      // 다시 한 번 notifyListeners() 호출하여 상태 동기화
      notifyListeners();
    }
    
    // 7단계: 메모리 캐시 완전 소거 확인 로그
    debugPrint('🚩 [LOG] AuthRepository 메모리 캐시 완전 소거 완료 - _currentUser: ${_currentUser?.id ?? "null"}');
    
    // 플래그 해제
    _isLoggingOut = false;
    _isInitialized = false; // 로그아웃 시 초기화 플래그도 리셋 (다음 로그인 시 재초기화)
    debugPrint('🚩 [LOG] 로그아웃 플래그 해제됨 - 화면 전환 완료 후');
    
    // 최종 확인 로그
    debugPrint('🚩 [LOG] AuthRepository 로그아웃 완료 - 사용자 세션 종료 (최종 확인: _currentUser=${_currentUser?.id ?? "null"})');
  }

  /// 회원 탈퇴: Firestore에서 유저 데이터 삭제 및 로그아웃 처리
  /// reason: 탈퇴 사유 (선택사항, 로그 기록용)
  Future<void> deleteAccount({String? reason}) async {
    final user = _currentUser;
    if (user == null) {
      debugPrint('🚩 [LOG] deleteAccount - 현재 유저가 없음');
      throw Exception('로그인된 사용자가 없습니다.');
    }

    debugPrint('🚩 [LOG] 회원 탈퇴 시작 - userId: ${user.id}, reason: ${reason ?? "없음"}');

    // 로그아웃 플래그 설정 (자동 로그인 방지)
    _isLoggingOut = true;

    try {
      // Firestore에서 유저 문서 삭제
      await _firestore.collection(FirestoreCollections.users).doc(user.id).delete();
      debugPrint('🚩 [LOG] Firestore 유저 문서 삭제 완료 - userId: ${user.id}');

      // 탈퇴 사유가 있으면 별도 컬렉션에 기록 (선택사항)
      if (reason != null && reason.isNotEmpty) {
        try {
          await _firestore.collection('withdrawal_reasons').add({
            'userId': user.id,
            'reason': reason,
            'deletedAt': FieldValue.serverTimestamp(),
          });
          debugPrint('🚩 [LOG] 탈퇴 사유 기록 완료 - reason: $reason');
        } catch (e) {
          debugPrint('🚩 [LOG] 탈퇴 사유 기록 실패 (무시) - $e');
        }
      }

      // 메모리 및 SharedPreferences 정리 (logout()과 동일한 로직이지만 중복 호출 방지)
      _currentUser = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyCurrentUser);
      await prefs.remove('user');
      await prefs.remove('userId');
      await prefs.remove('token');
      await prefs.remove('auth_token');
      await prefs.remove('session');
      await prefs.remove('current_user');
      await prefs.remove('logged_in_user');
      
      // 스트림 캐시 삭제
      clearWithPayStreamCache();
      clearApprovedPostsStreamCache();
      
      // 상태 변화 알림
      notifyListeners();
      
      debugPrint('🚩 [LOG] 회원 탈퇴 완료 - userId: ${user.id}');
    } catch (e, stackTrace) {
      debugPrint('🚩 [LOG] 회원 탈퇴 실패 - $e');
      debugPrint('🚩 [LOG] 스택 트레이스: $stackTrace');
      
      // 에러 발생 시 플래그 해제
      _isLoggingOut = false;
      
      rethrow;
    } finally {
      // 플래그 해제 (성공/실패 모두)
      await Future.delayed(const Duration(milliseconds: 500));
      _isLoggingOut = false;
      _isInitialized = false; // 탈퇴 시 초기화 플래그도 리셋
    }
  }
}