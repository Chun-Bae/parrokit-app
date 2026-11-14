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
import 'package:parrokit/core/shared/theme/app_theme.dart';

/// 탭 바가 차지하는 높이(안전 영역 제외). app_bottom_navbar.dart와 같아야 한다.
const double _navBarSpace = AppTheme.bottomNavHeight +
    6 * 2 + // bottomNavPadding
    8; // bottomNavMargin bottom

/// 지금 화면에 아래 탭 바가 있는지. 라우터 밖(테스트 등)에서는 없다고 본다.
bool _hasNavBar(BuildContext context) {
  try {
    return !appShellHidesNavBar(GoRouterState.of(context).uri.toString());
  } catch (_) {
    return false;
  }
}

/// 지금 화면에서 바텀시트가 띄워야 할 아래 여백.
double appSheetBottomGap(BuildContext context) {
  final inset = MediaQuery.paddingOf(context).bottom;
  return _hasNavBar(context) ? _navBarSpace + inset : inset;
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

/// 바텀시트 안쪽 면. 모서리·테두리·그림자·아래 여백을 맡는다.
class AppSheetSurface extends StatelessWidget {
  const AppSheetSurface({
    super.key,
    required this.child,
    required this.gap,
    this.showHandle = true,
  });

  final Widget child;

  /// 아래 탭 바와 안전 영역을 피할 여백.
  final double gap;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      // 키보드가 올라오면 그만큼 위로 밀어 입력칸이 가리지 않게 한다.
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        bottom: keyboard > 0 ? keyboard + 8 : gap,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          // 뒤에 막이 없어도 떠 있는 것으로 보이게 한다.
          border: Border.all(color: colors.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
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
            // 아래 여백은 이 위젯이 이미 뒀다. 시트 안에서 SafeArea를 또
            // 쓰면 여백이 두 번 들어가 카드 아래가 비어 보였다.
            Flexible(
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
