import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import '../../domain/entities/ai_chat_message.dart';
import 'gradient_helper.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.onTriggerAction,
  });

  final AiChatMessage message;
  final void Function(int tabIndex, Map<String, dynamic>? actionData)?
      onTriggerAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(top: 6, bottom: 6, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFF0052D4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            message.text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    } else {
      final mode = message.chatbotMode ?? 'general';
      final currentGradient = getGradientForMode(mode);

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: currentGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: currentGradient.colors.last.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceContainerHighDark
                          : AppColors.surfaceContainer,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      border: Border.all(
                        color: isDark
                            ? AppColors.dividerSubtleDark
                            : AppColors.dividerSubtle,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MarkdownBody(
                          data: message.text,
                          shrinkWrap: true,
                          selectable: true,
                          builders: {
                            'code': CodeElementBuilder(context),
                          },
                          styleSheet:
                              MarkdownStyleSheet.fromTheme(theme).copyWith(
                            p: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimary,
                              height: 1.4,
                            ),
                            code: const TextStyle(
                                backgroundColor: Colors.transparent),
                            codeblockDecoration:
                                const BoxDecoration(color: Colors.transparent),
                          ),
                        ),
                        if (message.actionType == 'tts_trigger' ||
                            message.actionType == 'video_trigger' ||
                            message.actionType ==
                                'video_prompt_recommendation') ...[
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () {
                              if (onTriggerAction != null) {
                                final isVideo =
                                    message.actionType == 'video_trigger' ||
                                        message.actionType ==
                                            'video_prompt_recommendation';
                                final targetTab = isVideo ? 2 : 1;
                                if (message.actionType ==
                                        'video_prompt_recommendation' &&
                                    message.actionData != null) {
                                  final recommendations =
                                      message.actionData!['recommendations'];
                                  if (recommendations is List &&
                                      recommendations.isNotEmpty) {
                                    final first = recommendations.first;
                                    if (first is Map) {
                                      onTriggerAction!(targetTab, {
                                        'script':
                                            first['script']?.toString() ?? '',
                                        'prompt':
                                            first['prompt']?.toString() ?? '',
                                      });
                                    } else {
                                      onTriggerAction!(
                                          targetTab, message.actionData);
                                    }
                                  } else {
                                    final scripts =
                                        message.actionData!['scripts'];
                                    final prompts =
                                        message.actionData!['prompts'];
                                    if (scripts is List &&
                                        prompts is List &&
                                        scripts.isNotEmpty &&
                                        prompts.isNotEmpty) {
                                      onTriggerAction!(targetTab, {
                                        'script': scripts.first.toString(),
                                        'prompt': prompts.first.toString(),
                                      });
                                    } else {
                                      onTriggerAction!(
                                          targetTab, message.actionData);
                                    }
                                  }
                                } else {
                                  onTriggerAction!(
                                      targetTab, message.actionData);
                                }
                                Navigator.of(context).pop();
                              } else {
                                showToast(
                                  message.actionType == 'video_trigger'
                                      ? '비디오 생성 화면으로 이동합니다'
                                      : message.actionType ==
                                              'video_prompt_recommendation'
                                          ? '비디오 프롬프트 추천을 적용합니다'
                                          : 'TTS 생성 화면으로 이동합니다',
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: (message.actionType ==
                                              'video_trigger' ||
                                          message.actionType ==
                                              'video_prompt_recommendation')
                                      ? [
                                          AppColors.primary,
                                          const Color(0xFF00C6FF)
                                        ]
                                      : [
                                          AppColors.secondary,
                                          const Color(0xFFC084FC)
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: ((message.actionType ==
                                                    'video_trigger' ||
                                                message.actionType ==
                                                    'video_prompt_recommendation')
                                            ? AppColors.primary
                                            : AppColors.secondary)
                                        .withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    message.actionType == 'video_trigger' ||
                                            message.actionType ==
                                                'video_prompt_recommendation'
                                        ? Icons.videocam_rounded
                                        : Icons.audiotrack_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    message.actionType == 'video_trigger'
                                        ? '비디오 생성하기'
                                        : message.actionType ==
                                                'video_prompt_recommendation'
                                            ? '한 쌍 추가하기'
                                            : 'TTS 생성하기',
                                    style:
                                        theme.textTheme.labelMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
          ],
        ),
      );
    }
  }
}

class CodeElementBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  CodeElementBuilder(this.context);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final codeText = element.textContent.trim();

    if (!element.textContent.contains('\n')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isDark ? Colors.white12 : Colors.black12,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          codeText,
          style: preferredStyle?.copyWith(
            fontFamily: 'monospace',
            fontSize: 13,
            color: isDark ? const Color(0xFFC084FC) : const Color(0xFF8B5CF6),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.dividerSubtleDark : AppColors.dividerSubtle,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 48, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                codeText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: codeText));
                  showToast('추천 프롬프트가 복사되었습니다');
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 16,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
