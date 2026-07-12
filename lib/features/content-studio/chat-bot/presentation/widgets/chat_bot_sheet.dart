import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import '../chat_bot_provider.dart';
import 'gradient_helper.dart';
import 'chat_bubble.dart';
import 'typing_indicator.dart';
import 'model_selector_sheet.dart';
import 'routing_bottom_sheet.dart';
import 'script_recommendation_sheet.dart';
import 'video_prompt_recommendation_sheet.dart';

Future<void> showChatBotSheet(
  BuildContext context, {
  void Function(int tabIndex, Map<String, dynamic>? actionData)?
      onTriggerAction,
  String? initialMessage,
}) async {
  final chatBotProvider = Provider.of<ChatBotProvider>(context, listen: false);
  final mediaQuery = MediaQuery.of(context);
  final statusBarHeight = mediaQuery.padding.top;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    showDragHandle: false,
    builder: (context) {
      return ChangeNotifierProvider.value(
        value: chatBotProvider,
        child: _ChatBotSheet(
          initialMessage: initialMessage,
          onTriggerAction: onTriggerAction,
          statusBarHeight: statusBarHeight,
        ),
      );
    },
  );
}

class _ChatBotSheet extends StatefulWidget {
  const _ChatBotSheet({
    this.initialMessage,
    this.onTriggerAction,
    required this.statusBarHeight,
  });

  final String? initialMessage;
  final void Function(int tabIndex, Map<String, dynamic>? actionData)?
      onTriggerAction;
  final double statusBarHeight;

  @override
  State<_ChatBotSheet> createState() => _ChatBotSheetState();
}

