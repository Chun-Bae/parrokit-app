// App Check를 켤지 한곳에서 정한다.
//
// 지금은 false다. 켜기 전에 Firebase 콘솔에서 iOS(App Attest 또는
// DeviceCheck)와 Android(Play Integrity) 앱을 App Check에 등록하고, App
// Check를 켠 앱 버전이 충분히 퍼진 뒤에 true로 바꿔 배포한다. 순서를 바꾸면
// 옛 앱과 등록 안 된 앱의 모든 호출이 거절된다.
// 자세한 순서는 .claude/review-findings.md의 "App Check이 없다" 항목에 있다.
export const ENFORCE_APP_CHECK = false;

// onCall 옵션에 펼쳐 넣는 모양. 줄이 짧아지게 따로 둔다.
export const appCheckOptions = {enforceAppCheck: ENFORCE_APP_CHECK};
