---
name: admob-ssv
description: >-
  AdMob 보상형 광고의 서버 측 확인(SSV) 콜백이 깨질 때 쓴다. 콜백이 `invalid
  signature`(bad-signature)로 거절되거나, 콘솔 테스트는 통과하는데 실제 기기만
  깨지거나, 콜백이 아예 안 오거나, 광고를 봤는데 패롯이 안 들어올 때. 콜백 URL을
  어디에 넣는지, 로그를 어떻게 읽는지, AdMob 콘솔 테스트로 어떻게 재현하는지를
  담았다.
---

# AdMob 서버 측 확인(SSV)

서버 코드는 `functions/src/adReward.ts`, 앱 쪽은
`lib/core/infrastructure/services/ad_service.dart`다. 돈(패롯)이 걸린 자리라
서명이 조금이라도 어긋나면 받아들이지 않는다.

## 프로젝트 값 (비밀 아님)

- 함수 이름 `admobRewardCallback`, 리전 `us-central1`, 2세대
- 콜백 URL 두 개가 **같은 함수**로 간다:
  - `https://admobrewardcallback-my7jjzrohq-uc.a.run.app` (Cloud Run 직접 주소)
  - `https://us-central1-parrokit-45126.cloudfunctions.net/admobRewardCallback`
- **직접 주소를 쓴다.** 앞단을 한 겹 덜 지나면 쿼리 문자열을 다시 인코딩할
  놈이 하나 줄어든다. 서명이 깨지는 흔한 원인이 그거다
- 광고 1회 보상은 `AD_REWARD_PARROTS = 3`. 앱의 `AdService.rewardCoins`와 같다
- AdMob 콘솔의 리워드 설정은 `1 Reward`다. 서버가 주는 값과 다르지만 상관없다 -
  서버는 `AD_REWARD_PARROTS`를 쓴다

## 켜는 순서 (거꾸로 하면 이중 지급이나 지급 누락)

1. 함수를 배포하고 AdMob 콘솔의 **보상형** 광고 단위에 콜백 URL을 넣는다.
   Android와 iOS 단위가 따로 있으니 **둘 다** 넣는다
2. 앱은 `custom_data`로 `verify-only`를 보낸다. 서버는 확인만 하고 기록을
   남기며, 지급은 앱이 한다. 로그로 콜백이 오는지 본다
3. 앱의 `AdService.serverCreditsReward`를 `true`로 바꿔 출시한다. 그 앱은
   `credit-v1`을 보내고 스스로 지급하지 않는다. 서버가 지급한다

`credited: false`는 2단계에서 **정상이다.** `custom_data`가 `verify-only`면
서버는 확인만 한다. 이걸 실패로 읽지 않는다.

## 겪었던 실수 (5차 568)

### 1. 메모리 256MiB로 콜백이 서명 확인에 닿기도 전에 죽었다

```
'Memory limit of 256 MiB exceeded with 259 MiB used.'
The request failed because either the HTTP response was malformed or
connection to the instance had an error.
While handling this request, the container instance was found to be using
too much memory and was terminated.
```

`[AdReward]` 줄이 **아예 없이** 저 오류만 나오면 이거다. 함수가 무거운 게
아니다. `functions/src/index.ts`가 함수 전부를 `export *`로 모으므로, 광고
콜백 하나도 `@genkit-ai`(19M)·`@aws-sdk`(11M)·음성 합성 SDK를 같이 지고
일어난다. 모듈 로딩만으로 258~262MiB를 썼다.

고침: `onRequest(OPTIONS, ...)`에 `memory: "512MiB"`.

콘솔 테스트는 매개변수가 짧아 **살아남는다.** 그래서 "테스트는 되는데 기기만
안 된다"로 보인다 - 아래 2번과 증상이 겹치니 로그를 끝까지 읽는다.

### 2. AdMob은 user_id를 **인코딩하기 전 글자로 서명**한다

이게 진짜 범인이었다.

네이버 로그인 uid는 `functions/src/naverAuth.ts`에서 `naver:${naverUser.id}`로
만든다. **콜론이 들어간다.** AdMob은 그 글자(`naver:XXX`)로 서명해 놓고 보낼
때는 `naver%3AXXX`로 인코딩해서 준다. 받은 글자로 검증하면 영원히 안 맞는다.

구글·애플 로그인 uid는 영숫자 28자뿐이라 안 걸린다. **네이버 계정에서만**
깨진다 - 그래서 계정 따라 되고 안 되고가 갈린다.

