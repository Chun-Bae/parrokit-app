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

  StopSound? _stopBackground;

  /// 이어 듣기 쪽이 '내가 소리를 들고 있다'고 알려 둔다.
  void registerBackground(StopSound stop) => _stopBackground = stop;

  void unregisterBackground(StopSound stop) {
    if (identical(_stopBackground, stop)) _stopBackground = null;
  }

  /// 다른 소리를 내기 직전에 부른다. 듣던 것이 있으면 멈춘다.
  Future<void> claim() async {
    final stop = _stopBackground;
    if (stop == null) return;
    try {
      await stop();
    } catch (error) {
      AppLogger.w('[AudioFocus] 듣던 소리를 멈추지 못했어요: $error');
    }
  }
}
