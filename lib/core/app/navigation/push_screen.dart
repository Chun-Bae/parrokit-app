// 화면을 미는 한 가지 길(5차, 사용자 요청).
//
// 아래 탭 바는 AppShell이 그린다. 그래서 탭 안쪽 Navigator로 화면을 밀면
// **민 화면 아래에 탭 바가 그대로 남는다.** 이용 약관을 열어도 탭 바가
// 보이고, 거기서 다른 탭을 누를 수도 있었다.
//
// 지금까지는 눈에 띌 때마다 그 자리에서만 `rootNavigator: true`를 붙였다.
// wallet_section에는 "돈을 다루는 화면에서 다른 탭이 눌렸다"는 주석까지
// 남아 있다. 자리가 늘수록 빠뜨리는 곳이 생기고, 사용자가 볼 때마다
// 하나씩 고치게 된다.
//
// 미는 길을 여기 하나로 모으고, 이 길이 늘 root로 민다. root로 밀면 화면이
// 셸 **위**로 올라가므로 탭 바가 덮인다 - 셸이 경로 목록으로 가릴지 말지
// 따로 따질 일이 없다.
//
// go_router로 가는 화면은 이 길을 타지 않는다. 그쪽은 셸 **안쪽** 가지라
// 탭 바가 남는 것이 맞고, 덮어야 하는 화면이면 라우터에서 셸 바깥에
// 선언한다(지금은 appShellHidesNavBar가 경로로 가린다).

import 'package:flutter/material.dart';

/// 화면을 띄운다. 아래 탭 바 위를 덮는다.
///
/// 화면 안에서 `Navigator.pop`을 부르면 그대로 닫힌다.
Future<T?> pushAppScreen<T>(
  BuildContext context,
  Widget screen, {
  bool fullscreenDialog = false,
}) =>
    Navigator.of(context, rootNavigator: true).push<T>(
      MaterialPageRoute<T>(
        builder: (_) => screen,
        fullscreenDialog: fullscreenDialog,
      ),
    );
