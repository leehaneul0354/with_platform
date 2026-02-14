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

---

## [UI/UX Status]

- **Mobile**
  - 상단 노란 헤더(좌측 사람 아이콘→로그인, WITH 로고, 알림), 로그인 시 "안녕하세요, [닉네임]님", 분홍 후원 카드(입체감), 투데이/피드 토글
  - 피드: 수직 스크롤 피드 카드 리스트
  - 투데이: 오늘의 베스트 후원자 + 한줄 후기 감사편지 가로 스크롤
  - 하단 네비: 홈 / 추가 / 마이페이지 (추가·마이페이지 비로그인 시 로그인 유도)

- **Web / Desktop**
  - 동일 헤더·후원 카드·토글
  - 2컬럼: 좌측 피드 또는 투데이 콘텐츠, 우측 고정 너비(320px) 후원자 순위
  - 하단 네비 없음, 우측 하단 «나도 후원하기» 버튼 (비로그인 시 로그인 유도)

---

## [Next Steps]

- 순위 전체보기 전용 화면 (이미지의 «순위 전체보기» UI)
- 로그아웃 버튼(마이페이지 또는 헤더 메뉴)
- 후원하기 플로우 화면
- API 연동 (후원 금액, 피드 목록, 순위 목록)
- **이미지 에셋:** `images/` 폴더에 실제 파일 추가 (mascot_p.png, image_48dd69.png 등). 경로는 `images/파일명`으로 통일해 웹 빌드 시 `assets/assets/` 중복 404 방지됨.
- 네트워크 이미지 URL 연동

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

6. **참조 관계**  
   - `core/constants` → `core/theme`, `shared/widgets`  
   - `core/util` (ResponsiveHelper) → `shared/widgets`, `features/main`  
   - `core/auth` (UserModel, AuthRepository) → `features/auth`, `features/main`  
   - `shared/widgets` → `features/main`, `features/auth`  
   - `features/auth` (LoginScreen, SignupScreen) → `core/auth`, `shared/widgets`  
   - `features/admin` (AdminMainScreen, AdminMemberDetailScreen) → `core/auth`, `features/main`(복귀용)

---

*마지막 갱신: 이미지 경로 수정(assets/assets/ 404 해결 → 루트 images/ 사용), Firebase 프로젝트 고정(with-platform-ccc06), 웹 릴리스 빌드·배포 완료.*
