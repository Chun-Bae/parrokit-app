---
name: firebase-deploy-check
description: >-
  Checks Firebase Functions/Firestore changes before the user is told to deploy,
  and verifies the result after. Use whenever you are about to give the user a
  `firebase deploy` command, after editing functions/ or firestore.rules, or when
  a deployed function errors (404, invalid-argument, memory, runtime).
---
# Firebase Deploy Check

배포는 사용자가 직접 실행한다. 그래서 안내 전에 내가 확인하고, 배포 뒤에도 확인한다.
기억이나 요약을 믿지 말고 파일과 로그를 직접 본다.

## 겪었던 실수

- 분기를 "넣었다"고 했는데 주석만 있었다. 앱에서 `invalid-argument`가 났다.
- 이미 종료된 모델(`gemini-2.5-*`)을 골라 404가 났다.
- Node 20 런타임이 종료돼 배포가 막혔다.
- 메모리 기본값 256MiB로 모듈 로딩 중 초과했다.

## 1. 안내 전 점검

`functions/`에서 실행한다. 하나라도 실패하면 안내하지 않는다.

```bash
npm run build && npm run lint
```

- 의도한 코드가 컴파일 결과에 실제로 있는지 `grep`으로 확인한다.
  예: `grep -n "status" functions/lib/sentenceAssist.js`
  소스에서도 주석이 아니라 실행되는 코드인지 읽어서 확인한다.
- 모델 ID가 지금 지원되는지 검색으로 확인한다. 기억으로 정하지 않는다.
- `functions/package.json`의 `engines.node`가 지원 중인 런타임인지 확인한다.
- 함수가 `firebase-admin`, `genkit` 같은 큰 모듈을 불러오면 `memory`를 `512MiB` 이상으로 둔다.
- `firestore.rules`나 인덱스를 바꿨으면 `--only firestore:rules` 등 별도 배포가 필요한지 정리한다.
- 키·토큰·비밀번호가 코드나 로그에 없는지 확인한다.

## 2. 안내

- `--only functions:함수이름`처럼 범위를 좁힌 명령 한 줄만 준다.
- 프로젝트는 `--project parrokit-45126`를 붙인다.
- 직접 실행하지 않는다. 커밋·푸시·배포를 요청 없이 하지 않는다.
- 예:

```bash
npx -y firebase-tools@latest deploy --only functions:함수이름 --project parrokit-45126
```

## 3. 배포 후 확인

- 사용자가 준 배포 출력에 `Deploy complete`와 해당 함수 이름이 있는지 본다.
- 앱에서 한 번 호출해 보게 하고, 실패하면 앱 로그의 한 줄과 함수 로그를 받아서 원인을 읽는다.
  함수 로그: `npx -y firebase-tools@latest functions:log --only 함수이름 --project parrokit-45126`
- 성공 여부를 확인하지 못했으면 "배포됨"이라고 단정하지 말고 확인하지 못했다고 말한다.
