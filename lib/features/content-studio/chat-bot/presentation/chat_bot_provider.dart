import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../domain/entities/ai_chat_message.dart';
import '../domain/usecases/send_chat_message_usecase.dart';
import '../data/data_sources/ai_chat_remote_data_source.dart';
import '../data/repositories/ai_chat_repository_impl.dart';

class ChatBotProvider extends ChangeNotifier {
  late final SendChatMessageUseCase _sendMessageUseCase;

  final List<AiChatMessage> _messages = [
    const AiChatMessage(
      text: '안녕하세요! TTS 생성 및 비디오 생성을 도와드릴 챗봇입니다.\n어떤 영상이나 음성을 만들고 싶으신가요?',
      isUser: false,
      chatbotMode: 'general',
    ),
  ];

  String _selectedModel = 'gemini-2.5-flash';
  String get selectedModel => _selectedModel;

  ChatBotProvider({SendChatMessageUseCase? useCase}) {
    // 임시 의존성 주입 (차후 get_it 등으로 교체 가능)
    _sendMessageUseCase = useCase ??
        SendChatMessageUseCase(
          AiChatRepositoryImpl(AiChatRemoteDataSource()),
        );
  }

  List<AiChatMessage> get messages => _messages;

  bool _isTyping = false;
  bool get isTyping => _isTyping;

  /// 오늘 남은/전체 채팅 횟수. 첫 응답을 받기 전에는 서버 기본 한도(30)로 표시한다.
  int _remainingChatsToday = 30;
  int get remainingChatsToday => _remainingChatsToday;

  int _dailyChatLimit = 30;
  int get dailyChatLimit => _dailyChatLimit;

  /// 서버에서 실제 사용량을 아직 못 받아온 상태인지 여부.
  bool _isUsageLoading = true;
  bool get isUsageLoading => _isUsageLoading;

  /// 시트를 열 때 채팅을 보내지 않고 오늘 사용량만 조회해 배지에 반영한다.
  Future<void> fetchDailyUsage() async {
    try {
      final usage = await _sendMessageUseCase.repository.fetchUsage();
      _remainingChatsToday = usage.remainingToday;
      _dailyChatLimit = usage.dailyLimit;
    } catch (e) {
      debugPrint('[Chatbot][Provider] Failed to fetch daily usage error=$e');
    } finally {
      _isUsageLoading = false;
      notifyListeners();
    }
  }

  void updateSelectedModel(String model) {
    if (_selectedModel != model) {
      _selectedModel = model;
      notifyListeners();
    }
  }

  String _chatbotMode = 'general';
  String get chatbotMode => _chatbotMode;

  void updateChatbotMode(String mode) {
    if (_chatbotMode != mode) {
      _chatbotMode = mode;
      notifyListeners();
    }
  }

  bool _hasPendingRouting = false;
  bool get hasPendingRouting => _hasPendingRouting;

  void consumePendingRouting() {
    if (_hasPendingRouting) {
      _hasPendingRouting = false;
      notifyListeners();
    }
  }

  List<String>? _pendingScriptRecommendations;
  List<String>? get pendingScriptRecommendations =>
      _pendingScriptRecommendations;

  void consumeScriptRecommendation() {
    if (_pendingScriptRecommendations != null) {
      _pendingScriptRecommendations = null;
      notifyListeners();
    }
  }

  List<Map<String, String>>? _pendingVideoRecommendations;
  List<Map<String, String>>? get pendingVideoRecommendations =>
      _pendingVideoRecommendations;

  void consumeVideoRecommendations() {
    if (_pendingVideoRecommendations != null) {
      _pendingVideoRecommendations = null;
      notifyListeners();
    }
  }

