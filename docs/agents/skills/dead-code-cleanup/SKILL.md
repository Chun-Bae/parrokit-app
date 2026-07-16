---
name: dead-code-cleanup
description: >-
  Finds unused/dead code in this repo (Dart lib/ via the unreachable_from_main
  lint, TypeScript functions/ via knip) and reports a verified candidate list.
  Never deletes without explicit user approval. Use when the user asks to find
  dead code, clean up unused code/files, or check for unreachable members.
---
# Dead Code Cleanup

이 리포는 DCM(Dart Code Metrics)을 쓸 수 없다(realm_dart가 최신 Dart SDK와
호환 깨짐, `dart pub global activate dcm` 빌드 실패, 업스트림 미해결).
대신 아래 두 가지 무료 방법을 조합해서 죽은 코드를 찾는다.

## 원칙

- **삭제는 절대 자동으로 하지 않는다.** 후보를 찾아서 grep으로 교차검증한
  결과만 사용자에게 보고하고, 실제 삭제는 사용자 승인 후에만 한다.
- 정적 분석 결과는 항상 오탐 가능성이 있다(아래 "알려진 오탐 패턴" 참고).
  후보 하나하나를 grep으로 재확인하기 전에는 "죽은 코드"라고 단정하지 않는다.

## 1. Dart (lib/) — unreachable_from_main

1. `analysis_options.yaml`의 `linter > rules`에 `unreachable_from_main`이
   있는지 확인한다. 없으면 추가한다:
   ```yaml
   linter:
     rules:
       - unreachable_from_main
   ```
2. 실행:
   ```bash
   flutter analyze 2>&1 | grep unreachable_from_main
   ```
3. 결과에 나온 각 파일/멤버에 대해 **반드시** grep으로 교차검증한다:
   ```bash
   grep -rn "심볼명" lib test --include="*.dart"
   ```
   선언부 외에 다른 참조가 없으면 죽은 코드 후보로 확정, 있으면 오탐이다.

### 알려진 오탐 패턴

- `@pragma('vm:entry-point')`가 있는 최상위 함수가 파일에 있으면, 그 파일
  전체가 "executable library"로 분류되어 같은 파일의 다른 멤버들이 실제로는
  다른 파일에서 쓰이고 있어도 "unreachable"로 잘못 뜬다
  (예: `firebase_messaging_service.dart` — `FirebaseMessagingService`
  클래스는 `bootstrap.dart`/`providers.dart`에서 실사용 중인데도 오탐 발생).
- static 메서드 호출(`ClassName.method()`), 생성자 tear-off, DI로 타입만
  주입되는 패턴에서 오탐이 잦다.
- 오탐으로 확인되면 삭제하지 말고, 파일 상단에 이유를 적은 주석과 함께
  `// ignore_for_file: unreachable_from_main`으로 억제한다.

## 2. functions/ (TypeScript) — knip

```bash
cd functions
npx knip
```

`package.json`의 `main`이 컴파일 결과물(`lib/index.js`)을 가리키고 있어
entry 추론이 부정확할 수 있다. 필요하면 `functions/knip.json`을 임시로:
```json
{
  "entry": ["src/index.ts"],
  "project": ["src/**/*.ts"],
  "ignore": ["lib/**"]
}
```
결과의 "Unused files"/"Unused exports"/"Unused dependencies" 섹션을 그대로
후보로 삼되, 마찬가지로 `grep -rn "심볼명" functions/src`로 교차검증한다.

## 3. 보고 형식

삭제 없이, 다음 형식으로만 보고한다:

- 파일/심볼명, 위치
- 정적 분석 근거(어느 도구, 어떤 메시지)
- grep 교차검증 결과(진짜 미사용 확인됨 / 오탐으로 판명됨)
- 삭제 시 영향 범위(다른 어디서도 참조 안 됨 확인)

사용자가 개별 항목 또는 전체를 승인한 뒤에만 삭제하고, 삭제 후에는
`flutter analyze`(Dart) 또는 `npm run build`(functions)로 재검증한다.

## 도구 설치가 막혔을 때

- DCM은 `realm_dart`의 `ByteBuffer`→`Uint8List` 타입 불일치(Dart 최신 SDK
  비호환, 업스트림 이슈가 "not planned"로 닫힘)로 이 환경에서 설치가 안 된다.
  재시도하지 말고 위 1, 2번 방법으로 대체한다.
- `dead_code_analyzer`(pub.dev)는 realm_dart 의존이 없어 설치는 되지만,
  프로젝트 전체(`-p .`)를 analyzer로 완전히 파싱해서 CPU를 매우 많이 쓰고
  오래 걸린다(이 리포 규모에서 10분+ 관측됨). 급하게 켤 도구는 아니다.