고침: `messageVariants`가 서명 대상이 될 수 있는 꼴을 여럿 본다.

```
raw / upper-percent / lower-percent / plus-as-%20 / %20-as-plus
/ %3A-as-colon / decoded
```

**꼴을 늘려도 느슨해지지 않는다.** 어떤 꼴이든 Google 공개키로 올바른 서명이
있어야 지나간다. 틀린 서명은 전부 거부한다(테스트로 막아 뒀다).

맞은 꼴은 로그의 `variant` 칸에 이름으로 찍힌다.

## 진단 순서

로그부터 본다. 추측하지 않는다.

```bash
npx -y firebase-tools@latest functions:log --only admobRewardCallback --project parrokit-45126
```

`Failed to retrieve log entries from Google Cloud`는 흔한 일시 오류다. 한 번
더 돌린다.

실패 줄은 이렇게 생겼다. 값은 담지 않고 **걸린 자리**만 적는다:

```json
{"reason":"bad-signature","names":[...],"keyId":"3335741209",
 "knownKeyIds":["3335741209"],"messageLength":240,"messageEncoded":true,
 "signatureBytes":71,"variant":"","sameUrl":true,
 "message":"ad_network=...&user_id=REDACTED"}
```

| 칸 | 읽는 법 |
|---|---|
| `reason` | `unknown-key-id`면 공개키가 돌았다. `no-signature-param`이면 URL에 다른 게 꽂혔다 |
| `keyId` vs `knownKeyIds` | 다르면 공개키 문제, 같으면 공개키는 멀쩡하다 |
| `signatureBytes` | ECDSA DER은 70~72다. 다르면 서명 자체가 깨졌다 |
| `sameUrl` | `false`면 앞단이 URL을 건드렸다 |
| `messageEncoded` | `true`인데 `message`에 `%`가 안 보이면 **가린 `user_id` 안에 있다** |
| `variant` | 빈 글자면 어느 꼴도 안 맞았다 |
| `message` | 서명 원문. `user_id` 값만 가렸다 |

`messageLength`에서 `message`의 길이를 빼면 가려진 `user_id`의 실제 길이가
나온다. Firebase uid는 보통 28자다. 51자쯤 나오면 커스텀 토큰 uid(네이버)다.

## AdMob 콘솔 테스트로 재현하기

광고를 보지 않고도 같은 코드 경로를 탄다. **이게 제일 빠르다.**

AdMob → 앱 → 광고 단위 → 보상형 단위(`코인 지급`) → 고급 설정 →
서버 측 확인 → `URL 수정 및 확인`.

대화상자에 칸이 셋이다:

- 콜백 URL 입력 - 건드리지 않는다
- **사용자 ID 입력(테스트 전용)** - 여기에 재현하려는 uid를 넣는다.
  콜론 함정을 보려면 `naver:testid123`
- **맞춤 데이터 입력(테스트 전용)** - `verify-only`

그리고 `URL 확인`을 누른다. **`확인된 URL 사용`이나 `저장`은 누르지 않는다** -
그건 설정을 바꾼다. `URL 확인`은 테스트 콜백만 보낸다.

`완료 콜백 URL이 확인되었습니다`가 뜨면 서버가 200을 줬다는 뜻이고, 서버는
서명이 맞을 때만 200을 준다.

끝나면 `Escape`로 닫는다. 저장하지 않았으므로 콘솔은 그대로다.

### 콘솔 테스트의 한계

테스트 콜백은 **가짜 고정값**을 쓴다. `transaction_id=123456789`이면 테스트고,
32자리 16진수면 진짜 기기다. 보상 항목도 실제 단위 설정이 아니라 더미다.
그래서 "콘솔 테스트는 통과하는데 기기는 깨진다"가 흔하다 - 차이는 거의 늘
`user_id` 값에 있다.

## 지킬 것

- 서명과 `user_id` 값을 로그에 남기지 않는다. 원문을 적어야 하면
  `redactMessage()`로 `user_id`만 가린다
- 꼴(variant)을 추가할 때도 **서명 검증은 그대로 둔다.** 길이·이름만 보고
  통과시키는 길을 만들지 않는다
- `pubspec.yaml`의 버전과 빌드 번호는 사용자가 요청할 때만 바꾼다
- 콜백은 `transaction_id`를 장부 키(`ad_<transactionId>`)로 써서 같은 콜백이
  다시 와도 한 번만 지급한다. AdMob은 200을 못 받으면 재시도한다 - 그 중복을
  막는 자리이므로 지우지 않는다
