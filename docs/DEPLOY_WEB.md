# Flutter Web 배포 (Firebase Hosting)

## 배포 전 클린 빌드 명령어 세트

배포 전 반드시 아래 순서로 실행하여 캐시·이전 빌드 잔여물을 제거한 뒤 다시 빌드하세요.

```bash
# 1. 이전 빌드·캐시 제거
flutter clean

# 2. 패키지 의존성 다시 가져오기
flutter pub get

# 3. 웹 릴리스 빌드
flutter build web --release

# 4. (선택) Firebase 프로젝트 지정 후 배포
firebase use with-platform-ccc06
firebase deploy
```

## 이미지 404 발생 시 점검

- **경로**: 코드·pubspec 모두 `assets/images/파일명` (선행 `/` 없음)
- **파일명**: 실제 파일명과 대소문자·확장자가 정확히 일치하는지 확인 (`assets/images/` 폴더)
- **캐시**: `web/index.html`에 캐시 방지 메타 태그가 있으므로, 배포 후에도 이전 버전이 보이면 브라우저에서 강력 새로고침(Ctrl+Shift+R) 또는 시크릿 창으로 확인
