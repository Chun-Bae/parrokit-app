// 문장 상세에서 끝까지 들으면 '듣기 N회'가 올라간다(5차 338, 사용자 신고).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/core/shared/widgets/speak_controls.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
