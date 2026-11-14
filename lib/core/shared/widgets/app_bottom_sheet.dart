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
import 'package:parrokit/core/shared/theme/app_radius.dart';

/// 지금 화면에 아래 탭 바가 있는지. 라우터 밖(테스트 등)에서는 없다고 본다.
bool _hasNavBar(BuildContext context) {
  try {
    return !appShellHidesNavBar(GoRouterState.of(context).uri.toString());
  } catch (_) {
    return false;
  }
}

/// 시트 안쪽 아래 여백. 시트가 탭 바를 덮으므로 안전 영역만 띄운다.
///
/// 한때 탭 바 높이만큼 더 띄워 탭 바 위에 떠 있게 했는데, 아래가 비어 보여
/// 되돌렸다(5차, 사용자 의견).
double appSheetBottomGap(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom;

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
  bool showHandle = true,
  bool? rootNavigator,
}) {
  final hasNavBar = _hasNavBar(context);
  final gap = appSheetBottomGap(context);
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
    // 떠 있는 카드 모양으로 그리려고 시트 자체는 투명하게 둔다.
    backgroundColor: Colors.transparent,
    elevation: 0,
    showDragHandle: false,
    constraints: const BoxConstraints(maxWidth: 600),
    builder: (sheetContext) => AppSheetSurface(
      gap: gap,
      showHandle: showHandle,
      child: builder(sheetContext),
    ),
  );
}

/// 바텀시트 안쪽 면. 아래 여백과 손잡이만 맡는다.
///
/// 한때 양옆 여백·테두리·그림자를 준 '떠 있는 카드'로 그렸는데, 기본
/// 바텀시트와 달라 어색했다(5차, 사용자 의견). 화면 아래에 붙고 위 모서리만
/// 둥근 보통 모양으로 되돌렸다.
class AppSheetSurface extends StatelessWidget {
  const AppSheetSurface({
    super.key,
    required this.child,
    required this.gap,
    this.showHandle = true,
  });

  final Widget child;

  /// 더 이상 쓰지 않는다. 안전 영역은 시트 안쪽 내용이 맡는다.
  final double gap;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      child: Padding(
        // 키보드가 올라오면 그만큼 위로 밀어 입력칸이 가리지 않게 한다.
        // 키보드가 없을 때는 아무것도 더하지 않는다. 안전 영역은 시트 안쪽
        // 내용이 저마다 SafeArea로 처리한다. 여기서 또 띄웠더니 마지막 줄
        // 아래에 흰 칸이 하나 더 생겨 보였다(5차, 사용자 의견).
        padding: EdgeInsets.only(bottom: keyboard),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHandle)
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 2),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
