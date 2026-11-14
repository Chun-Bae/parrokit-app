// 앱에서 쓰는 바텀시트 하나로 모은 것.
//
// 전에는 화면마다 showModalBottomSheet를 직접 불러서 모양이 조금씩 달랐다.
// 어떤 시트는 뒤에 어두운 막이 있고 어떤 시트는 없었고, 아래 탭 바와 겹쳐서
// 마지막 줄이 탭 바에 가렸다(5차, 사용자 의견).
//
// 여기서 한 번에 정한다:
// - 뒤에 어두운 막을 두지 않는다. 대신 테두리와 그림자로 떠 있는 것을 보인다.
// - 아래 탭 바 위에 뜬다. 탭 바가 없는 화면에서는 안전 영역만 띄운다.
// - 손잡이, 모서리, 최대 너비, 키보드 피하기를 같게 한다.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parrokit/core/app/router/app_shell.dart';

/// 지금 떠 있는 공통 바텀시트의 수. 0보다 크면 셸이 아래 탭 바를 숨긴다.
///
/// 아래 탭 바는 Flutter 위젯이 아니라 UiKitView로 띄운 iOS UITabBar다.
/// 그 네이티브 뷰는 자기 프레임 바깥 위쪽으로 그림자를 드리우는데, 그 영역은
/// Flutter가 시트를 올려 그리는 오버레이가 덮지 않아서 시트 위로 희미한
/// 가로 띠로 비쳤다(5차, 사용자가 여러 번 지적). 시트가 떠 있는 동안에는
/// 어차피 탭 바가 가려지므로 숨겨 둔다.
final ValueNotifier<int> openAppSheetCount = ValueNotifier<int>(0);

/// 지금 화면에 아래 탭 바가 있는지. 라우터 밖(테스트 등)에서는 없다고 본다.
bool _hasNavBar(BuildContext context) {
  try {
    return !appShellHidesNavBar(GoRouterState.of(context).uri.toString());
  } catch (_) {
    return false;
  }
}

/// 앱 공통 바텀시트. [builder]가 그린 내용만 넣으면 된다.
///
/// [fullHeight]를 켜면 화면 높이만큼 늘어날 수 있다(긴 목록·입력 폼).
/// [dismissible]을 끄면 바깥을 눌러도 닫히지 않는다.
/// [rootNavigator]를 켜면 화면 안에 내비게이터를 따로 둔 곳에서도 맨 위에 뜬다.
/// 그 화면에서 진행 창 같은 것을 루트에 띄우고 닫는다면 켜야 순서가 맞는다.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool fullHeight = true,
  bool dismissible = true,
  bool? rootNavigator,
}) {
  final hasNavBar = _hasNavBar(context);
  openAppSheetCount.value++;
  return showModalBottomSheet<T>(
    context: context,
    // 탭 바는 셸의 Scaffold가 그리므로 그 위에 뜨려면 루트 내비게이터가 필요하다.
    // 탭 바가 없는 화면(과 라우터 밖)에서는 그 화면의 내비게이터에 그대로 띄운다.
    // 전에 늘 루트로 띄웠더니 화면 안에 내비게이터를 따로 둔 곳에서 시트가
    // 그 화면 밖으로 빠져나갔다.
    useRootNavigator: rootNavigator ?? hasNavBar,
    isScrollControlled: fullHeight,
    isDismissible: dismissible,
    enableDrag: dismissible,
    // 화면을 거의 채우는 시트는 위가 상태 표시줄·노치에 가린다. 예전에는
    // 시트마다 useSafeArea를 켰는데, 공통으로 모으며 빠뜨려 문장 상세 위쪽
    // 칩과 아이콘이 시계에 가렸다(5차).
    useSafeArea: true,
    // 면·모서리·손잡이는 테마(app_bottom_sheet_theme.dart)가 그린다. 한때
    // 여기서 한 겹을 더 그렸는데, 시트 안쪽이 이미 자기 흰 판과 손잡이를
    // 그리는 곳이 있어 두 겹이 되면서 경계가 희미한 선으로 보였다
    // (5차, 사용자 의견).
    builder: builder,
  ).whenComplete(() => openAppSheetCount.value--);
}
