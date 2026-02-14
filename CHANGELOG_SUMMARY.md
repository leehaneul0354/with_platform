# 수정 사항 요약 (GitHub 푸시 전)

## 1. 이미지 에러 해결 (mascot_p.png 404)

### 조치 내용
- **경로 통일**: 프로젝트 전체에서 마스코트 이미지 경로는 **`assets/images/...`** 만 사용하도록 유지했습니다. (`assets/assets/` 중복 호출 없음)
- **코드**: `lib/core/constants/assets.dart`의 `WithMascots` 상수는 모두 `assets/images/mascot_p.png` 등 **`assets/images/`** 로만 정의되어 있습니다.
- **사용처**: `lib/features/main/my_page_screen.dart`에서 `Image.asset(WithMascots.yellowSmile)` 로만 참조하며, 별도 경로를 붙이지 않습니다.
- **pubspec.yaml**: `assets: - assets/images/` 로 디렉터리 등록되어 있으며, 주석으로 “코드에서는 `assets/images/xxx` 만 사용, `assets/assets/` 중복 금지” 및 “`assets/images/` 폴더에 `mascot_p.png` 등 이미지 파일이 있어야 함”을 명시했습니다.

### 404가 계속될 때 확인할 것
- **파일 존재 여부**: `assets/images/mascot_p.png` 파일이 실제로 있는지 확인하세요. 없으면 해당 경로에 이미지를 추가해야 합니다.
- **빌드**: `flutter clean` 후 `flutter pub get` 실행 후 다시 실행해 보세요.

---

## 2. 코드 최적화 및 구조화

### 2-1. 사용하지 않는 import / 변수
- **dart analyze** 기준 미사용 import/변수로 인한 이슈는 없었습니다.
- **프로덕션 로그**: `print` 사용을 `debugPrint`로 변경했습니다.
  - `lib/core/auth/auth_repository.dart`: signUp catch 블록
  - `lib/features/auth/signup_screen.dart`: _submitStep2 catch 블록

### 2-2. UserModel 역할(role) 및 Firestore 키 상수화
- **역할(role)**: 이미 `UserType` enum(donor, patient, admin)으로 관리되고 있으며, Firestore에는 `type.name`으로 문자열 저장됩니다. 별도 role 필드 enum 추가는 하지 않았습니다.
- **Firestore 키 상수화**:
  - **신규 파일**: `lib/core/constants/firestore_keys.dart`
    - `FirestoreUserKeys` 클래스에 `userId`, `id`, `email`, `password`, `nickname`, `role`, `type`, `trustScore`, `birthDate`, `createdAt`, `joinedAt`, `isVerified`, `name`, `birthdate` 상수 정의.
  - **적용 위치**:
    - `lib/core/auth/user_model.dart`: `fromJson`, `_readBirthDate`, `toJson`에서 위 상수 사용.
    - `lib/core/auth/auth_repository.dart`: signUp, resetPasswordByIdAndBirthDate, seedTestAccountsWithBirthDateIfNeeded 등 Firestore 읽기/쓰기 시 위 상수 사용.

### 2-3. BirthDateUtil 주석 및 로직
- **파일**: `lib/core/util/birth_date_util.dart`
- **추가/정리한 내용**:
  - 상단 library 문서: Firestore 저장 형식(YYYY-MM-DD), UI 표시 형식, 1900/2000년대 구분 규칙 설명.
  - `yymmddToIso`: YY와 현재 연도(뒤 2자리) 비교 규칙, 월(01~12)·일(01~31) 검사, 일(day)은 1~31만 검사한다는 점과 필요 시 `DateTime.tryParse`로 엄격 검사 가능하다는 설명 추가.
  - `formatBirthDateForDisplay`: YYYY-MM-DD / 레거시 6자리 / null 처리 동작 설명.
  - `isValidYymmdd`: 검사 범위(길이, 숫자, 월, 일) 설명.
  - **로직**: 기존 규칙(YY > 현재연도 → 19YY, 그 외 20YY, 월·일 범위 검사) 유지. `library;` 지시 추가로 dangling library doc comment 경고 해소.

---

## 3. 수정/추가된 파일 목록

| 구분 | 파일 |
|------|------|
| **신규** | `lib/core/constants/firestore_keys.dart` |
| **수정** | `lib/core/auth/user_model.dart` (Firestore 키 상수 사용) |
| **수정** | `lib/core/auth/auth_repository.dart` (Firestore 키 상수 사용, debugPrint) |
| **수정** | `lib/core/util/birth_date_util.dart` (주석 보강, library 지시) |
| **수정** | `lib/features/auth/signup_screen.dart` (debugPrint) |
| **수정** | `pubspec.yaml` (assets 주석) |

---

## 4. GitHub 푸시 전 체크

- [x] 이미지 경로 `assets/images/` 로 통일, pubspec 확인
- [x] Firestore 키 상수로 관리
- [x] BirthDateUtil 주석·로직 점검
- [x] `dart analyze lib` 통과 (No issues found.)
- [ ] `assets/images/mascot_p.png` 등 실제 이미지 파일 존재 여부 확인 (로컬에서 404 시)

위 내용 반영 후 커밋·푸시하시면 됩니다.
