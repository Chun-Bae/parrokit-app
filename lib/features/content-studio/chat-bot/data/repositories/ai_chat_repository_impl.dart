import 'package:flutter/foundation.dart';
import '../../domain/entities/ai_chat_message.dart';
import '../../domain/repositories/ai_chat_repository.dart';
import '../data_sources/ai_chat_remote_data_source.dart';

class AiChatRepositoryImpl implements AiChatRepository {
  final AiChatRemoteDataSource remoteDataSource;

  const AiChatRepositoryImpl(this.remoteDataSource);

  @override
  Future<AiChatMessage> sendMessage(String text, List<AiChatMessage> history,
      String model, String chatbotMode) async {
    try {
      debugPrint(
          '[Chatbot][Repository] Sending message chatbotMode=$chatbotMode model=$model');
      final response =
          await remoteDataSource.sendMessage(text, history, model, chatbotMode);

      final actionDataRaw = response['actionData'];
      final Map<String, dynamic>? actionData = actionDataRaw != null
          ? Map<String, dynamic>.from(actionDataRaw as Map)
          : null;

      final message = AiChatMessage(
        text: response['text'] as String,
        isUser: false,
        recommendedPrompt: response['recommendedPrompt'] as String?,
        actionType: response['actionType'] as String?,
        actionData: actionData,
        remainingToday: (response['remainingToday'] as num?)?.toInt(),
        dailyLimit: (response['dailyLimit'] as num?)?.toInt(),
      );

      debugPrint(
          '[Chatbot][Repository] Message sent success actionType=${message.actionType}');
      return message;
    } catch (e) {
      debugPrint('[Chatbot][Repository] Failed to send message error=$e');
      rethrow;
    }
  }

  @override
  Future<({int usedToday, int dailyLimit, int remainingToday})>
      fetchUsage() async {
    final response = await remoteDataSource.fetchUsage();
    return (
      usedToday: (response['usedToday'] as num?)?.toInt() ?? 0,
      dailyLimit: (response['dailyLimit'] as num?)?.toInt() ?? 30,
      remainingToday: (response['remainingToday'] as num?)?.toInt() ?? 30,
    );
  }
}
