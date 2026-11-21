import '../entities/ai_chat_message.dart';
import '../repositories/ai_chat_repository.dart';

class SendChatMessageUseCase {
  final AiChatRepository repository;

  const SendChatMessageUseCase(this.repository);

  Future<AiChatMessage> call(String text, List<AiChatMessage> history,
      String model, String chatbotMode) async {
    // 패롯 잔액 부족 등의 도메인 규칙을 여기에서 검증할 수 있습니다.
    if (text.trim().isEmpty) {
      throw Exception('Message cannot be empty');
    }
    return repository.sendMessage(text, history, model, chatbotMode);
  }
}
