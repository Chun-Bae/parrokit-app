import 'package:flutter/material.dart';
import 'package:parrokit/features/content-studio/shared/studio_colors.dart';
import 'chat_bot_sheet.dart';

class ChatBotFab extends StatefulWidget {
  const ChatBotFab({super.key, this.onTriggerAction});

  final void Function(int tabIndex, Map<String, dynamic>? actionData)?
      onTriggerAction;

  @override
  State<ChatBotFab> createState() => _ChatBotFabState();
}

class _ChatBotFabState extends State<ChatBotFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AI스러운 그라데이션 및 효과
    final gradientColors = [
      StudioColors.generalPurple, // Purple
      StudioColors.videoBlue, // Blue
    ];

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: gradientColors[0]
                      .withValues(alpha: 0.3 * _controller.value),
                  blurRadius: 16,
                  spreadRadius: 4 * _controller.value,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => showChatBotSheet(
                  context,
                  onTriggerAction: widget.onTriggerAction,
                ),
                child: Ink(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
