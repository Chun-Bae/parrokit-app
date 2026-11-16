// 도우미(챗봇) 시트의 알림도 시트 안에 보여야 한다(5차 371).
//
// 도우미는 바텀시트라 아래에 뜨는 토스트는 가려진다(368에서 확인).
// '추천 글을 복사했어요'와 '갈 길이 없다'는 말이 그래서 보이지 않았다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/content-studio/chat-bot/domain/entities/ai_chat_message.dart';
import 'package:parrokit/features/content-studio/chat-bot/presentation/widgets/chat_bubble.dart';

void main() {
  testWidgets('복사하면 알릴 말을 밖으로 넘긴다', (tester) async {
    final said = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChatBubble(
          message: AiChatMessage(
            text: '```\nhello world\n```',
            isUser: false,
          ),
          onNotice: said.add,
        ),
      ),
    ));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.copy_rounded));
    await tester.pump();
    expect(said, ['추천 글을 복사했어요.']);
  });

  test('갈 길이 없을 때 쓰는 말은 할 수 없다고 말한다', () {
    // 전에는 '영상 만들기 화면으로 이동합니다'라고 해 놓고 아무 일도 없었다.
    expect(chatbotNoRouteNotice, contains('갈 수 없어요'));
    expect(chatbotNoRouteNotice.contains('이동합니다'), isFalse);
  });

  test('도우미 시트와 말풍선은 토스트를 쓰지 않는다', () {
    for (final path in [
      'lib/features/content-studio/chat-bot/presentation/widgets/chat_bubble.dart',
      'lib/features/content-studio/chat-bot/presentation/widgets/chat_bot_sheet.dart',
    ]) {
      final code = File(path).readAsStringSync();
      expect(code.contains('showToast('), isFalse, reason: path);
      expect(code.contains('showSnackBar('), isFalse, reason: path);
    }
    final sheet = File(
            'lib/features/content-studio/chat-bot/presentation/widgets/chat_bot_sheet.dart')
        .readAsStringSync();
    expect(sheet, contains("ValueKey('chatbot-notice')"));
  });
}