  void resetChatbot() {
    _chatbotMode = 'general';
    _hasPendingRouting = false;
    _pendingScriptRecommendations = null;
    _pendingVideoRecommendations = null;
    _messages.clear();
    _messages.insert(
      0,
      const AiChatMessage(
        text: '안녕하세요! TTS 생성 및 비디오 생성을 도와드릴 챗봇입니다.\n어떤 영상이나 음성을 만들고 싶으신가요?',
        isUser: false,
        chatbotMode: 'general',
      ),
    );
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // 현재까지의 대화 목록 복사 (새 사용자 메시지 추가 전)
    final history = List<AiChatMessage>.from(_messages);

    // 사용자 메시지 추가
    _messages.insert(
        0, AiChatMessage(text: text, isUser: true, chatbotMode: _chatbotMode));
    _isTyping = true;
    notifyListeners();

    try {
      debugPrint(
          '[Chatbot][Provider] Calling sendMessageUseCase text=$text chatbotMode=$_chatbotMode');
      // AI 응답 호출 (대화 히스토리, 모델 정보, 챗봇 모드 포함)
      final aiResponse = await _sendMessageUseCase.call(
          text, history, _selectedModel, _chatbotMode);

      // AI 응답의 actionType이 change_mode인 경우, 클라이언트의 챗봇 모드 전환 처리
      if (aiResponse.actionType == 'change_mode' &&
          aiResponse.actionData != null) {
        final targetMode = aiResponse.actionData!['targetMode'] as String?;
        if (targetMode != null) {
          _chatbotMode = targetMode;
          debugPrint(
              '[Chatbot][Provider] Mode changed dynamically targetMode=$_chatbotMode');
        }
      }

      debugPrint(
          '[Chatbot][Provider] AI Response actionType=${aiResponse.actionType} actionData=${aiResponse.actionData}');

      if (aiResponse.actionType == 'ask_routing') {
        _hasPendingRouting = true;
        debugPrint(
            '[Chatbot][Provider] Routing action pending flag set to true');
      } else if (aiResponse.actionType == 'script_recommendation' &&
          aiResponse.actionData != null) {
        if (aiResponse.actionData!['scripts'] != null) {
          final rawScripts = aiResponse.actionData!['scripts'] as List<dynamic>;
          _pendingScriptRecommendations =
              rawScripts.map((e) => e.toString()).toList();
        } else if (aiResponse.actionData!['text'] != null) {
          // 호환성을 위해 text가 있으면 단일 항목 리스트로 만듦
          _pendingScriptRecommendations = [
            aiResponse.actionData!['text'].toString()
          ];
        }
        debugPrint(
            '[Chatbot][Provider] Script recommendation pending: $_pendingScriptRecommendations');
      } else if (aiResponse.actionType == 'video_prompt_recommendation' &&
          aiResponse.actionData != null) {
        _pendingVideoRecommendations =
            _extractVideoRecommendations(aiResponse.actionData!);
        debugPrint(
            '[Chatbot][Provider] Video recommendations pending: $_pendingVideoRecommendations');
      }

      debugPrint(
          '[Chatbot][Provider] Send message success replyLength=${aiResponse.text.length} actionType=${aiResponse.actionType}');
      _remainingChatsToday = aiResponse.remainingToday ?? _remainingChatsToday;
      _dailyChatLimit = aiResponse.dailyLimit ?? _dailyChatLimit;
      _messages.insert(0, aiResponse.copyWith(chatbotMode: _chatbotMode));
    } catch (e) {
      debugPrint('[Chatbot][Provider] Send message failed error=$e');
      final message = e is FirebaseFunctionsException &&
              e.message != null &&
              e.message!.trim().isNotEmpty
          ? e.message!
          : '오류가 발생했습니다. 다시 시도해 주세요.';
      _messages.insert(
        0,
        AiChatMessage(
          text: message,
          isUser: false,
          chatbotMode: _chatbotMode,
        ),
      );
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  List<Map<String, String>> _extractVideoRecommendations(
    Map<String, dynamic> actionData,
  ) {
    final recommendations = <Map<String, String>>[];

    final rawRecommendations = actionData['recommendations'];
    if (rawRecommendations is List) {
      for (final item in rawRecommendations) {
        if (item is Map) {
          final script = item['script']?.toString().trim() ?? '';
          final prompt = item['prompt']?.toString().trim() ?? '';
          if (script.isNotEmpty || prompt.isNotEmpty) {
            recommendations.add({
              'script': script,
              'prompt': prompt,
            });
          }
        }
      }
    }

    if (recommendations.isNotEmpty) {
      return recommendations;
    }

    final rawScripts = actionData['scripts'];
    final rawPrompts = actionData['prompts'];
    if (rawScripts is List) {
      final promptSource =
          rawPrompts is List && rawPrompts.isNotEmpty ? rawPrompts : rawScripts;
      final count = rawScripts.length < promptSource.length
          ? rawScripts.length
          : promptSource.length;
      for (var i = 0; i < count; i++) {
        final script = rawScripts[i].toString().trim();
        final prompt = promptSource[i].toString().trim();
        if (script.isNotEmpty || prompt.isNotEmpty) {
          recommendations.add({
            'script': script,
            'prompt': prompt,
          });
        }
      }
    }

    return recommendations;
  }
}
