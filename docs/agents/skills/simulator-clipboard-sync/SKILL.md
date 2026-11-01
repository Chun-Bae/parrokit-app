---
name: simulator-clipboard-sync
description: >-
  Syncs the Mac clipboard into the iOS Simulator so text copied on the Mac can be
  pasted into Flutter text fields. Use when the user asks to paste Mac-copied
  text into the simulator, says paste does not work in the simulator, or asks to
  start/stop the clipboard sync.
---
# Simulator Clipboard Sync

Simulator의 "Automatically Sync Pasteboard"는 Simulator 앱이 앞으로 나올 때만 동작해서,
Claude 앱의 시뮬레이터 패널을 쓰거나 포커스가 안 바뀌면 맥에서 복사한 글이 안 넘어간다.
`xcrun simctl pbcopy`로 맥 클립보드를 시뮬레이터에 직접 밀어 넣어서 우회한다.

## 한 번만 보내기

지금 맥 클립보드를 시뮬레이터로 한 번 보낸다. 시뮬레이터가 부팅돼 있어야 한다.

```bash
pbpaste | xcrun simctl pbcopy booted
```

## 계속 자동으로 보내기 (감시)

맥에서 복사할 때마다 0.5초 안에 시뮬레이터로 보낸다. 터미널 탭 하나에 켜 두고,
끄려면 그 탭에서 `Ctrl+C`를 누른다.

```bash
last=""; while true; do cur=$(pbpaste); if [ "$cur" != "$last" ]; then printf '%s' "$cur" | xcrun simctl pbcopy booted; last="$cur"; fi; sleep 0.5; done
```

## 실행 방법

- 사용자가 "감시 켜 줘", "붙여넣기 되게 해 줘"처럼 요청하면 **감시 스크립트**를 터미널 탭에서 실행한다.
  이미 같은 감시가 도는 탭이 있으면 새로 만들지 않는다(`list_terminal_tabs`로 확인).
- 한 번만 보내 달라고 하면 **한 번만 보내기**를 실행한다.
- 끄라고 하면 감시가 도는 탭을 중지한다(`stop_terminal_tab`).
- 먼저 `xcrun simctl list devices booted`로 부팅된 시뮬레이터가 있는지 확인한다.
  없으면 "시뮬레이터가 꺼져 있다"고 알리고 실행하지 않는다.

## 알아둘 점

- 텍스트만 전달한다. 이미지나 파일은 안 된다.
- 시뮬레이터를 끄거나 다른 기기로 바꾸면 에러가 반복될 수 있다. 감시를 끄고 다시 실행한다.
- iOS 16 이상에서는 외부 내용을 앱이 처음 읽을 때 "붙여넣기 허용" 팝업이 뜬다.
  앱 권한이 아니라 시스템 동작이므로 코드나 `Info.plist`를 고치지 않고 허용을 누르면 된다.
  매번 뜨는 게 싫으면 시뮬레이터 설정의 해당 앱에서 "다른 앱에서 붙여넣기"를 허용으로 바꾼다.
- 입력칸을 길게 눌러 "붙여넣기"를 고르거나, 하드웨어 키보드 연결 상태에서 Cmd+V를 누른다.
