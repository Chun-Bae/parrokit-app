import 'package:parrokit/features/collection/clip/player/domain/player_state.dart';

/// '한 줄씩 멈춤'을 지금 쓸 수 없는 까닭. 쓸 수 있으면 null.
///
/// 예전에는 흐리게 두고 누를 수도 없게 해서, 왜 안 되는지 알 길이 없었다(5차).
/// 다른 화면처럼 눌렀을 때 까닭을 말해 준다. 소리만 듣는 중(백그라운드)에는
/// 이 줄의 단추가 다 꺼지므로 여기서 따지지 않는다.
String? pauseEachLineDisabledReason(PlayScope scope) {
  if (scope != PlayScope.full) {
    return "'전체'로 볼 때 쓸 수 있어요. 구간은 줄 끝에서 멈추거나 반복해요.";
  }
  return null;
}
