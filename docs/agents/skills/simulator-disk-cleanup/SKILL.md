---
name: simulator-disk-cleanup
description: >-
  Keeps iOS Simulator leftovers from filling the Mac disk. Use before or after
  building and installing to the simulator, when a build fails with "No space
  left on device" (ENOSPC), when free disk is low, or when the user asks why the
  simulator folder is tens of gigabytes.
---

# Simulator Disk Cleanup

시뮬레이터에 앱을 다시 설치할 때마다 이전 컨테이너가 정리되지 않고 쌓인다.
2026-11-14에 한 기기에서만 67GB가 쌓여 맥 디스크가 꽉 찼고(ENOSPC) 명령이
하나도 돌지 않았다. 빌드·설치를 반복하는 루프에서는 매번 확인한다.

## 어디에 쌓이나

| 위치 | 무엇 | 지워도 되나 |
|---|---|---|
| `~/Library/Developer/CoreSimulator/Devices/<UDID>/data/Library/Caches/com.apple.containermanagerd/Dead` | 지워진 앱들의 컨테이너 찌꺼기(`temp.XXXXXX` 폴더) | 지워도 된다. 되돌릴 수 없지만 쓰는 곳이 없다 |
| `<프로젝트>/build/ios` | 시뮬레이터 빌드 산출물 | 지워도 된다. 다시 빌드하면 생긴다(약 1.9GB, 이어 빌드는 20초대) |
| `<프로젝트>/build/test_cache` | 테스트 캐시 | 지워도 된다 |
| `~/Library/Developer/Xcode/DerivedData` | Xcode 캐시 | 지워도 된다. 다음 Xcode 빌드만 느려진다 |

**건드리지 않는다**: `data/Containers`(지금 설치된 앱과 그 데이터), 기기 자체,
`build/app`(사용자가 만든 출시용 AAB), 세션 기록 `.jsonl`.

## 빌드 전 확인 (루프에서 매번)

```bash
df -h / | tail -1 | awk '{print $4}'
du -sh ~/Library/Developer/CoreSimulator/Devices/*/data/Library/Caches/com.apple.containermanagerd/Dead 2>/dev/null | sort -h | tail -3
```

남은 공간이 5GB 아래이거나 `Dead`가 2GB를 넘으면 아래로 정리한다.

## 정리

### 끄기 전에 반드시 묻는다

시뮬레이터를 끄면 사용자가 보고 있던 화면이 사라진다. 지워지는 것은 아니지만
쓰던 흐름이 끊긴다. 2026-11-14에 묻지 않고 꺼서 사용자가 "다 지워버린 것
같다"고 놀랐다. 그래서:

- 부팅된 기기를 끄기 전에 **사용자에게 묻고 답을 받는다**. 자동 루프에서
  답을 받을 수 없으면 끄지 않고, 공간이 급하면 끄지 않아도 되는 것부터
  지운다(`build/ios`, `build/test_cache`, DerivedData).
- 끈다면 무엇이 사라지고 무엇이 남는지 한 줄로 먼저 말한다:
  "화면은 닫히지만 앱 데이터(문장·단어·패롯)와 기기는 그대로입니다."
- 끈 뒤에는 바로 다시 켜고 앱을 설치·실행해 원래 상태로 되돌린다.

### 명령

부팅된 기기의 `Dead`는 시뮬레이터를 끄고 지운다. 끄지 않고 지우면 쓰는 중인
파일과 엉킬 수 있다.

```bash
xcrun simctl shutdown booted; rm -rf ~/Library/Developer/CoreSimulator/Devices/*/data/Library/Caches/com.apple.containermanagerd/Dead; xcrun simctl boot <UDID>
```

`rm` 안전 검사가 맨 `$변수`를 막으므로 변수로 쓸 때는 `"${d:?}"`처럼 쓴다.
지운 뒤 `xcrun simctl boot`로 다시 켜고, 앱을 다시 설치·실행한다.

프로젝트 빌드 산출물만 비울 때(시뮬레이터를 끄지 않아도 된다):

```bash
rm -rf build/ios build/test_cache
```

## 쌓이지 않게 하는 요령

- 한 기기만 쓴다. 여러 기기를 번갈아 쓰면 기기마다 따로 쌓인다.
- 같은 UDID에 계속 설치한다. `xcrun simctl install`은 이전 컨테이너를 `Dead`로
  옮기므로, 설치 횟수만큼 쌓인다. 화면 확인이 끝났으면 바로 정리한다.
- 쓰지 않는 기기는 `xcrun simctl delete unavailable`로 지운다(사용자 승인 뒤).

## 지킬 것

- **부팅된 시뮬레이터는 사용자 허락 없이 끄지 않는다.** 사용자가 보고 있을 수 있다.
- 지우기 전에 무엇을 지우는지와 되돌릴 수 없다는 점을 사용자에게 말한다.
- '끈다'와 '지운다'를 구분해서 말한다. 끄는 것은 화면만 닫히고 데이터는 남는다.
- `data/Containers`와 사용자가 만든 파일은 지우지 않는다.
- 사용자 기기 데이터를 지우는 명령(`simctl erase`)은 쓰지 않는다.
