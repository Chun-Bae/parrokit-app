// 문장 상세에서 끝까지 들으면 '듣기 N회'가 올라간다(5차 338, 사용자 신고).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/core/shared/widgets/speak_controls.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 네이티브가 보내오는 알림을 흉내 낸다.
Future<void> _ttsEvent(String name) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'flutter_tts',
      const StandardMethodCodec().encodeMethodCall(MethodCall(name)),
      (_) {},
    );

Future<void> ttsStarted() => _ttsEvent('speak.onStart');

/// 네이티브가 "다 읽었다"고 알려 오는 것을 흉내 낸다.
Future<void> ttsCompleted() =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'flutter_tts',
      const StandardMethodCodec()
          .encodeMethodCall(const MethodCall('speak.onComplete')),
      (_) {},
    );

void main() {
  setUp(() {
    // 테스트에는 진짜 음성이 없다. '그 언어 음성이 있다'고만 답해 둔다.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'),
            (call) async => call.method == 'isLanguageAvailable' ? true : 1);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
  });

  testWidgets('다 읽으면 onListened를 부른다', (tester) async {
    var listened = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SpeakControls(
          text: 'Where were we?',
          language: '영어',
          onListened: () => listened++,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await ttsCompleted();
    await tester.pumpAndSettle();
    expect(listened, 1);

    await ttsCompleted();
    await tester.pumpAndSettle();
    expect(listened, 2, reason: '들을 때마다 센다');
  });

  testWidgets('끝까지 안 듣고 멈추면 세지 않는다', (tester) async {
    // iOS는 stop() 뒤에도 '다 읽었다'를 보내 온다(사용자 신고: 중간에 멈춰도
    // 숙련도가 올랐다).
    var listened = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SpeakControls(
          text: 'Where were we?',
          language: '영어',
          onListened: () => listened++,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // 듣기 → (읽기 시작) → 멈추기.
    await tester.tap(find.byKey(const ValueKey('speak-text')));
    await tester.pumpAndSettle();
    await ttsStarted();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('speak-text')));
    await tester.pumpAndSettle();

    await ttsCompleted();
    await tester.pumpAndSettle();
    expect(listened, 0);

    // 멈춘 뒤 다시 들어서 끝까지 들으면 그때는 센다.
    await tester.tap(find.byKey(const ValueKey('speak-text')));
    await tester.pumpAndSettle();
    await ttsStarted();
    await tester.pumpAndSettle();
    await ttsCompleted();
    await tester.pumpAndSettle();
    expect(listened, 1);
  });

  test('듣기 횟수는 들은 만큼 쌓인다', () async {
    SharedPreferences.setMockInitialValues({});
    await SentenceActivityStore.incrementListen('guest', 's1');
    await SentenceActivityStore.incrementListen('guest', 's1');
    final activity = await SentenceActivityStore.load('guest', 's1');
    expect(activity.listenCount, 2);
  });

  test('문장 상세가 듣기 횟수를 적는다', () {
    final code = File(
            'lib/features/collection/shell/presentation/widgets/sentence_collection_preview.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'\s+'), ' ');
    expect(code, contains('onListened: countListen'));
    expect(code, contains('SentenceActivityStore.incrementListen('));
  });
}