class _ChatBotSheetState extends State<_ChatBotSheet> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialMessage = widget.initialMessage?.trim();
      if (!mounted || initialMessage == null || initialMessage.isEmpty) {
        return;
      }
      context.read<ChatBotProvider>().sendMessage(initialMessage);
    });
  }

  void _onTextChanged() {
    final hasText = _textController.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    context.read<ChatBotProvider>().sendMessage(text);
    _textController.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? AppColors.surfaceContainerDark : AppColors.surface;
    final dividerColor = isDark ? AppColors.dividerDark : AppColors.divider;
    final provider = context.watch<ChatBotProvider>();

    if (provider.hasPendingRouting) {
      debugPrint('[Chatbot][UI] Detected hasPendingRouting=true in build');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && provider.hasPendingRouting) {
          debugPrint('[Chatbot][UI] Triggering showRoutingBottomSheet...');
          provider.consumePendingRouting();
          showRoutingBottomSheet(context, provider);
        } else {
          debugPrint(
              '[Chatbot][UI] Routing pop skipped. mounted=$mounted, hasPendingRouting=${provider.hasPendingRouting}');
        }
      });
    }

    if (provider.pendingScriptRecommendations != null) {
      final scripts = provider.pendingScriptRecommendations!;
      debugPrint(
          '[Chatbot][UI] Detected pendingScriptRecommendations in build');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && provider.pendingScriptRecommendations != null) {
          debugPrint(
              '[Chatbot][UI] Triggering showScriptRecommendationSheet...');
          provider.consumeScriptRecommendation();
          showScriptRecommendationSheet(
              context, scripts, widget.onTriggerAction);
        }
      });
    }

    if (provider.pendingVideoRecommendations != null) {
      final recommendations = provider.pendingVideoRecommendations!;
      debugPrint('[Chatbot][UI] Detected pendingVideoRecommendations in build');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && provider.pendingVideoRecommendations != null) {
          debugPrint(
              '[Chatbot][UI] Triggering showVideoPromptRecommendationSheet...');
          provider.consumeVideoRecommendations();
          showVideoPromptRecommendationSheet(
            context,
            recommendations: recommendations,
            onTriggerAction: widget.onTriggerAction,
          );
        }
      });
    }

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final statusBarHeight = widget.statusBarHeight;

    final maxSheetHeight = screenHeight - keyboardHeight - statusBarHeight - 16;
    final defaultSheetHeight = screenHeight * 0.7;
    final sheetHeight = defaultSheetHeight > maxSheetHeight
        ? (maxSheetHeight > 0 ? maxSheetHeight : 0.0)
        : defaultSheetHeight;

    return Padding(
      padding: EdgeInsets.only(
        bottom: keyboardHeight,
      ),
      child: Container(
        height: sheetHeight,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.transparent,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: getGradientForMode(provider.chatbotMode),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.chatbotMode == 'tts'
                              ? 'AI TTS 어시스턴트'
                              : provider.chatbotMode == 'video'
                                  ? 'AI 비디오 어시스턴트'
                                  : 'AI 스튜디오 어시스턴트',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                [
                                  provider.chatbotMode == 'tts'
                                      ? '음성 스튜디오 튜닝 중'
                                      : provider.chatbotMode == 'video'
                                          ? '비디오 씬 기획 중'
                                          : '도움 준비 완료',
                                  if (provider.remainingChatsToday != null &&
                                      provider.dailyChatLimit != null)
                                    '오늘 ${provider.remainingChatsToday}/${provider.dailyChatLimit}',
                                ].join(' · '),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? AppColors.textTertiaryDark
                                      : AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 모델 선택 칩
                  InkWell(
                    onTap: () =>
                        showModelSelectorBottomSheet(context, provider),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceContainerHighDark
                            : AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? AppColors.dividerSubtleDark
                              : AppColors.dividerSubtle,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            provider.selectedModel == 'gemini-2.5-flash'
                                ? 'Gemini Flash'
                                : 'Gemini Pro',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 14,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: isDark
                        ? AppColors.surfaceContainerHighDark
                        : AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(30),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: dividerColor),

            // Chat list
            Expanded(
              child: Consumer<ChatBotProvider>(
                builder: (context, vm, _) {
                  final messages = vm.messages;
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    itemCount: messages.length + (vm.isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (vm.isTyping && index == 0) {
                        return const TypingIndicator();
                      }

                      final msg = messages[vm.isTyping ? index - 1 : index];
                      return ChatBubble(
                        message: msg,
                        onTriggerAction: widget.onTriggerAction,
                      );
                    },
                  );
                },
              ),
            ),

            // Input area
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom > 0
                    ? MediaQuery.of(context).padding.bottom + 8
                    : 24,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _focusNode.requestFocus();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceContainerHighDark
                        : AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: isDark
                          ? AppColors.dividerSubtleDark
                          : AppColors.dividerSubtle,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.15 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      PopupMenuButton<String>(
                        constraints: const BoxConstraints(
                          minWidth: 180,
                          maxWidth: 240,
                        ),
                        icon: Icon(
                          Icons.menu_rounded,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                        offset: const Offset(12, -210),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isDark
                                ? AppColors.dividerDark
                                : AppColors.divider,
                            width: 1, // 테두리 두께
                          ),
                        ),
                        onSelected: (value) {
                          if (value == 'reset') {
                            provider.resetChatbot();
                          } else if (value == 'mode_general') {
                            provider.updateChatbotMode('general');
                          } else if (value == 'mode_tts') {
                            provider.updateChatbotMode('tts');
                          } else if (value == 'mode_video') {
                            provider.updateChatbotMode('video');
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: 'reset',
                            height: 38,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '대화 초기화',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(
                            height: 1,
                          ),
                          PopupMenuItem<String>(
                            value: 'mode_general',
                            height: 38,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: Center(
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF8B5CF6), // 퍼플
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '일반 안내 모드',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (provider.chatbotMode == 'general')
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: Color(0xFF8B5CF6),
                                  ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'mode_tts',
                            height: 38,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: Center(
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEC4899), // 핑크
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'TTS 전문가 모드',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (provider.chatbotMode == 'tts')
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: Color(0xFFEC4899),
                                  ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'mode_video',
                            height: 38,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: Center(
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF3B82F6), // 블루
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '비디오 전문가 모드',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (provider.chatbotMode == 'video')
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: Color(0xFF3B82F6),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          style: theme.textTheme.bodyMedium,
                          decoration: InputDecoration(
                            hintText: 'TTS나 비디오 생성 요청을 입력하세요...',
                            hintStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiary,
                            ),
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          onSubmitted: (_) => _handleSend(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOutCubic,
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: _hasText
                              ? const LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.secondary
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: _hasText
                              ? null
                              : (isDark
                                  ? AppColors.surfaceContainerDark
                                  : AppColors.surface),
                          shape: BoxShape.circle,
                          border: _hasText
                              ? null
                              : Border.all(
                                  color: isDark
                                      ? AppColors.dividerSubtleDark
                                      : AppColors.dividerSubtle,
                                ),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.send_rounded,
                            color: _hasText
                                ? Colors.white
                                : (isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiary),
                            size: 18,
                          ),
                          onPressed: _handleSend,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
