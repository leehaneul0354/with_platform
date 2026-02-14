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

---

## [File Changes]

- **생성/수정된 주요 파일 및 경로**

| 경로 | 역할 |
|------|------|
| `lib/main.dart` | 앱 진입점. WithApp → AppTheme → MainScreen |
| `lib/core/constants/app_colors.dart` | 전역 색상 상수 AppColors (yellow/coral/textPrimary 등) |
| `lib/core/constants/responsive_breakpoints.dart` | ResponsiveBreakpoints (mobileMax 600px) |
| `lib/core/theme/app_theme.dart` | AppTheme.lightTheme (ThemeData) |
| `lib/core/util/responsive_util.dart` | ResponsiveHelper (isMobile/isDesktop/screenWidth) |
| `lib/shared/widgets/responsive_layout.dart` | ResponsiveLayout (mobileChild/desktopChild 분기) |
| `lib/shared/widgets/with_header.dart` | WithHeader (WITH 로고 + 알림, showBackButton) |
| `lib/shared/widgets/donation_progress_card.dart` | DonationProgressCard (후원 금액 카드, Stack 입체감) |
| `lib/shared/widgets/today_feed_toggle.dart` | TodayFeedToggle (투데이/피드 전환) |
| `lib/shared/widgets/bottom_navigation.dart` | BottomNavBar (홈/추가/마이페이지) |
| `lib/shared/widgets/login_prompt_dialog.dart` | LoginPromptDialog (로그인·회원가입 유도) |
| `lib/shared/widgets/feed_card.dart` | FeedCard (피드 한 건: authorName, likeCount, bodyText 등) |
| `lib/shared/widgets/donor_rank_list.dart` | DonorRankList / DonorRankItem (후원자 순위) |
| `lib/features/main/main_screen.dart` | MainScreen (헤더·카드·토글·본문·하단네비·로그인 유도) |
| `lib/features/main/main_content_mobile.dart` | MainContentMobile (모바일 단일 컬럼) |
| `lib/features/main/main_content_desktop.dart` | MainContentDesktop (데스크톱 2컬럼) |

---

## [UI/UX Status]

- **Mobile**
  - 상단 노란 헤더(WITH 로고 + 알림), 분홍 후원 카드(입체감), 투데이/피드 토글
  - 피드: 수직 스크롤 피드 카드 리스트
  - 투데이: 오늘의 베스트 후원자 + 한줄 후기 감사편지 가로 스크롤
  - 하단 네비: 홈 / 추가 / 마이페이지 (추가·마이페이지 비로그인 시 로그인 유도)

- **Web / Desktop**
  - 동일 헤더·후원 카드·토글
  - 2컬럼: 좌측 피드 또는 투데이 콘텐츠, 우측 고정 너비(320px) 후원자 순위
  - 하단 네비 없음, 우측 하단 «나도 후원하기» 버튼 (비로그인 시 로그인 유도)

---

## [Next Steps]

- 로그인/회원가입 실제 화면 및 라우팅 연동
- 순위 전체보기 전용 화면 (이미지의 «순위 전체보기» UI)
- 후원하기 플로우 화면
- API 연동 (후원 금액, 피드 목록, 순위 목록)
- 이미지 에셋 및 네트워크 이미지 URL 연동

---

## [Dependencies]

- **프론트–백엔드 연결점**
  - API base URL: TBD
  - 예정 엔드포인트: 현재 후원 금액, 피드 목록, 후원자 순위, 인증(로그인/회원가입)

---

## [Data Flow / 호출 순서]

1. **앱 기동**  
   `main()` → `WithApp` (MaterialApp, theme: `AppTheme.lightTheme`) → `home: MainScreen`

2. **메인 화면**  
   `MainScreen` → `WithHeader` + `DonationProgressCard` + `ResponsiveLayout(mobileChild, desktopChild)`  
   - 모바일: `TodayFeedToggle` + `MainContentMobile` (피드 리스트 or 투데이 섹션)  
   - 데스크톱: `MainContentDesktop` (좌: 토글+콘텐츠, 우: `DonorRankList`)

3. **로그인 유도**  
   비로그인 상태에서 하단 «추가»/«마이페이지» 탭 또는 «나도 후원하기» 클릭  
   → `LoginPromptDialog.show()` → 로그인/회원가입 버튼 (추후 화면 라우팅)

4. **참조 관계**  
   - `core/constants` → `core/theme`, `shared/widgets`  
   - `core/util` (ResponsiveHelper) → `shared/widgets`, `features/main`  
   - `shared/widgets` → `features/main` (메인에서 공통 위젯 사용)

---

*마지막 갱신: 메인 화면 반응형 UI 및 로그인 유도 로직 구현 완료.*
