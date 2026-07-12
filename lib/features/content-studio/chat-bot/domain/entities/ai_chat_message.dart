class AiChatMessage {
  final String text;
  final bool isUser;
  final String? recommendedPrompt;
  final String? actionType;
  final Map<String, dynamic>? actionData;
  final String? chatbotMode; // 메시지 생성 당시의 에이전트 모드

  /// 이 응답 시점 기준 오늘 남은/전체 채팅 횟수. AI 응답에만 채워짐.
  final int? remainingToday;
  final int? dailyLimit;

  const AiChatMessage({
    required this.text,
    required this.isUser,
    this.recommendedPrompt,
    this.actionType,
    this.actionData,
    this.chatbotMode,
    this.remainingToday,
    this.dailyLimit,
  });

  AiChatMessage copyWith({
    String? text,
    bool? isUser,
    String? recommendedPrompt,
    String? actionType,
    Map<String, dynamic>? actionData,
    String? chatbotMode,
    int? remainingToday,
    int? dailyLimit,
  }) {
    return AiChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      recommendedPrompt: recommendedPrompt ?? this.recommendedPrompt,
      actionType: actionType ?? this.actionType,
      actionData: actionData ?? this.actionData,
      chatbotMode: chatbotMode ?? this.chatbotMode,
      remainingToday: remainingToday ?? this.remainingToday,
      dailyLimit: dailyLimit ?? this.dailyLimit,
    );
  }
}
