# 네이티브 플레이어 — 계획 (2026-11-16)

사용자가 정한 것: **공플처럼 플레이어 하나로.** 화면을 나가거나 앱을 내려도
같은 플레이어가 그대로 돌아간다. 넘기는 과정이 없으니 끊기지 않는다.

## 왜

지금은 플레이어가 둘이다.
- 화면: `video_player`(AVPlayer)
- 백그라운드: `just_audio` + `audio_service`(또 다른 AVPlayer)

앱을 내리면 앞을 멈추고, 뒤에 파일을 읽히고, 자리를 맞추고, 튼다. 그 사이가
0.3초다. 실험으로 확인한 것: 넘기기를 끄면(`--dart-define=PK_NO_HANDOFF=true`)
홈을 누르는 순간 `playback state: Playing → Paused (ClientInitiated)`로 소리가
그냥 멈춘다. `video_player` 하나로는 백그라운드에서 울리지 않는다.

iOS가 백그라운드에서 AVPlayer 소리를 이어 주려면 **비디오 트랙을 꺼야** 한다.
그 손잡이를 `video_player` 플러그인이 내주지 않는다. 그래서 직접 만든다.

## 무엇을 만드나

### iOS (Swift)
- `AVPlayer` + `AVPlayerLayer`를 담은 `UIView`를 **PlatformView**로 내놓는다
- 앱이 활성이면 layer에 player가 붙어 영상이 보인다
- 앱을 내리거나 화면을 나가면 **비디오 트랙만 끈다**(`playerItem.tracks`의
  video track `isEnabled = false`). 같은 player가 소리만 계속 낸다
- `AVAudioSession`을 `.playback`으로 두고 활성화
- `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter` — 잠금화면·제어센터 조작
- 나중에 `AVPictureInPictureController(playerLayer:)` — **PiP가 이때 가능해진다**

### Android (media3/ExoPlayer)
- `ExoPlayer` + `SurfaceView`를 PlatformView로
- `MediaSessionService`(포그라운드 서비스)로 백그라운드 재생과 알림 조작
- PiP는 액티비티 단위라 따로

### Flutter 쪽
- MethodChannel: load(path, speed, clipBegin, clipEnd, loop) / play / pause /
  seek / setSpeed / setClipRange / dispose
- EventChannel: position, duration, playing, buffering, completed
- 지금 `ClipPlayerViewModel`이 `VideoPlayerController`에 하던 말을 그대로 옮긴다

## 단계 (각 단계만으로 analyze·test가 통과하고 앱이 돌아야 한다)

1. **iOS 플러그인 뼈대** — 로컬 파일 재생, 영상 보이기, play/pause/seek/speed.
   시험용 화면 하나로 눈으로 확인
2. **백그라운드 유지** — 비디오 트랙 끄기 + 오디오 세션 + 잠금화면 조작.
   홈을 눌러도 끊김 없이 이어지는 것을 로그와 귀로 확인
3. **구간 반복** — clipBegin/clipEnd, loop. 지금 `ClippingAudioSource`가 하던 일
4. **클립 플레이어 교체** — 스위치로 새 플레이어를 켜고 끌 수 있게 두고 바꾼다.
   되면 `audio_service` 넘기기(`BackgroundPlaybackProvider.takeOver`)를 없앤다
5. **안드로이드**
6. 쇼츠·스튜디오 미리보기도 바꿀지 정한다
7. 다 되면 `video_player`·`audio_service`·`just_audio` 정리. PiP는 그 뒤에 따로

## 위험하다고 보는 것

- 플레이어 버그를 우리가 떠안는다(자막 동기, 속도 바꿈, 반복 경계, 파일 깨짐)
- 시뮬레이터로 못 보는 것이 있다(잠금화면, 진짜 백그라운드 동작) — 기기에서 봐야 한다
- 지금 기능을 하나씩 옮겨야 한다: 소리만 듣기, '듣는 중' 줄, 다른 소리 나면 멈추기,
  한 줄씩 멈춤, 구간/전체, 속도, 자막
- 되돌릴 길을 둔다: 4단계까지는 스위치로 예전 플레이어로 돌아갈 수 있게
