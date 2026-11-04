---
name: ios-distribute
description: >-
  GitHub Actions로 iOS 앱을 빌드해 Firebase App Distribution(Ad Hoc)에 올리는
  `.github/workflows/ios-distribute.yml`을 만들거나 고치거나 실행·진단할 때 쓴다.
  iOS 빌드/서명/배포 Actions 실패, "does not support provisioning profiles",
  "flutterfire: command not found", pod install 실패, 업로드 실패,
  .p12·프로비저닝 프로파일·Secrets 준비 질문이 나오면 사용한다.
---
# iOS Distribute (Actions → Firebase App Distribution)

수동 실행(`workflow_dispatch`)으로 Ad Hoc IPA를 만들어 `testers` 그룹에 올린다.
추측하지 말고 Actions 로그를 직접 읽어서 원인을 찾는다. 한 번 도는 데 약 30분이 걸리니
수정은 로그로 원인을 확인한 뒤 한 번에 한다.

## 프로젝트 값 (비밀 아님)

- Bundle ID `com.bull.parrokit`, Team ID `X8P2QKDF7W`
- Firebase iOS 앱 ID `1:392832464036:ios:71b3e2d9c65fa1922e6231` (`firebase.json`)
- 워크플로 파일 `.github/workflows/ios-distribute.yml`, 러너 `macos-latest`
- 기본 브랜치는 `dev`. `workflow_dispatch`는 기본 브랜치에 파일이 있어야 웹의 Run 버튼이 보인다.
- 실행 브랜치는 `dev`로 제한되지 않는다. 배포할 변경이 있는 브랜치를 `ref`로 골라 돌리면 되고, `dev`에 merge할 필요는 없다. 단 `dev`로 돌리면 `dev`에 있는 코드만 올라간다.
- 앱은 CocoaPods 기반이다 (`ios/Podfile.lock`에 플러그인 Pod가 들어 있다).

## 파이프라인 순서

1. `.env` 생성 (커밋되지 않지만 pubspec assets에 있어서 필수)
2. 인증서(.p12)·프로비저닝 프로파일 설치 (임시 키체인)
3. `flutter config --no-enable-swift-package-manager`
4. `flutter pub get`
5. `dart pub global activate flutterfire_cli` + PATH 추가
6. `flutter build ios --release --no-codesign --config-only` (설정 생성 + pod install만)
7. `xcodeproj`(Ruby)로 **Runner 타깃 Release에만** 수동 서명 지정
8. `xcodebuild archive` (서명 설정을 명령줄로 넘기지 않는다)
9. `xcodebuild -exportArchive` (`method: ad-hoc`, ExportOptions.plist)
10. `firebase-tools`로 `*.ipa` 업로드

## 겪었던 실수와 해결

| 증상 (로그) | 원인 | 해결 |
|---|---|---|
| `Unable to find a specification for webview_flutter_wkwebview depended upon by google_mobile_ads` (pod install) | 최신 Flutter는 SwiftPM이 기본이라 SwiftPM 지원 플러그인을 Pod 목록에서 뺀다 | `flutter config --no-enable-swift-package-manager` |
| `flutterfire: command not found` (Xcode 빌드 단계) | Runner에 `flutterfire upload-crashlytics-symbols` 단계가 있는데 러너에 CLI가 없다 | `dart pub global activate flutterfire_cli`, `$HOME/.pub-cache/bin`을 PATH에 |
| 컴파일을 두 번 해서 25분 낭비 | `flutter build ios`와 `xcodebuild archive`가 둘 다 컴파일 | 앞은 `--config-only` |
| `<Pod> does not support provisioning profiles` (Archive, 34초 만에 실패) | `PROVISIONING_PROFILE_SPECIFIER` 등을 xcodebuild 명령줄로 넘기면 Pods 타깃 전체에 적용된다 | 명령줄 설정을 빼고 `xcodeproj`로 Runner Release 설정만 변경 |
| `Container action is only supported on Linux` (업로드, 0초) | `wzieba/Firebase-Distribution-Github-Action`은 Docker 액션이라 macOS에서 안 돈다 | macOS에서 `npx firebase-tools appdistribution:distribute` |
| `File .../export/Runner.ipa does not exist` | IPA 파일명을 추측했다 | 폴더의 `*.ipa`를 찾아 쓰고 `ls -la`를 로그에 남긴다 |

Runner 전용 서명 설정 스크립트는 `project.pbxproj` 복사본에 먼저 돌려 diff로
Runner Release 설정만 바뀌는지 확인했다. 이런 검증 가능한 수정은 푸시 전에 로컬에서 확인한다.

## 사전 준비 (사용자가 직접)

- **Apple Distribution 인증서**: Xcode가 만든 `Distribution Managed` 인증서는 개인 키가 Apple 서버에 있어
  `.p12`로 내보낼 수 없다. 키체인 접근의 `Certificate Assistant > Request a Certificate From a Certificate Authority...`로
  CSR을 만들고 Apple Developer에서 새 Apple Distribution 인증서를 발급한다. `My Certificates`에서 private key가 붙어 있는지 확인하고
  `.p12`로 내보낸다.
