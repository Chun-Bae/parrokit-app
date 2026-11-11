import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

/// 비디오 플레이어 전용 컨트롤 바.
/// [-3초] [처음으로] [재생/일시정지] [+3초] 버튼으로 구성된다.
class VideoControlsBar extends StatefulWidget {
  const VideoControlsBar({
    super.key,
    required this.controller,
    required this.onPlayInline,
    required this.onToggleInline,
    required this.onStopInline,
    this.onZoomIn,
    this.onZoomOut,
    this.onToggleSettings,
    this.isSettingsExpanded = false,
    this.skipSeconds = 3.0,
  });

  final VideoPlayerController? controller;
  final VoidCallback onPlayInline;
  final VoidCallback onToggleInline;
  final VoidCallback onStopInline;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onToggleSettings;
  final bool isSettingsExpanded;
  final double skipSeconds;

  @override
  State<VideoControlsBar> createState() => _VideoControlsBarState();
}

class _VideoControlsBarState extends State<VideoControlsBar> {
  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onControllerUpdate);
  }

  @override
  void didUpdateWidget(VideoControlsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerUpdate);
      widget.controller?.addListener(_onControllerUpdate);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  bool get _isInitialized =>
      widget.controller != null && widget.controller!.value.isInitialized;

  void _seekRelative(Duration delta) {
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) return;
    final next = c.value.position + delta;
    final clamped = next.isNegative
        ? Duration.zero
        : next > c.value.duration
            ? c.value.duration
            : next;
    c.seekTo(clamped);
  }

  void _seekToStart() {
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) return;
    c.seekTo(Duration.zero);
  }

  IconData get _playIcon {
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) return Icons.play_arrow_rounded;
    if (c.value.isPlaying) return Icons.pause_rounded;
    if (c.value.position >= c.value.duration) return Icons.replay_rounded;
    return Icons.play_arrow_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor =
        isDark ? cs.surfaceContainerHigh : cs.surface; // 화이트 모드에서는 기본 배경색 사용

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 줌 버튼 (좌측)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ControlButton(
                icon: Icons.remove_rounded,
                label: '축소',
                onTap: widget.onZoomOut,
                cs: cs,
                size: 22,
              ),
              const SizedBox(width: 8),
              _ControlButton(
                icon: Icons.add_rounded,
                label: '확대',
                onTap: widget.onZoomIn,
                cs: cs,
                size: 22,
              ),
            ],
          ),
          const SizedBox(width: 12),
          Container(
            height: 32,
            width: 1,
            color: cs.onSurface.withValues(alpha: 0.1),
          ),
          const SizedBox(width: 12),

          // -n초
          _ControlButton(
            icon: Icons.replay_5_rounded,
            label:
                '${widget.skipSeconds.toStringAsFixed(widget.skipSeconds == widget.skipSeconds.truncateToDouble() ? 0 : 1)}초 전',
            onTap: _isInitialized
                ? () => _seekRelative(Duration(
                    milliseconds: (widget.skipSeconds * 1000).toInt() * -1))
                : null,
            cs: cs,
            size: 26,
          ),
          const SizedBox(width: 8),

          // 재생 / 일시정지 (강조)
          _PlayButton(
            icon: _playIcon,
            onTap: () {
              if (!_isInitialized) {
                widget.onPlayInline();
              } else {
                widget.onToggleInline();
              }
            },
            cs: cs,
          ),
          const SizedBox(width: 8),

          // +n초
          _ControlButton(
            icon: Icons.forward_5_rounded,
            label:
                '${widget.skipSeconds.toStringAsFixed(widget.skipSeconds == widget.skipSeconds.truncateToDouble() ? 0 : 1)}초 후',
            onTap: _isInitialized
                ? () => _seekRelative(
                    Duration(milliseconds: (widget.skipSeconds * 1000).toInt()))
                : null,
            cs: cs,
            size: 26,
          ),
          const SizedBox(width: 12),

          // 분리선 및 우측 버튼 영역 (처음으로, 설정)
          Container(
            height: 32,
            width: 1,
            color: cs.onSurface.withValues(alpha: 0.1),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ControlButton(
                icon: Icons.skip_previous_rounded,
                label: '처음으로',
                onTap: _isInitialized ? _seekToStart : null,
                cs: cs,
                size: 24,
              ),
              const SizedBox(width: 8),
              _ControlButton(
                icon: Icons.tune_rounded,
                label: '설정',
                onTap: widget.onToggleSettings,
                cs: cs,
                size: 24,
                isActive: widget.isSettingsExpanded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.icon,
    required this.onTap,
    required this.cs,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return _BouncingButton(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              cs.primary,
              cs.primary.withValues(alpha: 0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: cs.onPrimary, size: 30),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.cs,
    this.size = 24,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final ColorScheme cs;
  final double size;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BouncingButton(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: size,
              color: enabled
                  ? (isActive ? cs.primary : cs.onSurfaceVariant)
                  : cs.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: context.texts.labelSmall.copyWith(
              color: enabled
                  ? (isActive ? cs.primary : cs.onSurfaceVariant)
                  : cs.onSurface.withValues(alpha: 0.3)),
        ),
      ],
    );
  }
}

class _BouncingButton extends StatefulWidget {
  const _BouncingButton({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<_BouncingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.92)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap != null ? (_) => _controller.forward() : null,
      onTapUp: widget.onTap != null ? (_) => _controller.reverse() : null,
      onTapCancel: widget.onTap != null ? () => _controller.reverse() : null,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}
