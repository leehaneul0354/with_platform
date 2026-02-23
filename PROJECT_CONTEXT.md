# WITH Platform — Project Context & Hand-over Document

> 프로젝트 루트의 단일 컨텍스트 문서. 기능 구현 완료 시마다 이 파일을 갱신합니다.

---

## [Current Status]

- **구현된 기능 목록**
  - Clean Architecture 기반 폴더 구조 (core / features / shared)
  - 반응형 테마 (노란 #FFD700, 산호 #FF7F7F) 및 ThemeData
  - 반응형 레이아웃: 모바일 단일 컬럼, 웹/데스크톱 2컬럼(피드 좌 + 순위 우)
  - 메인 화면: WITH 헤더, 후원 진행 카드(입체감 Stack), 투데이/피드 토글, 피드 카드·후원자 순위·감사편지 영역
  - **하단 네비게이션 5탭 확장:** 홈(집 아이콘), 탐색(돋보기), 작성(다이어리), 투데이(하트), 마이페이지(사람) — 모바일 전용. 아웃라인 스타일 아이콘(Icons.*_outlined) 사용.
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
  - **메인 5탭 구조:** 홈(피드 일자형 나열), 탐색(ExploreScreen — SliverGrid n×3 인스타 스타일), 작성(DiaryScreen — 환자/후원자/비로그인 권한별 분기), 투데이(TodayScreen — 기부 순위 + 베스트 감사편지), 마이페이지. 작성 탭 비로그인 시 로그인 유도 바텀시트 자동 노출. 마이페이지 관리자 전용 '관리자 대시보드' → AdminDashboardScreen 진입 시 admin 권한 체크 후 비관리자 즉시 퇴장.
  - **WITH Pay:** Firestore `users` 문서에 `withPayBalance`(int, 기본 0). `WithPayService`: `rechargeWithPay(userId, amount, paymentMethod)`(Transaction·increment + `recharges` 컬렉션 내역 저장), `getWithPayBalance`, `withPayBalanceStream`, `balanceFromSnapshot`. 충전 UX: 금액 선택 → [충전하기] → 결제 수단 선택 BottomSheet(신용카드/카카오페이/네이버페이/토스) → `PaymentService.startPay()`(추후 Portone 등 PG 교체용) → 가상 결제 모달(PaymentWebViewMock: 2.5초 로딩 → "지문/비밀번호 입력" + [확인]) → 충전 처리 → RechargeSuccessScreen(초록 체크 + "충전이 완료되었습니다!" + 잔액 + [확인]) → 마이페이지 복귀 시 StreamBuilder로 잔액 최신화. Firestore `recharges`: userId, amount, paymentMethod, createdAt.
  - **게시글 상세 후원 UI 조건부:** `PostDetailScreen`에서 `isDonationRequest == false`(일반 기록)일 때 하단 '후원하기' 버튼 및 사용 목적(usagePurpose) 블록을 숨김. 후원 요청 게시물에서만 후원 관련 UI 노출.
  - **피드/투데이 하트(좋아요) 아이콘:** `StoryFeedCard`, `TodayThankYouGrid`, `PatientPostsListScreen`, `PatientMyContentScreen`에서 `isLikedStream` 기반으로 미좋아요 시 `Icons.favorite_border`, 좋아요 시 `Icons.favorite` + `AppColors.coral`. 상세 화면(PostDetailScreen, ThankYouDetailScreen) 좋아요 아이콘도 동일 브랜드 컬러 적용. 피드 카드에서 하트 탭 시 `toggleLike` 호출로 즉시 반영.
  - **관리자 대시보드 일반/후원 구분:** 투병 기록 승인 탭에서 카드별 **[일반 기록]**(푸른 배지) / **[후원 요청]**(코랄 배지) 표시. 상세 풀시트 상단에 동일 태그 노출, 후원 요청 시 '후원 요청 요약' 섹션(후원 유형·목표 금액·필요 물품·수량·배송 정보·병원명·사용 목적) 표시. 상단 ChoiceChip 필터 [전체 / 일반 기록 / 후원 요청]로 검수 우선순위 조절.
  - **Firestore 내부 ASSERTION FAILED (ID: ca9) 에러 수정 및 메인 피드 로딩 안정화:** Flutter Web 환경에서 로그아웃/로그인 시 Firestore 스트림 충돌 방지 및 간헐적 피드 로딩 실패 해결. (1) `main.dart` — Firebase 초기화 직후 `Firestore.settings`(persistenceEnabled: false, cacheSizeBytes: CACHE_SIZE_UNLIMITED) 적용, 모든 초기화 단계에 try-catch 에러 핸들링 추가, 피드 스트림 초기화 실패 시 500ms 후 재시도 로직. (2) `MainScreen` — 폭포수형 순차 로딩: 유저 확인 → 피드 스트림 초기화 확인/재시도 → 300ms → 피드 허용(_phaseFeedReady) → 300ms → 잔액/후원 허용(_phaseStatsReady), 각 단계별 로그 출력. (3) `with_pay_service.dart` — `_isInitialized` 플래그로 중복 구독 방지, `initializeWithPayService()`/`clearWithPayStreamCache()`로 초기화/리셋 관리, `withPayBalanceStream()`에서 초기화 체크 후 빈 스트림 반환. (4) `approved_posts_feed.dart` — `_approvedPostsStreamInitialized` 플래그로 중복 구독 방지, `initializeApprovedPostsStream(force: bool)`로 강제 초기화 지원, `_approvedPostsStream` getter에서 미초기화 시 자동 초기화, 스트림 에러 발생 시 캐시 리셋 및 재시도 가능하도록 처리, `ApprovedPostsFeed`/`ApprovedPostsFeedSliver`를 StatefulWidget으로 변경하여 재시도 버튼 구현(ValueKey로 스트림 재구독). (5) `auth_repository.dart` — 로그인 성공 시 `initializeWithPayService()`, `initializeApprovedPostsStream()` 호출, 로그아웃 시 `clearWithPayStreamCache()`, `clearApprovedPostsStreamCache()` 호출하여 모든 스트림 캐시 완전 삭제.
  - **Firestore 워터폴 로딩 및 엔진 충돌 완전 해결:** (1) `MainScreen` — `_isStreamTab0Ready`(500ms) → `_isStreamTab1Ready`(1000ms) → `_isStreamTab3Ready`(1500ms) 시차로 탭별 스트림 활성화, build() 내 유저 null 시 리다이렉트 제거(탭 튕김 방지), 완료 시 `🚩 [LOG] Firestore 엔진 안정화 및 시차 로딩 적용 완료` 로그. (2) `ExploreScreen` — `streamEnabled` 파라미터, initState/didUpdateWidget에서 스트림 변수 캐시(_exploreStream), streamEnabled false 시 로딩 표시. (3) `TodayScreen` — `streamEnabled` 파라미터, false 시 로딩 표시 후 DonorRankList/TodayThankYouGrid 렌더 안 함. (4) `DonorRankListFromFirestore` — initState에서 `recentDonationsStream(limit: 80)`을 `_cachedStream`에 할당 후 StreamBuilder에 전달. (5) `TodayThankYouGrid` — StatefulWidget으로 전환, initState에서 today_thank_you 스트림을 `_cachedStream`에 할당 후 StreamBuilder에 전달.
  - **홈 화면 무한 로딩 탈출 및 0원 노출 차단:** (1) `MainScreen` — 홈 콘텐츠에 `KeyedSubtree(key: ValueKey(_isStreamTab0Ready))`로 `_isStreamTab0Ready` 변경 시 강제 리빌드, 워터폴 시작 시 `🚩 [LOG] 워터폴 로딩 시작: 홈 탭` 로그. (2) `PlatformStatsCard` — 로딩/waiting/!hasData 시 ShimmerPlaceholder만 표시(0원 절대 노출). (3) `ApprovedPostsFeedSliver` — 3초 타임아웃 시 "데이터를 불러올 수 없습니다. 다시 시도해주세요" + [새로고침], 로딩 중 스켈레톤 카드 2개 표시, 에러 시 로그 및 따뜻한 안내. (4) `ShimmerPlaceholder` — 0원 대체용 회색 애니메이션 플레이스홀더(opacity 0.35~0.65 반복).
  - **소셜 로그인 UI 완성 및 구글 인증 연동:** 한국형 소셜 서비스 스타일에 맞게 로그인 화면 고도화. (1) `login_screen.dart` — 기존 로그인 버튼 하단에 "또는 소셜 계정으로 로그인" 안내 문구와 구분선 추가, 카카오톡/구글/네이버 원형 아이콘 버튼 3개 가로 정렬(구글은 브랜드 컬러 #4285F4, 카카오/네이버는 회색 톤), 카카오/네이버 버튼 클릭 시 "서비스 준비 중입니다" SnackBar 표시, 중복 클릭 방지 플래그(`_isLoggingInGoogle`) 추가. (2) `auth_repository.dart` — `google_sign_in` 패키지를 사용한 `signInWithGoogle()` 메서드 구현, 구글 로그인 성공 시 Firestore `users` 컬렉션에 자동 저장/업데이트(기존 유저는 정보 업데이트, 신규 유저는 생성), 신규 유저는 기본 `role`을 `viewer`로 설정하여 온보딩 필요 상태 표시, 프로필 이미지(photoUrl) 자동 저장, 로그인 성공 시 스트림 서비스 초기화. (3) `pubspec.yaml` — `google_sign_in: ^6.2.1`, `intl: ^0.19.0` 패키지 추가. (4) `web/index.html` — 구글 클라이언트 ID 메타 태그 추가.
  - **구글 로그인 기반 사용자 온보딩 시스템:** 구글 로그인 후 필수 정보 수집을 위한 스마트 온보딩 구현. (1) `user_model.dart` — `hasRequiredOnboardingInfo` getter 추가(생년월일 필수, 회원 유형은 viewer 포함 모든 타입 허용). (2) `additional_info_screen.dart` — 신규 유저 또는 필수 정보 누락 유저를 위한 추가 정보 입력 화면 생성, 생년월일 DatePicker(한국어 로케일, 코랄 테마), 회원 유형 선택(환자/후원자/일반회원) 카드형 UI, 정보 저장 후 메인 화면으로 이동. (3) `auth_repository.dart` — `updateUserOnboardingInfo()` 메서드 추가(생년월일, 회원 유형 업데이트), `signInWithGoogle()` 수정(신규 유저는 기본 role을 viewer로 설정, 생년월일 없음으로 초기화). (4) `login_screen.dart` — 구글 로그인 성공 후 `hasRequiredOnboardingInfo` 체크, 필수 정보 누락 시 `AdditionalInfoScreen`으로 리다이렉트, 필수 정보 완료 시 메인 화면으로 이동.
  - **Firestore imageUrls gs:// URL 지원:** Firestore에 `gs://...` 형태로 저장된 이미지 URL을 앱에서 HTTPS 다운로드 URL로 변환해 표시. (1) `gs_url_resolver.dart` — `resolveImageUrl(url)`로 gs:// → `FirebaseStorage.refFromURL().getDownloadURL()` 변환, 메모리 캐시(`_gsToHttpsCache`)로 재요청 방지. (2) `cached_network_image_gs.dart` — gs:///https 공통 `CachedNetworkImage` 래퍼 `CachedNetworkImageGs`(placeholder/errorWidget 지원). (3) 탐색 탭 `ExploreScreen` 그리드 타일, 상세 `PostDetailScreen` 이미지 목록에서 `CachedNetworkImage` → `CachedNetworkImageGs`로 교체하여 gs:// 자동 처리.

---

## [File Changes]

- **생성/수정된 주요 파일 및 경로**

| 경로 | 역할 |
|------|------|
| `lib/main.dart` | 앱 진입점. Firebase 초기화 후 Firestore settings(persistenceEnabled: false). loadCurrentUser 후 WithApp → MainScreen |
| `lib/core/constants/app_colors.dart` | 전역 색상 상수 AppColors (yellow/coral/textPrimary 등) |
| `lib/core/constants/admin_account.dart` | 관리자 계정 상수 AdminAccount (id: admin, password: admin0000) |
| `lib/core/constants/assets.dart` | WithMascots(마스코트 이미지 경로). `images/xxx` 사용 → 웹 빌드 시 build/web/assets/images/ 로 출력 |
| `images/` (루트) | 에셋 이미지 폴더. pubspec `images/` 등록. mascot_p.png, image_48dd69.png 등 배치 |
| `lib/core/auth/user_model.dart` | UserModel, UserType, MemberStatus. joinedAt/status/trustScore/isVerified, copyWith |
| `lib/core/auth/auth_repository.dart` | AuthRepository(싱글톤). getUsers/updateUser, SharedPreferences 저장, `signInWithGoogle()` 구글 소셜 로그인 구현, `updateUserOnboardingInfo()` 온보딩 정보 업데이트 |
| `lib/features/auth/additional_info_screen.dart` | 구글 로그인 후 신규 유저 또는 필수 정보 누락 유저의 추가 정보 입력 화면. 생년월일 DatePicker, 회원 유형 선택(환자/후원자/일반회원) |
| `lib/core/constants/responsive_breakpoints.dart` | ResponsiveBreakpoints (mobileMax 600px) |
| `lib/core/theme/app_theme.dart` | AppTheme.lightTheme (ThemeData) |
| `lib/core/util/responsive_util.dart` | ResponsiveHelper (isMobile/isDesktop/screenWidth) |
| `lib/shared/widgets/responsive_layout.dart` | ResponsiveLayout (mobileChild/desktopChild 분기) |
| `lib/shared/widgets/with_header.dart` | WithHeader (WITH 로고, 좌측 사람 아이콘 onPersonTap, 알림, showBackButton) |
| `lib/shared/widgets/donation_progress_card.dart` | DonationProgressCard (후원 금액 카드, Stack 입체감) |
| `lib/shared/widgets/today_feed_toggle.dart` | TodayFeedToggle (투데이/피드 전환) |
| `lib/shared/widgets/bottom_navigation.dart` | BottomNavBar (홈/탐색/작성/투데이/마이페이지 5탭, 아웃라인 아이콘) |
| `lib/shared/widgets/login_prompt_dialog.dart` | LoginPromptDialog (show/showAsBottomSheet — 로그인·회원가입 유도) |
| `lib/shared/widgets/feed_card.dart` | FeedCard (피드 한 건: authorName, likeCount, bodyText 등) |
| `lib/shared/widgets/donor_rank_list.dart` | DonorRankList / DonorRankItem. DonorRankListFromFirestore: initState에서 _cachedStream 할당 |
| `lib/features/main/main_screen.dart` | MainScreen. 폭포수형 순차 로딩(_phaseFeedReady/_phaseStatsReady), admin 로그인 시 AdminMainScreen pushReplacement |
| `lib/features/main/main_content_mobile.dart` | MainContentMobile (displayNickname으로 첫 피드 작성자명) |
| `lib/features/main/main_content_desktop.dart` | MainContentDesktop (displayNickname으로 첫 피드 작성자명) |
| `lib/features/auth/login_screen.dart` | LoginScreen (아이디/비밀번호, 관리자·일반 로그인, 회원가입 링크) |
| `lib/features/auth/signup_screen.dart` | SignupScreen (후원자/환자 선택 → 상세 정보 입력, AuthRepository.signUp) |
| `lib/features/admin/admin_main_screen.dart` | AdminMainScreen. 가드, 헤더·로그아웃, 통계 카드, 회원 리스트·상세보기 |
| `lib/features/admin/admin_member_detail_screen.dart` | 회원 상세: 기본정보·Trust Score·투병/후원 영역·인증 완료·저장 |
| `lib/core/constants/firestore_keys.dart` | FirestorePostKeys, ThankYouPostKeys, BugReportKeys, FirestoreCollections(bugReports) |
| `lib/core/services/imgbb_upload.dart` | ImgBB API 업로드. imgbbApiKey, readAsBytes→base64→POST, data.url 반환. [SYSTEM] 로그 |
| `lib/core/services/with_pay_service.dart` | getWithPayBalance, withPayBalanceStream(userId별 캐시 1회 구독, _isInitialized 플래그로 중복 구독 방지), balanceFromSnapshot, rechargeWithPay, initializeWithPayService(), clearWithPayStreamCache() |
| `lib/core/services/payment_method.dart` | PaymentMethod(card/kakao/naver/toss) enum |
| `lib/core/services/payment_service.dart` | startPay(context, userId, amount, method) — PG 교체용 진입점, 현재 가상 결제 |
| `lib/core/services/donation_service.dart` | platformStatsStream, processPaymentWithWithPay, donationsStreamByUser |
| `lib/core/services/bug_report_service.dart` | imgbb API로 이미지 업로드(Storage 미사용). uploadBugReportImage, submitBugReport, updateBugReportStatus |
| `lib/shared/widgets/bug_report_bottom_sheet.dart` | 버그 제보 ModalBottomSheet. 텍스트 입력·이미지 첨부(선택)·제출 로딩·성공 스낵바 |
| `lib/features/main/with_pay_recharge_dialog.dart` | showWithPayRechargeDialog, RechargeScreen(충전 페이지) |
| `lib/features/main/with_pay_payment_flow.dart` | showPaymentMethodSheet, PaymentWebViewMock, RechargeSuccessScreen |
| `lib/features/main/explore_screen.dart` | 탐색 탭 — SliverGrid n×3 인스타 스타일. streamEnabled 시에만 스트림 구독, initState에서 _exploreStream 캐시. 그리드 타일 이미지에 CachedNetworkImageGs(gs:// 지원). |
| `lib/features/main/diary_screen.dart` | 작성 탭 — 환자(투병/감사편지/내 게시물), 후원자(후원 중인 환자 목록→PatientPostsListScreen), 비로그인(바텀시트) |
| `lib/features/main/today_screen.dart` | 투데이 탭 — streamEnabled 시에만 DonorRankList·TodayThankYouGrid 렌더, 실시간 기부 순위 + 베스트 감사편지 |
| `lib/features/main/post_create_choice_screen.dart` | 게시글 작성 선택: 투병 기록 남기기 → PostUploadScreen / 감사 편지 쓰기 → ThankYouPostListScreen (관리자 대시보드 진입 포함) |
| `lib/features/main/thank_you_post_list_screen.dart` | 현재 유저의 승인된 투병 기록 목록, 선택 시 ThankYouLetterUploadScreen |
| `lib/features/main/thank_you_letter_upload_screen.dart` | 감사 편지 폼(제목·내용·사진 0~3장) → thank_you_posts 저장 |
| `lib/features/post/post_upload_screen.dart` | 투병 기록: 제목/내용(20자 이상)/사진(0~3장), type struggle, "검토 후 업로드됩니다." |
| `lib/features/post/post_detail_screen.dart` | 승인된 사연 상세. isDonationRequest일 때만 후원하기 버튼·usagePurpose 블록 노출. 좋아요 아이콘 coral. 이미지 목록에 CachedNetworkImageGs(gs:// 지원). |
| `lib/shared/widgets/story_feed_card.dart` | 피드 카드. isLikedStream 기반 빈하트/채운하트(coral), 하트 탭 시 toggleLike. |
| `lib/shared/widgets/approved_posts_feed.dart` | 승인 피드 스트림 전역 캐시. ApprovedPostsFeedSliver: 스켈레톤 2개, 3초 타임아웃 시 새로고침 안내, 에러 로그 |
| `lib/shared/widgets/shimmer_placeholder.dart` | ShimmerPlaceholder — 로딩 중 0원 노출 차단용 회색 애니메이션(opacity 0.35~0.65 반복) |
| `lib/shared/widgets/platform_stats_card.dart` | 후원 현황. platform_stats 스트림 구독, 문서 없으면 0원 표시, MainVisualCard |
| `lib/shared/widgets/today_thank_you_grid.dart` | 투데이 감사편지 그리드. StatefulWidget, initState에서 today_thank_you 스트림 캐시. isLikedStream 기반 하트 아이콘·탭 토글. |
| `lib/features/main/thank_you_detail_screen.dart` | 감사편지 상세. 좋아요 아이콘 AppColors.coral 적용. |
| `lib/features/admin/admin_dashboard_screen.dart` | 탭 [투병 기록 승인][감사 편지 승인]. 투병 기록: 필터(전체/일반/후원), 카드 배지(일반 기록·후원 요청), 상세 시트 상단 태그·후원 요약. 감사 편지 리스트 탭 시 AdminThankYouDetailScreen push |
| `lib/features/admin/admin_main_screen.dart` | 사이드바: 플랫폼 대시보드, 사용자 관리, 후원 내역, 게시글 승인, **어드민 게시물 관리**, 병원/기관, 버그 제보 관리 |
| `lib/features/admin/admin_post_management_section.dart` | 어드민 게시물 작성 폼(카테고리·이미지·제목·내용·링크·배지), 등록 리스트·삭제. 탐색 탭 배너용 |
| `lib/core/services/admin_post_service.dart` | addAdminPost, deleteAdminPost, adminPostsStream — Firestore admin_posts |
| `lib/features/admin/admin_bug_report_management_section.dart` | bug_reports Firestore 스트림 리스트, 카드(상태 배지·내용·이미지 썸네일·기기정보), [해결 완료] 버튼 |
| `lib/features/admin/admin_thank_you_detail_screen.dart` | 관리자 전용 감사 편지 상세 풀스크린. 진입 시 admin 재확인, 하단 [삭제][승인], 이미지/환자명/내용/사용목적 레이아웃 |
| `lib/core/services/admin_service.dart` | deleteDocument(컬렉션 경로·docId), deletePost/deleteThankYouPost 래퍼, showDeleteConfirmDialog, approveThankYouPost |
| `lib/core/services/gs_url_resolver.dart` | gs:// URL → FirebaseStorage getDownloadURL() HTTPS 변환. 메모리 캐시로 동일 URL 재요청 방지. |
| `lib/shared/widgets/cached_network_image_gs.dart` | gs:///https 공통 CachedNetworkImage 래퍼(CachedNetworkImageGs). resolveImageUrl 후 CachedNetworkImage로 렌더. |

---

## [UI/UX Status]

- **Mobile**
  - 상단 노란 헤더(좌측 사람 아이콘→로그인, WITH 로고, 알림), 로그인 시 "안녕하세요, [닉네임]님", 분홍 후원 카드(입체감), 투데이/피드 토글
  - 피드: 수직 스크롤 피드 카드 리스트. 카드 탭 → PostDetailScreen(후원하기 → WITH Pay 잔액 확인·차감·충전 유도).
  - 투데이: 오늘의 베스트 후원자 + 한줄 후기 감사편지(Firestore `today_thank_you` 실시간 스트림) 가로 스크롤
  - **하단 네비 5탭:** 홈 / 탐색(그리드) / 작성(권한별 다이어리) / 투데이(기부·감사편지) / 마이페이지. 마이페이지 탭 비로그인 시 로그인 유도. 작성 탭 비로그인 시 바텀시트 자동 노출.
  - **마이페이지:** WITH Pay 카드(탭 시 충전 다이얼로그), 고객센터에 '버그 제보하기'·'WITH 페이 충전'·'전자기부금 영수증 발급' 메뉴. 버그 제보는 로그인 시 바텀시트로 텍스트·이미지 첨부 후 Firestore bug_reports 저장.

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

*마지막 갱신: Firestore imageUrls gs:// 지원 — gs_url_resolver, CachedNetworkImageGs 추가. ExploreScreen·PostDetailScreen 이미지에 CachedNetworkImageGs 적용.*