- **Ad Hoc 프로비저닝 프로파일**: App ID `com.bull.parrokit`, 위 인증서, 테스트 기기 UDID를 선택한다.
  기기 UDID는 Devices에서 먼저 등록한다. 푸시·로그인 등 앱이 쓰는 Capability가 App ID에 켜져 있어야 한다.
- **App Distribution 테스터 그룹**: 그룹 식별자(alias)가 workflow 입력과 같아야 한다 (기본 `testers`).
- **서비스 계정**: Firebase App Distribution Admin 권한, Google Cloud에서 Firebase App Distribution API 사용 설정.

## GitHub Secrets

| 이름 | 내용 |
|---|---|
| `ENV_FILE` | `.env` 전체 내용 |
| `IOS_CERT_P12_BASE64` | `base64 -i cert.p12`로 변환한 값 |
| `IOS_CERT_PASSWORD` | `.p12` 내보낼 때 정한 비밀번호 |
| `IOS_PROVISION_PROFILE_BASE64` | Ad Hoc `.mobileprovision`을 base64로 변환한 값 |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | 서비스 계정 JSON 전체 |

값을 코드, 로그, 답변에 적지 않는다. `.p12`는 Secret 등록 뒤 로컬에서 지운다.
workflow에서 Secret은 `env:`로 받아 쓰고, 서비스 계정 파일은 업로드 직후 지운다.

## 실패 진단 절차

1. 실행 목록에서 최신 run과 job의 단계별 `conclusion`을 본다. 어느 단계에서 실패했는지 먼저 정한다.
2. 실패한 job의 로그 끝부분을 읽는다. 로그 끝은 정리 단계로 가득 차 있으니 `error`, `failed`, `does not` 같은 줄을 찾는다.
3. 위 표에 있는 증상이면 해당 해결을 적용한다. 없으면 로그 근거로 원인을 정한다. 추정이면 추정이라고 말한다.
4. 단계 소요 시간으로 단서를 얻는다. 0초에 끝난 단계는 시작도 못 한 것이고, 30초 안에 끝난 Archive는 컴파일이 아니라 설정 오류다.
5. 고친 뒤에는 한 번 더 돌려 다음 단계로 넘어갔는지까지 확인한다. 한 단계 통과를 전체 성공으로 말하지 않는다.

## 실행과 결과 확인

- 정상 소요 시간: pod install 약 7분, Archive 12~24분, export 약 25초, 업로드 약 30초, 전체 약 30~35분.
- 성공의 기준은 모든 단계가 `success`인 것이다. 앱이 폰에 설치되는지는 사용자가 확인해야 하고,
  설치가 안 되면 먼저 UDID가 프로파일에 있는지 본다.
- 빌드 번호: 워크플로가 `pubspec.yaml`의 `+N`에 실행 번호(`github.run_number`)를 더해 매번 올린다
  (예: `+98`, 실행 #10 → 108). Archive 뒤 "빌드 번호 확인" 단계가 실제 반영 여부를 검사한다.
  나중에 TestFlight로 가면 번호는 올라가야 한다.

### 배포 위치가 다르면 중복 빌드가 배포된다 (헷갈렸던 부분)

Firebase App Distribution은 `버전 + 빌드 번호`가 같은지로 릴리스를 구분한다. 올리는 방법에 따라 결과가 다르다.

| 올린 방법 | 같은 버전·빌드 번호일 때 |
|---|---|
| 로컬/콘솔에서 직접 업로드 | 새 릴리스 항목이 따로 생긴다. 같은 `1.0.6 (98)`이 목록에 중복으로 보인다. |
| Actions의 `firebase-tools` CLI (`appdistribution:distribute`) | 새 항목 없이 기존 릴리스의 파일만 덮어쓴다(로그에 `uploaded update to existing release`). 목록에 안 뜨고 테스터 메일도 안 간다. |

- 그래서 "Actions는 성공인데 목록에 없다/메일이 안 온다"면 먼저 로그에서 `update to existing release`가 있는지 본다.
  실제 사례: 같은 `1.0.6 (98)`을 run #6이 만든 뒤 #7, #8, #9가 전부 그 릴리스를 덮어썼다.
- 덮어쓴 릴리스의 날짜는 처음 만든 시각 그대로이고, 이미 설치한 기기는 같은 번호라 업데이트로 인식하지 않을 수 있다.
- 로컬과 Actions를 섞어 쓰면 같은 번호가 겹쳐 중복 빌드가 생기고 어느 것이 최신인지 헷갈린다.
  배포 위치는 하나로 정하거나, 번호가 겹치지 않게 한다(Actions 번호는 위처럼 자동으로 올라간다).
- 브랜치(`dev`인지 아닌지)는 이 동작과 무관하다. Firebase에는 브랜치 정보가 가지 않는다.
- Android는 아직 만들지 않았다 (사용자가 나중으로 미뤘다).

## 지킬 것

- 커밋·푸시·PR·머지는 사용자가 요청할 때만 한다. 이 프로젝트의 PR 대상은 `dev`이다.
- 워크플로 수정은 YAML 문법을 확인하고, 확인하지 못한 부분(macOS 러너 실제 동작)은 PR 본문에 사실대로 적는다.
