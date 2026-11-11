import 'package:flutter/material.dart';
import 'package:parrokit/features/content-studio/shared/studio_colors.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import '../chat_bot_provider.dart';

void showRoutingBottomSheet(BuildContext context, ChatBotProvider provider) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final bg = isDark ? context.tokens.surfaceContainer : context.tokens.surface;
  final borderCol = context.tokens.divider;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    isScrollControlled: true,
    builder: (modalContext) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
          border: Border(
            top: BorderSide(color: borderCol, width: 1),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '원하시는 작업을 선택해주세요',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.tokens.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(modalContext),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: context.tokens.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // TTS Option Card
              InkWell(
                onTap: () {
                  Navigator.pop(modalContext);
                  provider.updateChatbotMode('tts');
                  provider.sendMessage('음성(TTS) 생성을 진행하고 싶어');
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? StudioColors.ttsPink.withValues(alpha: 0.4)
                          : StudioColors.ttsPink.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              StudioColors.purpleLight.withValues(alpha: 0.15),
                              StudioColors.ttsPink.withValues(alpha: 0.15)
                            ]
                          : [
                              StudioColors.purpleLight.withValues(alpha: 0.05),
                              StudioColors.ttsPink.withValues(alpha: 0.05)
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              StudioColors.purpleLight,
                              StudioColors.ttsPink
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.audiotrack_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🎙️ AI 음성(TTS) 생성 요청',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: context.tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '자연스러운 AI 목소리로 음성을 생성하고 튜닝합니다.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: context.tokens.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: context.tokens.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Video Option Card
              InkWell(
                onTap: () {
                  Navigator.pop(modalContext);
                  provider.updateChatbotMode('video');
                  provider.sendMessage('비디오(영상) 생성을 진행하고 싶어');
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? StudioColors.videoCyan.withValues(alpha: 0.4)
                          : StudioColors.videoCyan.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              StudioColors.videoBlue.withValues(alpha: 0.15),
                              StudioColors.videoCyan.withValues(alpha: 0.15)
                            ]
                          : [
                              StudioColors.videoBlue.withValues(alpha: 0.05),
                              StudioColors.videoCyan.withValues(alpha: 0.05)
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              StudioColors.videoBlue,
                              StudioColors.videoCyan
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.videocam_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🎬 AI 비디오 생성 요청',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: context.tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '텍스트 시나리오를 바탕으로 멋진 비디오 씬을 기획합니다.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: context.tokens.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: context.tokens.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
