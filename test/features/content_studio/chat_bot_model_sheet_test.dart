// 챗봇 시트에서 모델 고르기가 열리는지 지킨다(5차 430~431).
//
// 기기에서 모델 칩을 눌러도 시트가 뜨지 않고, 닫기 단추와 입력칸까지
// 먹통이었다. 까닭은 **시트를 띄운 Navigator**였다. 스튜디오는 아래 탭 바가
// 없는 화면으로 셈해져(appShellHidesNavBar), 공통 시트가 셸 안쪽
// Navigator에 떴다. 맨 위 Navigator에 띄우니 바로 풀렸다(431에서 확인).
import 'dart:async';
import 'dart:io';

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

  test('챗봇 시트는 맨 위 Navigator에 띄운다(5차 431)', () {
    // 셸 안쪽 Navigator에 띄우면 기기에서 시트가 통째로 먹통이 된다.
    final code = File(
            'lib/features/content-studio/chat-bot/presentation/widgets/chat_bot_sheet.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(code, contains('rootNavigator: true'));
  });
}
