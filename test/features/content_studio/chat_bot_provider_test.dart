// 챗봇 답을 기다리는 사이 새 대화를 시작했을 때의 회귀 테스트.
//
// 예전엔 예전 대화의 답이 새 대화에 끼어들고, 그 답의 모드 전환·추천까지
// 새 대화에 걸렸다.
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/content-studio/chat-bot/domain/entities/ai_chat_message.dart';
import 'package:parrokit/features/content-studio/chat-bot/domain/repositories/ai_chat_repository.dart';
import 'package:parrokit/features/content-studio/chat-bot/domain/usecases/send_chat_message_usecase.dart';
import 'package:parrokit/features/content-studio/chat-bot/presentation/chat_bot_provider.dart';
import 'package:parrokit/features/content-studio/video/domain/models/video_generation_models.dart';

class _Repo implements AiChatRepository {
  final pending = <Completer<AiChatMessage>>[];

  /// 사용량 조회를 영영 끝내지 않게 하려면 true로 둔다(5차 429).
  bool usageNeverAnswers = false;

  /// 첫 조회만 영영 끝내지 않는다(5차 455). 서버가 쉬다 깨는 상황.
  bool usageSlowFirst = false;
  int usageCalls = 0;

  @override
  Future<AiChatMessage> sendMessage(String text, List<AiChatMessage> history,
      String model, String chatbotMode) {
    final c = Completer<AiChatMessage>();
    pending.add(c);
    return c.future;
  }

  @override
  Future<({int usedToday, int dailyLimit, int remainingToday})> fetchUsage() {
    usageCalls++;
    if (usageSlowFirst && usageCalls == 1) {
      return Completer<({int usedToday, int dailyLimit, int remainingToday})>()
          .future;
    }
    if (usageNeverAnswers) {
      return Completer<({int usedToday, int dailyLimit, int remainingToday})>()
          .future;
    }
    return Future.value((usedToday: 0, dailyLimit: 30, remainingToday: 30));
  }
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
      expect(off.contains('음성 만들기'), isTrue);
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


  test('사용량 조회가 대답 없으면 기다리다 끝낸다(5차 429)', () {
    // 전에는 기다림에 끝이 없어서 시트 맨 위 동그라미가 영영 돌았다.
    fakeAsync((async) {
      repo.usageNeverAnswers = true;
      final done = provider.fetchDailyUsage();
      var finished = false;
      done.then((_) => finished = true);

      async.elapse(const Duration(seconds: 7));
      expect(provider.isUsageLoading, isTrue, reason: '아직 기다리는 중');

      // 한 번 접히면 조용히 한 번 더 묻는다(5차 455).
      async.elapse(ChatBotProvider.usageTimeout);
      expect(finished, isFalse, reason: '한 번 더 묻는 중');

      async.elapse(ChatBotProvider.usageTimeout);
      expect(finished, isTrue);
      expect(provider.isUsageLoading, isFalse, reason: '동그라미가 멈춘다');
    });
  });

  test('첫 사용량 조회가 접히면 조용히 한 번 더 묻는다(5차 455)', () {
    // 서버가 쉬다 깨는 첫 호출은 기다릴 시간을 넘긴다. 전에는 그대로
    // 접혀서 시트를 열 때마다 남은 횟수가 비어 있었다.
    fakeAsync((async) {
      repo.usageSlowFirst = true;
      provider.fetchDailyUsage();

      async.elapse(ChatBotProvider.usageTimeout + const Duration(seconds: 1));
      async.flushMicrotasks();

      expect(repo.usageCalls, 2, reason: '한 번 더 물었다');
      expect(provider.remainingChatsToday, 30);
      expect(provider.isUsageLoading, isFalse);
    });
  });

  test('두 번 다 대답이 없으면 접고 대화는 할 수 있다', () {
    fakeAsync((async) {
      repo.usageNeverAnswers = true;
      provider.fetchDailyUsage();

      async.elapse(ChatBotProvider.usageTimeout * 2 +
          const Duration(seconds: 1));
      async.flushMicrotasks();

      expect(repo.usageCalls, 2);
      expect(provider.isUsageLoading, isFalse, reason: '도는 동그라미를 남기지 않는다');
    });
  });

  test('조회하기 전에는 사용량을 안다고 하지 않는다(5차 456)', () {
    // 전에는 기본값 30을 그대로 '오늘 사용량 30/30'으로 적었다.
    expect(provider.usageKnown, isFalse);
    expect(provider.usedChatsToday, isNull);
  });

  test('조회에 성공하면 쓴 횟수를 셈한다', () async {
    await provider.fetchDailyUsage();

    expect(provider.usageKnown, isTrue);
    // 한도 30, 남은 30이면 오늘 쓴 것은 0이다.
    expect(provider.usedChatsToday, 0);
  });

  test('두 번 다 실패하면 모른다고 둔다', () {
    fakeAsync((async) {
      repo.usageNeverAnswers = true;
      provider.fetchDailyUsage();

      async.elapse(
          ChatBotProvider.usageTimeout * 2 + const Duration(seconds: 1));
      async.flushMicrotasks();

      expect(provider.usageKnown, isFalse);
      expect(provider.usedChatsToday, isNull);
    });
  });

  test('답에 횟수가 실려 오면 그때부터는 안다', () async {
    final sending = provider.sendMessage('안녕');
    repo.pending.single.complete(const AiChatMessage(
        text: '반가워요', isUser: false, remainingToday: 29, dailyLimit: 30));
    await sending;

    expect(provider.usageKnown, isTrue);
    expect(provider.usedChatsToday, 1);
  });
}
