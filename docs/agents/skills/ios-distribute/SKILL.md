---
name: ios-distribute
description: >-
  맥에서 직접 iOS Ad Hoc IPA를 빌드해 Firebase App Distribution에 올릴 때 쓴다.
  `flutter build ipa` 실패, 서명·프로비저닝 프로파일 문제, App Distribution
  업로드 실패, 올렸는데 목록에 안 보이거나 테스터에게 메일이 안 갈 때,
  인증서·프로파일·테스터 그룹 준비 질문이 나오면 사용한다.
---
# iOS Distribute (로컬 빌드 → Firebase App Distribution)

맥에서 Ad Hoc IPA를 만들어 `testers` 그룹에 올린다. 추측하지 말고 빌드 로그를
직접 읽어서 원인을 찾는다. 한 번 빌드에 10~20분이 걸리니 수정은 로그로 원인을
확인한 뒤 한 번에 한다.

GitHub Actions 경로는 2026-11-17에 걷어냈다(사용자 결정: 안 쓴다).
워크플로 파일도 지웠으니 되살리지 않는다. GitHub Secrets(ENV_FILE,
IOS_CERT_P12_BASE64 등)는 저장소 설정에 남아 있을 수 있다 - 치우려면
사용자가 GitHub에서 직접 지운다.

## 프로젝트 값 (비밀 아님)

- Bundle ID `com.bull.parrokit`, Team ID `X8P2QKDF7W`
- Firebase iOS 앱 ID `1:392832464036:ios:71b3e2d9c65fa1922e6231` (`firebase.json`)
- 기본 브랜치는 `dev`
- 앱은 CocoaPods 기반이다 (`ios/Podfile.lock`에 플러그인 Pod가 들어 있다)
- 서명은 **자동**(`CODE_SIGN_STYLE = Automatic`), 팀은 위 Team ID

## 올리는 절차

### 1. 올리기 전 확인

```bash
grep -n "^version:" pubspec.yaml
df -h / | tail -1 | awk '{print $4}'
ls .env
security find-identity -v -p codesigning | grep Distribution
```

- `.env`는 커밋되지 않지만 pubspec assets에 있어서 없으면 빌드가 깨진다.
- `Apple Distribution` 인증서가 보여야 한다.
- Ad Hoc 프로파일이 있는지도 본다. 기기 UDID가 들어 있는 것만 쓸 수 있다:

```bash
for f in ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/*.mobileprovision; do security cms -D -i "$f" | plutil -extract Name raw -; done
```

### 2. 빌드

```bash
flutter build ipa --release --export-method ad-hoc
```

결과는 `build/ios/ipa/*.ipa`. 10~20분 걸리므로 백그라운드로 돌리고 로그를
파일에 받는다.

### 3. 업로드

```bash
npx -y firebase-tools@latest appdistribution:distribute build/ios/ipa/*.ipa --app 1:392832464036:ios:71b3e2d9c65fa1922e6231 --groups testers
```

IPA 파일명은 추측하지 말고 `ls build/ios/ipa/`로 확인한다.

### 4. 올린 뒤 확인

- 업로드 출력에 릴리스 링크가 나온다. 버전과 빌드 번호가 의도한 것인지 본다.
- 앱이 폰에 설치되는지는 사용자가 확인해야 하고, 설치가 안 되면 먼저 그 기기
  UDID가 프로파일에 있는지 본다.

## 빌드 번호와 중복 릴리스

Firebase App Distribution은 `버전 + 빌드 번호`가 같은지로 릴리스를 구분한다.

- 번호는 `pubspec.yaml`의 `version: 1.0.6+120`에서 온다. **루프 규칙상 이 값을
  마음대로 바꾸지 않는다.** 올려야 하면 사용자에게 먼저 묻는다.
- 같은 번호로 또 올리면 **새 릴리스 항목이 따로 생긴다.** 목록에 같은
  `1.0.6 (120)`이 둘로 보인다.
- 이미 설치한 기기는 번호가 같으면 업데이트로 인식하지 않을 수 있다.
- Android는 아직 만들지 않았다 (사용자가 나중으로 미뤘다).

## 사전 준비 (사용자가 직접)

- **Apple Distribution 인증서**: Xcode가 만든 `Distribution Managed` 인증서는
  개인 키가 Apple 서버에 있어 `.p12`로 내보낼 수 없다. 키체인 접근의
  `Certificate Assistant > Request a Certificate From a Certificate Authority...`로
  CSR을 만들고 Apple Developer에서 새 Apple Distribution 인증서를 발급한다.
  `My Certificates`에서 private key가 붙어 있는지 확인한다.
- **Ad Hoc 프로비저닝 프로파일**: App ID `com.bull.parrokit`, 위 인증서,
  테스트 기기 UDID를 선택한다. 기기 UDID는 Devices에서 먼저 등록한다.
  푸시·로그인 등 앱이 쓰는 Capability가 App ID에 켜져 있어야 한다.
- **App Distribution 테스터 그룹**: 그룹 식별자(alias)가 `--groups` 값과 같아야
  한다 (기본 `testers`).
- **Firebase CLI 로그인**: `npx -y firebase-tools@latest login:list`로 확인한다.

## 실패 진단 절차

1. 빌드 로그 끝부분을 읽는다. 로그 끝은 정리 단계로 가득 차 있으니
   `error`, `failed`, `does not`, `No profiles` 같은 줄을 찾는다.
2. 아래 표에 있는 증상이면 해당 해결을 적용한다. 없으면 로그 근거로 원인을
   정한다. 추정이면 추정이라고 말한다.
3. 단계 소요 시간으로 단서를 얻는다. 몇 초 만에 끝난 Archive는 컴파일이 아니라
   설정 오류다.
4. 고친 뒤에는 한 번 더 돌려 다음 단계로 넘어갔는지까지 확인한다. 한 단계
   통과를 전체 성공으로 말하지 않는다.

| 증상 (로그) | 원인 | 해결 |
|---|---|---|
| `No profiles for 'com.bull.parrokit' were found` | Ad Hoc 프로파일이 없거나 만료 | Xcode로 열어 한 번 빌드하거나 Apple Developer에서 새로 받는다 |
| `Unable to find a specification for webview_flutter_wkwebview depended upon by google_mobile_ads` (pod install) | 최신 Flutter는 SwiftPM이 기본이라 SwiftPM 지원 플러그인을 Pod 목록에서 뺀다 | `flutter config --no-enable-swift-package-manager` |
| `flutterfire: command not found` (Xcode 빌드 단계) | Runner에 `flutterfire upload-crashlytics-symbols` 단계가 있는데 CLI가 없다 | `dart pub global activate flutterfire_cli`, `$HOME/.pub-cache/bin`을 PATH에 |
| `Unicode Normalization not appropriate for ASCII-8BIT` (pod install) | 로케일이 ASCII | `LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8`을 앞에 붙인다 |
| `File .../export/Runner.ipa does not exist` | IPA 파일명을 추측했다 | 폴더의 `*.ipa`를 찾아 쓰고 `ls -la`로 확인한다 |

## 지킬 것

- 커밋·푸시·PR·머지는 사용자가 요청할 때만 한다. 이 프로젝트의 PR 대상은 `dev`.
- `pubspec.yaml`의 버전과 빌드 번호는 사용자가 요청할 때만 바꾼다.
- 키·토큰·비밀번호를 코드, 로그, 답변에 적지 않는다.
- 확인하지 못한 것은 사실대로 말한다. 업로드 성공과 "폰에 설치됨"은 다르다.
