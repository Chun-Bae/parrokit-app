# 보안 규칙 테스트

`firestore.rules`와 `storage.rules`를 Firebase 에뮬레이터 위에서 검증한다.

```bash
cd test_rules
npm install   # 처음 한 번
npm test
```

`emulators:exec`가 Firestore와 Storage 에뮬레이터를 띄우고 그 안에서
`node --test`를 돌린 뒤 내려 준다. Java가 필요하다.

테스트 파일은 두 갈래를 모두 본다.

- **앱이 실제로 하는 쓰기는 통과하는지.** 규칙을 좁히다 앱을 막으면
  배포한 뒤에야 안다. 추천 토글, 댓글 작성, 투표, 닉네임 선점처럼 앱이
  실제로 보내는 모양을 그대로 보낸다.
- **남의 것을 건드리는 쓰기는 막히는지.**

규칙을 고치면 두 갈래를 같이 돌린다. 한쪽만 보면 "아무도 아무것도 못 한다"는
규칙도 통과한다.

## 왜 파일을 직렬로 돌리는지

`node --test`는 파일을 동시에 돌린다. 두 테스트 파일이 같은 에뮬레이터
프로젝트를 쓰므로, 한쪽의 `clearFirestore`/`clearStorage`가 다른 쪽이 넣어
둔 문서를 지운다. `--test-concurrency=1`로 한 파일씩 돈다.
