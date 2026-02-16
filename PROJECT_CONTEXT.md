# WITH Platform — Project Context & Hand-over Document

> 프로젝트 루트의 단일 컨텍스트 문서. 기능 구현 완료 시마다 이 파일을 갱신합니다.

---

## [Current Status]

- **구현된 기능 목록**
  - Clean Architecture 기반 폴더 구조 (core / features / shared)
  - 반응형 테마 (노란 #FFD700, 산호 #FF7F7F) 및 ThemeData
  - 반응형 레이아웃: 모바일 단일 컬럼, 웹/데스크톱 2컬럼(피드 좌 + 순위 우)
  - 메인 화면: WITH 헤더, 후원 진행 카드(입체감 Stack), 투데이/피드 토글, 피드 카드·후원자 순위·감사편지 영역
  - 하단 네비게이션(홈/추가/마이페이지) — 모바일 전용
  - 비로그인 메인 노출, 추가/마이페이지·나도 후원하기 클릭 시 로그인 유도 다이얼로그(로그인/회원가입 버튼)
  - **인증:** 메인 좌측 상단 사람 아이콘 → 로그인 화면 이동. SharedPreferences 기반 AuthRepository로 회원 정보 저장.
  - **로그인/회원가입 화면:** 아이디·비밀번호 로그인, 회원가입 유형(후원자/환자) 선택 후 상세 정보(아이디, 비밀번호, 이메일, 닉네임) 입력.
  - **관리자 계정:** ID `admin`, PW `admin0000` 사전 정의(AdminAccount). admin 로그인 시 관리자 모드 진입 기초.
  - **로그인 후:** 메인 상단 "안녕하세요, [닉네임]님" 출력, 피드 첫 카드 작성자명에 닉네임 표시.
  - **마스코트:** 단순 기하 도형(원·사각형·삼각형)+감은 눈·미소, 파스텔 노랑·분홍·하늘·연두. 로딩 화면·프로필 기본 이미지·후원 완료 축하 페이지에 사용 예정.
  - **관리자 대시보드:** admin/admin0000 로그인 시 AdminMainScreen으로 분기. 비관리자 접근 가드. 통계(총/후원자/환자), 회원 리스트(닉네임·역할·가입일·상태·상세보기), 회원 상세(이메일·Trust Score·투병/후원 영역·인증 완료). SharedPreferences 회원 데이터 연동.
  - **게시글 작성 이원화:** 하단 네비 가운데 [+] 탭 → `PostCreateChoiceScreen`(투병 기록 남기기 / 감사 편지 쓰기). **투병 기록:** `PostUploadScreen` — 제목·내용(20자 이상)·사진 0~3장(선택), Firestore `posts`에 `type: 'struggle'`, 저장 후 "검토 후 업로드됩니다." **감사 편지:** `ThankYouPostListScreen`(현재 유저의 승인된 투병 기록 목록) → 게시물 선택 → `ThankYouLetterUploadScreen`(제목·내용·사진 0~3장) → Firestore `thank_you_posts`에 `status: pending`, `type: 'thanks'` 저장 후 "검토 후 업로드됩니다."
  - **관리자 대시보드:** 상단 탭 [투병 기록 승인] | [감사 편지 승인]. **투병 기록:** 기존 pending 사연 리스트·상세 시트·승인/반려/삭제(삭제 버튼 상시). **감사 편지:** pending 감사 편지 리스트에서 탭 시 **관리자 전용** `AdminThankYouDetailScreen`(풀스크린)으로 이동. 상세 화면 진입 시 `currentUser.type == admin` 재확인, 비관리자면 '권한이 없습니다' 스낵바 후 즉시 pop. 상세 화면 하단 고정 [삭제]/[승인], 이미지·환자명·편지 내용·사용 목적(usagePurpose) 한눈에 표시. 삭제: 확인 팝업 후 Firestore 제거. 승인: `approveThankYouPost` → today_thank_you 노출·스낵바. `admin_service`: `deleteDocument`, `deletePost`, `deleteThankYouPost`, `showDeleteConfirmDialog`, `approveThankYouPost`.
  - **투데이 탭:** '한줄 후기 감사편지' 영역이 Firestore `today_thank_you` 컬렉션 실시간 스트림으로 표시(승인된 감사 편지).
  - **메인:** 모바일 우측 하단 FAB 제거. 하단 네비 [+] → `PostCreateChoiceScreen`. 마이페이지 관리자 전용 '관리자 대시보드' → `AdminDashboardScreen` 진입 시 admin 권한 체크 후 비관리자 즉시 퇴장.
  - **WITH Pay:** Firestore `users` 문서에 `withPayBalance`(int, 기본 0). `WithPayService`: `rechargeWithPay(userId, amount, paymentMethod)`(Transaction·increment + `recharges` 컬렉션 내역 저장), `getWithPayBalance`, `withPayBalanceStream`, `balanceFromSnapshot`. 충전 UX: 금액 선택 → [충전하기] → 결제 수단 선택 BottomSheet(신용카드/카카오페이/네이버페이/토스) → `PaymentService.startPay()`(추후 Portone 등 PG 교체용) → 가상 결제 모달(PaymentWebViewMock: 2.5초 로딩 → "지문/비밀번호 입력" + [확인]) → 충전 처리 → RechargeSuccessScreen(초록 체크 + "충전이 완료되었습니다!" + 잔액 + [확인]) → 마이페이지 복귀 시 StreamBuilder로 잔액 최신화. Firestore `recharges`: userId, amount, paymentMethod, createdAt.

---

## [File Changes]

- **생성/수정된 주요 파일 및 경로**

| 경로 | 역할 |
|------|------|
| `lib/main.dart` | 앱 진입점. loadCurrentUser 후 WithApp → MainScreen |
| `lib/core/constants/app_colors.dart` | 전역 색상 상수 AppColors (yellow/coral/textPrimary 등) |
| `lib/core/constants/admin_account.dart` | 관리자 계정 상수 AdminAccount (id: admin, password: admin0000) |
| `lib/core/constants/assets.dart` | WithMascots(마스코트 이미지 경로). `images/xxx` 사용 → 웹 빌드 시 build/web/assets/images/ 로 출력 |
| `images/` (루트) | 에셋 이미지 폴더. pubspec `images/` 등록. mascot_p.png, image_48dd69.png 등 배치 |
| `lib/core/auth/user_model.dart` | UserModel, UserType, MemberStatus. joinedAt/status/trustScore/isVerified, copyWith |
| `lib/core/auth/auth_repository.dart` | AuthRepository(싱글톤). getUsers/updateUser, SharedPreferences 저장 |
| `lib/core/constants/responsive_breakpoints.dart` | ResponsiveBreakpoints (mobileMax 600px) |
| `lib/core/theme/app_theme.dart` | AppTheme.lightTheme (ThemeData) |
| `lib/core/util/responsive_util.dart` | ResponsiveHelper (isMobile/isDesktop/screenWidth) |
| `lib/shared/widgets/responsive_layout.dart` | ResponsiveLayout (mobileChild/desktopChild 분기) |
| `lib/shared/widgets/with_header.dart` | WithHeader (WITH 로고, 좌측 사람 아이콘 onPersonTap, 알림, showBackButton) |
| `lib/shared/widgets/donation_progress_card.dart` | DonationProgressCard (후원 금액 카드, Stack 입체감) |
| `lib/shared/widgets/today_feed_toggle.dart` | TodayFeedToggle (투데이/피드 전환) |
| `lib/shared/widgets/bottom_navigation.dart` | BottomNavBar (홈/추가/마이페이지) |
| `lib/shared/widgets/login_prompt_dialog.dart` | LoginPromptDialog (onLoginTap/onSignupTap으로 해당 화면 이동) |
| `lib/shared/widgets/feed_card.dart` | FeedCard (피드 한 건: authorName, likeCount, bodyText 등) |
| `lib/shared/widgets/donor_rank_list.dart` | DonorRankList / DonorRankItem (후원자 순위) |
| `lib/features/main/main_screen.dart` | MainScreen. admin 로그인 시 AdminMainScreen으로 pushReplacement, initState 가드 |
| `lib/features/main/main_content_mobile.dart` | MainContentMobile (displayNickname으로 첫 피드 작성자명) |
| `lib/features/main/main_content_desktop.dart` | MainContentDesktop (displayNickname으로 첫 피드 작성자명) |
| `lib/features/auth/login_screen.dart` | LoginScreen (아이디/비밀번호, 관리자·일반 로그인, 회원가입 링크) |
| `lib/features/auth/signup_screen.dart` | SignupScreen (후원자/환자 선택 → 상세 정보 입력, AuthRepository.signUp) |
| `lib/features/admin/admin_main_screen.dart` | AdminMainScreen. 가드, 헤더·로그아웃, 통계 카드, 회원 리스트·상세보기 |
| `lib/features/admin/admin_member_detail_screen.dart` | 회원 상세: 기본정보·Trust Score·투병/후원 영역·인증 완료·저장 |
| `lib/core/constants/firestore_keys.dart` | FirestorePostKeys(type/typeStruggle/typeThanks), ThankYouPostKeys, FirestoreCollections(thankYouPosts, todayThankYou) |
| `lib/core/services/imgbb_upload.dart` | ImgBB API 업로드. imgbbApiKey, readAsBytes→base64→POST, data.url 반환. [SYSTEM] 로그 |
| `lib/core/services/with_pay_service.dart` | getWithPayBalance, withPayBalanceStream, balanceFromSnapshot, rechargeWithPay(Transaction·recharges 저장) |
| `lib/core/services/payment_method.dart` | PaymentMethod(card/kakao/naver/toss) enum |
| `lib/core/services/payment_service.dart` | startPay(context, userId, amount, method) — PG 교체용 진입점, 현재 가상 결제 |
| `lib/core/services/donation_service.dart` | processPaymentWithWithPay(Transaction: 잔액 차감·donations·stats·post), donationsStreamByUser |
| `lib/features/main/with_pay_recharge_dialog.dart` | showWithPayRechargeDialog, RechargeScreen(충전 페이지) |
| `lib/features/main/with_pay_payment_flow.dart` | showPaymentMethodSheet, PaymentWebViewMock, RechargeSuccessScreen |
| `lib/features/main/post_create_choice_screen.dart` | 게시글 작성 선택: 투병 기록 남기기 → PostUploadScreen / 감사 편지 쓰기 → ThankYouPostListScreen |
| `lib/features/main/thank_you_post_list_screen.dart` | 현재 유저의 승인된 투병 기록 목록, 선택 시 ThankYouLetterUploadScreen |
| `lib/features/main/thank_you_letter_upload_screen.dart` | 감사 편지 폼(제목·내용·사진 0~3장) → thank_you_posts 저장 |
| `lib/features/post/post_upload_screen.dart` | 투병 기록: 제목/내용(20자 이상)/사진(0~3장), type struggle, "검토 후 업로드됩니다." |
| `lib/features/admin/admin_dashboard_screen.dart` | 탭 [투병 기록 승인][감사 편지 승인], 감사 편지 리스트 탭 시 AdminThankYouDetailScreen push |
| `lib/features/admin/admin_thank_you_detail_screen.dart` | 관리자 전용 감사 편지 상세 풀스크린. 진입 시 admin 재확인, 하단 [삭제][승인], 이미지/환자명/내용/사용목적 레이아웃 |
| `lib/core/services/admin_service.dart` | deleteDocument(컬렉션 경로·docId), deletePost/deleteThankYouPost 래퍼, showDeleteConfirmDialog, approveThankYouPost |

---

## [UI/UX Status]

- **Mobile**
  - 상단 노란 헤더(좌측 사람 아이콘→로그인, WITH 로고, 알림), 로그인 시 "안녕하세요, [닉네임]님", 분홍 후원 카드(입체감), 투데이/피드 토글
  - 피드: 수직 스크롤 피드 카드 리스트. 카드 탭 → PostDetailScreen(후원하기 → WITH Pay 잔액 확인·차감·충전 유도).
  - 투데이: 오늘의 베스트 후원자 + 한줄 후기 감사편지(Firestore `today_thank_you` 실시간 스트림) 가로 스크롤
  - 하단 네비: 홈 / 추가(+) / 마이페이지. [+] 탭 시 `PostCreateChoiceScreen`(투병 기록 or 감사 편지). 추가·마이페이지 비로그인 시 로그인 유도.
  - 마이페이지: WITH Pay 카드에 실시간 잔액(StreamBuilder), 탭 시 충전 다이얼로그 → 결제 수단 시트 → 가상 결제 모달 → 성공 화면(잔액 표시) → [확인] 시 다이얼로그 닫고 잔액 최신화. 후원 화면에서 잔액 없음/부족 시 RechargeScreen push.

- **Web / Desktop**
  - 동일 헤더·후원 카드·토글
  - 2컬럼: 좌측 피드 또는 투데이 콘텐츠, 우측 고정 너비(320px) 후원자 순위
  - 하단 네비 없음, 우측 하단 «나도 후원하기» 버튼 (비로그인 시 로그인 유도)

---

## [Next Steps]

- 순위 전체보기 전용 화면 (이미지의 «순위 전체보기» UI)
- 로그아웃 버튼(마이페이지 또는 헤더 메뉴)
- API 연동 (후원 금액, 피드 목록, 순위 목록)
- 회원가입/로그인 시 Firestore `users` 문서에 `withPayBalance: 0` 필드 초기화(선택, 없으면 읽기 시 0 처리)
- **이미지 에셋:** `images/` 폴더에 실제 파일 추가 (mascot_p.png, image_48dd69.png 등). 경로는 `images/파일명`으로 통일해 웹 빌드 시 `assets/assets/` 중복 404 방지됨.
- 네트워크 이미지 URL 연동
- Firestore 복합 인덱스: `posts`(patientId, status, createdAt), `thank_you_posts`(status, createdAt) — 콘솔 오류 링크로 생성 가능

---

## [Dependencies]

- **프론트–백엔드 연결점**
  - API base URL: TBD
  - 예정 엔드포인트: 현재 후원 금액, 피드 목록, 후원자 순위, 인증(로그인/회원가입)

---

## [Data Flow / 호출 순서]

1. **앱 기동**  
   `main()` → `AuthRepository.instance.loadCurrentUser()` → `runApp(WithApp)` → `home: MainScreen`

2. **메인 화면**  
   `MainScreen` → `WithHeader(onPersonTap: _navigateToLogin)` + 로그인 시 "안녕하세요, [닉네임]님" + `DonationProgressCard` + `ResponsiveLayout`  
   - 모바일/데스크톱: `MainContentMobile`/`MainContentDesktop`에 `displayNickname: _currentNickname` 전달 → 첫 피드 카드 작성자명에 닉네임 표시

3. **로그인 진입**  
   - 헤더 좌측 사람 아이콘 탭 → `LoginScreen` push. 로그인 성공 시 `AuthRepository.setCurrentUser` 후 pop(true) → MainScreen setState 갱신.  
   - 비로그인 시 «추가»/«마이페이지»/«나도 후원하기» → `LoginPromptDialog.show(onLoginTap, onSignupTap)` → 로그인/회원가입 탭 시 해당 화면 push.

4. **로그인/회원가입**  
   - `LoginScreen`: 아이디·비밀번호 입력 → `AuthRepository.login` (AdminAccount 또는 저장된 사용자와 일치 시 성공) → 성공 시 pop(true).  
   - 회원가입 탭 → `SignupScreen` push. 유형(후원자/환자) 선택 → 아이디·비밀번호·이메일·닉네임 입력 → `AuthRepository.signUp` (addUser + setCurrentUser) → pop(true) → 필요 시 LoginScreen도 pop(true).

5. **관리자 대시보드**  
   - admin 로그인 시: `MainScreen`에서 `pushReplacement(AdminMainScreen)`. 앱 기동 시 currentUser가 admin이면 동일하게 치환.  
   - `AdminMainScreen`: 진입 시 `currentUser?.isAdmin != true`이면 `pushAndRemoveUntil(MainScreen)`. 통계(총/후원자/환자)는 `getUsers()` 결과로 계산. 회원 리스트에서 상세보기 → `AdminMemberDetailScreen(user)`.  
   - `AdminMemberDetailScreen`: 기본정보·Trust Score 입력·환자 시 투병 기록(플레이스홀더)·인증 완료 체크·후원자 시 후원 내역(플레이스홀더). 저장 시 `AuthRepository.updateUser(updated)`.  
   - **AdminDashboardScreen**(마이페이지 '관리자 대시보드'): 진입 시 admin 권한 체크, 비관리자 즉시 MainScreen으로 퇴장. 투병 기록: Firestore pending 스트림 → 탭 시 상세 시트 → 승인/반려/삭제. 감사 편지: pending 스트림 → 탭 시 **AdminThankYouDetailScreen** 풀스크린 push → 진입 시 admin 재확인(아니면 '권한이 없습니다' 후 pop) → 하단 [삭제]/[승인] 고정.

6. **환자 사연 신청**  
   - 메인: `UserType.patient`이고 모바일일 때만 FAB(+) 표시 → 탭 시 `PostUploadScreen` push.  
   - `PostUploadScreen`: 제목 필수, 내용 20자 이상·10줄 높이, 사진 최소 1장. [신청하기] 시 한 번에 로딩 → 각 사진 `uploadImageToImgBB(XFile)` → URL 수집 → Firestore `posts`에 title, content, imageUrls, patientId, patientName, createdAt, status: pending 저장 후 pop.

7. **참조 관계**  
   - `core/constants` → `core/theme`, `shared/widgets`  
   - `core/util` (ResponsiveHelper) → `shared/widgets`, `features/main`  
   - `core/auth` (UserModel, AuthRepository) → `features/auth`, `features/main`  
   - `shared/widgets` → `features/main`, `features/auth`  
   - `features/auth` (LoginScreen, SignupScreen) → `core/auth`, `shared/widgets`  
   - `features/admin` (AdminMainScreen, AdminMemberDetailScreen, AdminDashboardScreen, AdminThankYouDetailScreen) → `core/auth`, `features/main`(복귀용), Firestore posts  
   - `features/post` (PostUploadScreen, PostDetailScreen) → `core/auth`, `core/services/imgbb_upload`, `core/services/donation_service`, `core/services/with_pay_service`, Firestore posts  
   - `core/services/imgbb_upload` → `http`, `image_picker` (XFile.readAsBytes)

8. **WITH Pay · 충전·후원**  
   - 마이페이지: `withPayBalanceStream(userId)`로 잔액 표시. WITH Pay 카드 탭 → `showWithPayRechargeDialog`(금액 선택) → [충전하기] → `showPaymentMethodSheet`(신용카드/카카오/네이버/토스) → `startPay`(PaymentWebViewMock: 2.5초 로딩 → "지문/비밀번호" + [확인]) → `rechargeWithPay`(Transaction·`recharges` 저장) → `RechargeSuccessScreen`(잔액 표시) → [확인] 시 다이얼로그 닫고 스트림으로 잔액 갱신.  
   - PostDetailScreen 후원하기: 금액 선택 → `getWithPayBalance(userId)`. 잔액 0/부족 → "충전하시겠습니까?" 등 확인 시 `RechargeScreen` push. 잔액 ≥ 금액 → `processPaymentWithWithPay`(Transaction: 잔액 차감·donations·stats·post) → 성공 시 스낵바.

---

*마지막 갱신: 감사 편지 상세를 관리자 전용 풀스크린(AdminThankYouDetailScreen)으로 전환. 진입 시 admin 재확인·비관리자 퇴장, 하단 [삭제]/[승인] 고정, 이미지·환자명·내용·사용목적 레이아웃. AdminDashboard 감사 편지 리스트 탭 시 해당 화면으로 push, 기존 시트 제거.*
