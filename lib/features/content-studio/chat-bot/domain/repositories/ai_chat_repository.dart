import '../entities/ai_chat_message.dart';

abstract class AiChatRepository {
  Future<AiChatMessage> sendMessage(String text, List<AiChatMessage> history,
      String model, String chatbotMode);

  /// 채팅을 보내지 않고 오늘 사용량만 조회합니다.
  Future<({int usedToday, int dailyLimit, int remainingToday})> fetchUsage();
}
