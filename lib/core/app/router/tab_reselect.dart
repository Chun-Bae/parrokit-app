import 'package:flutter/foundation.dart';

/// 하단 탭을 그 탭의 첫 화면에서 다시 눌렀을 때 알린다.
///
/// 하위 화면에 있을 때는 [AppShell]이 `context.go`로 첫 화면에 돌려보내므로
/// 여기로 오지 않는다. 이미 첫 화면이면 각 화면이 듣고 맨 위로 스크롤한다.
/// 탭 번호는 AppShell과 같다: 0 쇼츠, 1 커뮤니티, 2 홈, 3 보관함, 4 더보기.
class TabReselect extends ChangeNotifier {
  TabReselect._();

  static final TabReselect instance = TabReselect._();

  int? _lastIndex;

  /// 마지막으로 다시 눌린 탭 번호.
  int? get lastIndex => _lastIndex;

  void fire(int index) {
    _lastIndex = index;
    notifyListeners();
  }
}
