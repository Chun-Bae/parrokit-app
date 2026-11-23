// 듣는 중일 때 아래에 붙는 줄(5차, 사용자 요청).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/state/provider/background_playback_provider.dart';
import 'package:parrokit/features/collection/clip/player/presentation/widgets/listening_bar.dart';

Future<void> _open(
  WidgetTester tester, {
  bool playing = true,
  VoidCallback? onOpen,
  VoidCallback? onToggle,
  VoidCallback? onClose,
}) async {
  final cs = ColorScheme.fromSeed(seedColor: Colors.blue);
  await tester.pumpWidget(MaterialApp(
    theme:
        ThemeData(colorScheme: cs, textTheme: appTextTheme(cs, isDark: false)),
    home: Scaffold(
      body: ListeningBar(
        playback:
            BackgroundPlayback(clipId: 7, title: '카페에서', playing: playing),
        onOpen: onOpen ?? () {},
        onTogglePlay: onToggle ?? () {},
        onClose: onClose ?? () {},
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('무엇을 듣는지 적는다', (tester) async {
    await _open(tester);

    expect(find.text(listeningBarHint), findsOneWidget);
    expect(find.text('카페에서'), findsOneWidget);
  });

  // 멈췄는데 '듣는 중'이라 적으면 옆의 ▶ 단추와 말이 갈린다(5차 566).
  testWidgets('멈추면 머리말도 멈췄다고 적는다', (tester) async {
    await _open(tester, playing: false);

    expect(find.text(listeningBarPausedHint), findsOneWidget);
    expect(find.text(listeningBarHint), findsNothing);
  });

  testWidgets('듣는 중이면 멈춤, 멈췄으면 이어 듣기', (tester) async {
    await _open(tester, playing: true);
    expect(
        tester
            .widget<IconButton>(
                find.byKey(const ValueKey('listening-bar-toggle')))
            .tooltip,
        '멈춤');

    await _open(tester, playing: false);
    expect(
        tester
            .widget<IconButton>(
                find.byKey(const ValueKey('listening-bar-toggle')))
            .tooltip,
        '이어 듣기');
  });

  testWidgets('누르면 돌아가고, 버튼은 각각 제 일을 한다', (tester) async {
    var opened = 0, toggled = 0, closed = 0;
    await _open(tester,
        onOpen: () => opened++,
        onToggle: () => toggled++,
        onClose: () => closed++);

    await tester.tap(find.byKey(const ValueKey('listening-bar-toggle')));
    await tester.tap(find.byKey(const ValueKey('listening-bar-close')));
    await tester.tap(find.byKey(const ValueKey('listening-bar-title')));
    await tester.pump();

    expect(toggled, 1);
    expect(closed, 1);
    expect(opened, 1, reason: '줄을 누르면 그 클립으로 돌아간다');
  });

  test('플레이어는 나갈 때 넘기고 돌아오면 돌려받는다', () {
    final vm = File(
            'lib/features/collection/clip/player/presentation/clip_player_view_model.dart')
        .readAsStringSync();

    expect(vm, contains('_handOffToBackground()'));
    expect(vm, contains('handOff.takeOver('));
    expect(vm, contains('handOff.handBack()'));
    // 다른 클립을 열면 듣던 것은 멈춘다.
    expect(vm, contains('await handOff.stop();'));
  });
}
