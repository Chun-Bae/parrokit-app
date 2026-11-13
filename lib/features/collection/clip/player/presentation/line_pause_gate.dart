/// "한 줄씩 멈춤"에서 언제 멈출지 정한다.
///
/// 전체 재생 중 자막 한 줄이 끝나면 한 번 멈춰서 따라 말할 틈을 준다
/// (design-research 7, 다른 학습 앱의 자동 멈춤). 같은 줄 끝에서 다시 재생을
/// 눌렀을 때 곧바로 또 멈추지 않도록, 멈춘 줄을 기억해 둔다. 그 줄의 끝보다
/// 앞으로 돌아가면(다시 듣기) 기억을 지워 그 줄 끝에서 다시 멈춘다.
class LinePauseGate {
  int? _pausedAfter;

  /// 줄 [index]의 끝 [end]를 지금 위치 [position]이 넘었고, 그 줄 끝에서 아직
  /// 멈추지 않았으면 true. true를 돌려주면 그 줄은 멈춘 것으로 기억한다.
  bool shouldPause(int index, Duration position, Duration end) {
    if (position < end) {
      if (_pausedAfter == index) _pausedAfter = null;
      return false;
    }
    if (_pausedAfter == index) return false;
    _pausedAfter = index;
    return true;
  }

  void reset() => _pausedAfter = null;
}
