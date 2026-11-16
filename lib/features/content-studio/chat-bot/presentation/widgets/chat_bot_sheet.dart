import 'package:flutter/material.dart';
import 'package:parrokit/features/content-studio/shared/studio_colors.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import '../chat_bot_provider.dart';
import 'gradient_helper.dart';
import 'chat_bubble.dart';
import 'typing_indicator.dart';
import 'model_selector_sheet.dart';
import 'routing_bottom_sheet.dart';
import 'script_recommendation_sheet.dart';
import 'video_prompt_recommendation_sheet.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';
import 'package:parrokit/features/content-studio/video/domain/models/video_generation_models.dart';

Future<void> showChatBotSheet(
  BuildContext context, {
  void Function(int tabIndex, Map<String, dynamic>? actionData)?
      onTriggerAction,
  String? initialMessage,
}) async {
  final chatBotProvider = Provider.of<ChatBotProvider>(context, listen: false);
  final mediaQuery = MediaQuery.of(context);
  final statusBarHeight = mediaQuery.padding.top;

  await showAppSheet(
    context: context,
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

  /// 말풍선에서 알릴 말(복사했어요 등). 시트 안에 적는다(5차 371).
  ///
  /// 전에는 토스트로 띄웠는데 도우미는 바텀시트라 시트가 아래를 덮어
  /// 보이지 않았다(368~370에서 다른 시트로 확인).
  String? _notice;

  void _showNotice(String message) {
    if (!mounted) return;
    setState(() => _notice = message);
  }

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    context.read<ChatBotProvider>().fetchDailyUsage();
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
    final bg =
        isDark ? context.tokens.surfaceContainer : context.tokens.surface;
    final dividerColor = context.tokens.divider;
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
    final defaultSheetHeight = screenHeight * 0.88;
    final sheetHeight = defaultSheetHeight > maxSheetHeight
        ? (maxSheetHeight > 0 ? maxSheetHeight : 0.0)
        : defaultSheetHeight;

    return Padding(
      padding: EdgeInsets.only(
        bottom: keyboardHeight,
      ),
      child: Container(
        height: sheetHeight,
        clipBehavior: Clip.antiAlias,
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
            // 하루 사용 제한량 (항상 표시)
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: context.tokens.surfaceContainerHigh,
              child: provider.isUsageLoading
                  ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.tokens.textSecondary,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          size: 14,
                          color: context.tokens.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '오늘 사용량 ${provider.remainingChatsToday}/${provider.dailyChatLimit}',
                          style: context.texts.labelSmall.copyWith(
                            color: context.tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
            ),
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
                      borderRadius: BorderRadius.circular(AppRadius.md),
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
                          // 앱의 다른 곳은 한국어로 부른다(앵무새·목소리·클립).
                          // '비디오'는 5차에 '영상'으로 맞췄는데 여기만 남아
                          // 있었다.
                          provider.chatbotMode == 'tts'
                              ? '음성 도우미'
                              : provider.chatbotMode == 'video'
                                  ? '영상 만들기 도우미'
                                  : '만들기 도우미',
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
                              decoration: BoxDecoration(
                                color: context.tokens.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                provider.chatbotMode == 'tts'
                                    ? '음성 만들기를 도와줄게요'
                                    : provider.chatbotMode == 'video'
                                        ? '영상 만들기를 도와줄게요'
                                        : '무엇이든 물어보세요',
                                style: context.texts.labelSmall.copyWith(
                                  color: isDark
                                      ? context.tokens.textTertiary
                                      : context.tokens.textSecondary,
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
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.tokens.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(
                          color: context.tokens.dividerSubtle,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 12,
                            color: context.tokens.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            provider.selectedModel == 'gemini-2.5-flash'
                                ? 'Gemini Flash'
                                : 'Gemini Pro',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.tokens.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 14,
                            color: context.tokens.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: context.tokens.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(30),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: context.tokens.textSecondary,
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
                        onNotice: _showNotice,
                      );
                    },
                  );
                },
              ),
            ),

            if (_notice != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: Text(
                  _notice!,
                  key: const ValueKey('chatbot-notice'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: context.tokens.textSecondary),
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
                    color: context.tokens.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: context.tokens.dividerSubtle,
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
                          color: context.tokens.textSecondary,
                        ),
                        offset: const Offset(12, -210),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          side: BorderSide(
                            color: context.tokens.divider,
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
                                  color: context.tokens.textPrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '대화 초기화',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: context.tokens.textPrimary,
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
                                        color: StudioColors.generalPurple, // 퍼플
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
                                      color: context.tokens.textPrimary,
                                    ),
                                  ),
                                ),
                                if (provider.chatbotMode == 'general')
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: StudioColors.generalPurple,
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
                                        color: StudioColors.ttsPink, // 핑크
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '음성 전문가 모드',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: context.tokens.textPrimary,
                                    ),
                                  ),
                                ),
                                if (provider.chatbotMode == 'tts')
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: StudioColors.ttsPink,
                                  ),
                              ],
                            ),
                          ),
                          // 영상 만들기를 숨긴 동안에는 이 모드도 숨긴다.
                          // 골라도 영상 화면으로 갈 수 없다(5차).
                          if (kVideoStudioEnabled)
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
                                          color: StudioColors.videoBlue, // 블루
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '영상 만들기 도우미',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: context.tokens.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (provider.chatbotMode == 'video')
                                    const Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: StudioColors.videoBlue,
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
                            hintText: kVideoStudioEnabled
                                ? '음성이나 영상 만들기 요청을 적어 보세요...'
                                : '음성으로 만들 내용을 적어 보세요...',
                            hintStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: context.tokens.textTertiary,
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
                              ? LinearGradient(
                                  colors: [
                                    context.tokens.primary,
                                    context.tokens.secondary
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: _hasText
                              ? null
                              : (isDark
                                  ? context.tokens.surfaceContainer
                                  : context.tokens.surface),
                          shape: BoxShape.circle,
                          border: _hasText
                              ? null
                              : Border.all(
                                  color: context.tokens.dividerSubtle,
                                ),
                        ),
                        child: IconButton(
                          tooltip: '보내기',
                          icon: Icon(
                            Icons.send_rounded,
                            color: _hasText
                                ? Colors.white
                                : (context.tokens.textTertiary),
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
