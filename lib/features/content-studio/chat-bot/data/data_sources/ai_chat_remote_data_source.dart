import 'package:cloud_functions/cloud_functions.dart';
import '../../domain/entities/ai_chat_message.dart';

class AiChatRemoteDataSource {
  Future<Map<String, dynamic>> sendMessage(String text,
      List<AiChatMessage> history, String model, String chatbotMode) async {
    // 1. 대화 기록을 Genkit 및 Cloud Functions 요구 구조로 매핑 (시간순 정렬)
    final mappedHistory = history.reversed.map((msg) {
      return {
        'role': msg.isUser ? 'user' : 'model',
        'text': msg.text,
      };
    }).toList();

    // 2. Gemini 대화 시작 규칙 준수: 첫 시작은 반드시 'user'이어야 하므로
    // 첫 'user' 메시지가 나타나기 전의 앞선 'model' 메시지(예: 최초 웰컴 메시지)들은 제외합니다.
    final firstUserIndex =
        mappedHistory.indexWhere((msg) => msg['role'] == 'user');
    final List<Map<String, String>> historyData =
        firstUserIndex != -1 ? mappedHistory.sublist(firstUserIndex) : [];

    // 3. Firebase Cloud Functions 호출
    final callable =
        FirebaseFunctions.instance.httpsCallable('generateChatbotResponse');

    final response = await callable.call({
      'message': text,
      'history': historyData,
      'model': model,
      'chatbotMode': chatbotMode,
    });

    final Map<String, dynamic> data =
        Map<String, dynamic>.from(response.data as Map);

    final String aiText = data['reply'] as String? ?? '';
    final String? actionType = data['actionType'] as String?;
    final Map<String, dynamic>? actionData = data['actionData'] != null
        ? Map<String, dynamic>.from(data['actionData'] as Map)
        : null;

    String? recommendedPrompt;
    if (actionType == 'video_trigger' && actionData != null) {
      recommendedPrompt = actionData['prompt'] as String?;
    } else if (actionType == 'tts_trigger' && actionData != null) {
      recommendedPrompt = actionData['text'] as String?;
    } else if (actionType == 'script_recommendation' && actionData != null) {
      recommendedPrompt = actionData['text'] as String?;
    } else if (actionType == 'video_prompt_recommendation' &&
        actionData != null) {
      final recommendations = actionData['recommendations'];
      if (recommendations is List && recommendations.isNotEmpty) {
        final first = recommendations.first;
        if (first is Map) {
          recommendedPrompt = first['prompt']?.toString();
        }
      }
      if (recommendedPrompt == null) {
        final prompts = actionData['prompts'];
        if (prompts is List && prompts.isNotEmpty) {
          recommendedPrompt = prompts.first.toString();
        }
      }
    }

    return {
      'text': aiText,
      'recommendedPrompt': recommendedPrompt,
      'actionType': actionType,
      'actionData': actionData,
      'remainingToday': data['remainingToday'] as num?,
      'dailyLimit': data['dailyLimit'] as num?,
    };
  }

  /// 채팅을 보내지 않고 오늘 사용량만 조회합니다.
  Future<Map<String, dynamic>> fetchUsage() async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('getChatbotUsage');
    final response = await callable.call();
    return Map<String, dynamic>.from(response.data as Map);
  }
}
