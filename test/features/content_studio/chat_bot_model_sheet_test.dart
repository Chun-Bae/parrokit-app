// 챗봇 시트에서 모델 고르기가 열리는지 지킨다(5차 430).
//
// 기기에서 모델 칩을 눌러도 시트가 뜨지 않고, 닫기 단추와 입력칸까지
// 먹통이 되는 것을 봤다. 위젯으로는 멀쩡히 열린다(이 테스트). 그래서
// 코드 흐름이 아니라 기기 쪽(네이티브 탭 바 같은 플랫폼 뷰)을 의심한다.
// 적어도 코드가 망가지는 것은 이 테스트가 막는다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/features/content-studio/chat-bot/domain/entities/ai_chat_message.dart';
import 'package:parrokit/features/content-studio/chat-bot/domain/repositories/ai_chat_repository.dart';
import 'package:parrokit/features/content-studio/chat-bot/domain/usecases/send_chat_message_usecase.dart';
import 'package:parrokit/features/content-studio/chat-bot/presentation/chat_bot_provider.dart';
import 'package:parrokit/features/content-studio/chat-bot/presentation/widgets/chat_bot_sheet.dart';
import 'package:parrokit/core/shared/theme/app_theme.dart';

class _Repo implements AiChatRepository {
  @override
  Future<AiChatMessage> sendMessage(
          String text, List<AiChatMessage> history, String m, String mode) =>
      Completer<AiChatMessage>().future;

  @override
  Future<({int usedToday, int dailyLimit, int remainingToday})>
      fetchUsage() async => (usedToday: 0, dailyLimit: 30, remainingToday: 30);
}

void main() {
  testWidgets('모델 칩을 누르면 모델 고르기 시트가 뜬다', (tester) async {
    final provider = ChatBotProvider(useCase: SendChatMessageUseCase(_Repo()));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: ChangeNotifierProvider.value(
        value: provider,
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showChatBotSheet(context),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('만들기 도우미'), findsOneWidget);

    await tester.tap(find.text('Gemini Flash'));
    await tester.pumpAndSettle();
    expect(find.text('AI 모델 고르기'), findsOneWidget);
  });
}
