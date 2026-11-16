// 소리는 한 번에 하나만 난다(5차, 사용자 요청).
//
// 플레이어를 나가도 소리가 이어지게 한 뒤로, 그 소리가 나는 동안 쇼츠를 보거나
// 문장을 들으면 둘이 겹쳐 울렸다. 소리를 내려는 쪽이 여기 한 줄만 부르면 듣던
// 것이 멈춘다.
//
// Provider가 아니라 작은 싱글톤인 까닭: 소리를 내는 곳이 BuildContext 없이
// 돌아가는 데(FlutterTts를 바로 쓰는 위젯)도 있어서다.

import 'package:parrokit/core/shared/utils/app_logger.dart';

typedef StopSound = Future<void> Function();

class AudioFocus {
  AudioFocus._();
  static final AudioFocus instance = AudioFocus._();

  /// 지금 소리를 내고 있을 수 있는 곳들. 둘 이상일 수 있다
  /// (소리 전용 플레이어, 새 네이티브 플레이어).
  final List<StopSound> _stoppers = [];

  /// 소리를 들고 있는 쪽이 '나도 있다'고 알려 둔다.
  void registerBackground(StopSound stop) {
    if (!_stoppers.contains(stop)) _stoppers.add(stop);
  }

  void unregisterBackground(StopSound stop) => _stoppers.remove(stop);

  /// 다른 소리를 내기 직전에 부른다. 듣던 것이 있으면 모두 멈춘다.
  ///
  /// [except]는 멈추지 않는다. 소리를 내려는 쪽이 자기 정지 콜백을 등록해 둔
  /// 경우(읽어 주기 위젯) 자기 자신을 멈춰 켜자마자 꺼지는 일을 막는다(5차 320).
  Future<void> claim({StopSound? except}) async {
    for (final stop in List<StopSound>.of(_stoppers)) {
      // tear-off는 부를 때마다 새 객체라 identical로는 못 가린다. ==로 본다.
      if (except != null && stop == except) continue;
      try {
        await stop();
      } catch (error) {
        AppLogger.w('[AudioFocus] 듣던 소리를 멈추지 못했어요: $error');
      }
    }
  }
}
