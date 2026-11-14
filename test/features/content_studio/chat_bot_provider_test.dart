// 챗봇 답을 기다리는 사이 새 대화를 시작했을 때의 회귀 테스트.
//
// 예전엔 예전 대화의 답이 새 대화에 끼어들고, 그 답의 모드 전환·추천까지
// 새 대화에 걸렸다.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/content-studio/chat-bot/domain/entities/ai_chat_message.dart';
import 'package:parrokit/features/content-studio/chat-bot/domain/repositories/ai_chat_repository.dart';
import 'package:parrokit/features/content-studio/chat-bot/domain/usecases/send_chat_message_usecase.dart';
import 'package:parrokit/features/content-studio/chat-bot/presentation/chat_bot_provider.dart';
import 'package:parrokit/features/content-studio/video/domain/models/video_generation_models.dart';

class _Repo implements AiChatRepository {
  final pending = <Completer<AiChatMessage>>[];

  @override
  Future<AiChatMessage> sendMessage(String text, List<AiChatMessage> history,
      String model, String chatbotMode) {
    final c = Completer<AiChatMessage>();
    pending.add(c);
    return c.future;
  }

  @override
  Future<({int usedToday, int dailyLimit, int remainingToday})>
      fetchUsage() async => (usedToday: 0, dailyLimit: 30, remainingToday: 30);
}

void main() {
  late _Repo repo;
  late ChatBotProvider provider;

  setUp(() {
    repo = _Repo();
    provider = ChatBotProvider(useCase: SendChatMessageUseCase(repo));
  });

  test('답이 오면 대화에 붙고 입력 중 표시가 꺼진다', () async {
    final sending = provider.sendMessage('안녕');
    expect(provider.isTyping, isTrue);
    repo.pending.single.complete(const AiChatMessage(
        text: '반가워요', isUser: false, remainingToday: 29, dailyLimit: 30));
    await sending;

    expect(provider.messages.first.text, '반가워요');
    expect(provider.isTyping, isFalse);
    expect(provider.remainingChatsToday, 29);
  });

  test('기다리는 사이 새 대화를 시작하면 예전 답을 버린다', () async {
    final sending = provider.sendMessage('TTS 만들고 싶어요');
    provider.resetChatbot();
    expect(provider.isTyping, isFalse);
    final fresh = provider.messages.map((m) => m.text).toList();

    repo.pending.single.complete(const AiChatMessage(
      text: 'TTS 모드로 바꿀게요',
      isUser: false,
      actionType: 'change_mode',
      actionData: {'targetMode': 'tts'},
      remainingToday: 28,
    ));
    await sending;

    expect(provider.messages.map((m) => m.text), fresh);
    expect(provider.chatbotMode, 'general');
    expect(provider.isTyping, isFalse);
    // 서버가 이미 센 횟수는 반영한다.
    expect(provider.remainingChatsToday, 28);
  });

  test('새 대화의 입력 중 표시를 예전 요청이 끄지 않는다', () async {
    final first = provider.sendMessage('첫 질문');
    provider.resetChatbot();
    final second = provider.sendMessage('새 질문');
    expect(provider.isTyping, isTrue);

    repo.pending.first.complete(
        const AiChatMessage(text: '첫 답', isUser: false));
    await first;
    expect(provider.isTyping, isTrue);

    repo.pending.last.complete(
        const AiChatMessage(text: '새 답', isUser: false));
    await second;
    expect(provider.isTyping, isFalse);
    expect(provider.messages.first.text, '새 답');
    expect(provider.messages.any((m) => m.text == '첫 답'), isFalse);
  });

  group('첫 인사', () {
    test('영상 만들기를 숨긴 동안에는 영상을 돕는다고 하지 않는다', () {
      final off = chatBotGreeting(videoEnabled: false);
      expect(off.contains('영상'), isFalse);
      expect(off.contains('TTS 음성 만들기'), isTrue);
    });

    test('영상 만들기를 켜면 영상도 함께 안내한다', () {
      final on = chatBotGreeting(videoEnabled: true);
      expect(on.contains('영상'), isTrue);
    });

    test('지금 설정(kVideoStudioEnabled)에 맞는 인사를 쓴다', () {
      expect(chatBotGreeting(),
          chatBotGreeting(videoEnabled: kVideoStudioEnabled));
    });
  });
}
