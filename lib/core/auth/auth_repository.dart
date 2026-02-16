import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/firestore_keys.dart';
import '../constants/test_accounts.dart';
import '../constants/assets.dart';
import '../util/birth_date_util.dart';
import 'user_model.dart';

class AuthRepository {
  AuthRepository._();
  static final AuthRepository _instance = AuthRepository._();
  static AuthRepository get instance => _instance;

  static const String _keyCurrentUser = 'with_current_user';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  Future<void> loadCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_keyCurrentUser);
      if (json == null || json.isEmpty) return;
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) {
        _currentUser = null;
        return;
      }
      _currentUser = UserModel.fromJson(decoded);
    } catch (_) {
      _currentUser = null;
    }
  }

  /// 모든 페이지 진입 시 호출 가능. SharedPreferences 기준으로 현재 로그인 상태를 다시 불러와 동기화.
  Future<void> ensureAuthSync() async {
    await loadCurrentUser();
  }

  Future<void> setCurrentUser(UserModel? user) async {
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    if (user == null) {
      await prefs.remove(_keyCurrentUser);
      return; // 로그아웃 시 이전 사용자 데이터 완전 제거
    }
    await prefs.setString(_keyCurrentUser, jsonEncode(user.toJson()));
  }

  // --- 에러 해결 구간 ---

  /// 회원가입. 호출 전 프론트엔드에서 비밀번호 4~20자·생년월일 6자리 검증 완료된 경우에만 요청됨.
  /// CHECK: 생년월일 기반 비밀번호 초기화 로직 적용 완료 — Firestore 필드명 'birthDate'
  Future<UserModel> signUp(UserModel user) async {
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

  /// Firestore에서 최신 유저 문서를 불러와 동기화. 회원정보 수정 화면 등에서 실시간 반영용.
  Future<UserModel?> fetchUserFromFirestore(String userId) async {
    try {
      final doc = await _firestore.collection(FirestoreCollections.users).doc(userId).get();
      final data = doc.data();
      if (doc.exists && data != null) {
        final user = UserModel.fromJson(data);
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

  /// 로그인. 호출 전 프론트엔드에서 비밀번호 4~20자 검증 완료된 경우에만 요청됨. (CHECK: 비밀번호 규칙 (4-20자) 적용 완료)
  Future<UserModel?> login(String id, String password) async {
    final admin = TestAccounts.resolveAdmin(id, password);
    if (admin != null) { await setCurrentUser(admin); return admin; }

    final testUser = TestAccounts.resolveTestUser(id, password);
    if (testUser != null) { await setCurrentUser(testUser); return testUser; }

    final doc = await _firestore.collection(FirestoreCollections.users).doc(id).get();
    final data = doc.data();
    if (doc.exists && data != null) {
      final user = UserModel.fromJson(data);
      if (user.password == password) {
        await setCurrentUser(user);
        return user;
      }
    }
    return null;
  }

  /// 로그아웃 시 현재 사용자만 제거. 이전 사용자 데이터가 남지 않도록 setCurrentUser(null)로 초기화.
  Future<void> logout() async => await setCurrentUser(null);
}