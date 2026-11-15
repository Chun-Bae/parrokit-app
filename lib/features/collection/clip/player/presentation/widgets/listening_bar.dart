// 플레이어를 나와도 듣고 있을 때 아래에 붙는 줄(5차, 사용자 요청).
//
// 소리만 이어지므로 화면 어디에도 표시가 없으면 무엇이 울리는지, 어떻게
// 멈추는지 알 수 없다. 무엇을 듣는지와 멈춤·닫기를 한 줄로 둔다.

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/state/provider/background_playback_provider.dart';

const String listeningBarHint = '듣는 중';

class ListeningBar extends StatelessWidget {
  const ListeningBar({
    super.key,
    required this.playback,
    required this.onOpen,
    required this.onTogglePlay,
    required this.onClose,
  });

  final BackgroundPlayback playback;

  /// 줄을 누르면 그 클립으로 돌아간다.
  final VoidCallback onOpen;
  final VoidCallback onTogglePlay;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: InkWell(
          key: const ValueKey('listening-bar'),
          onTap: onOpen,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Ink(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: cs.outlineVariant),
            ),
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
            child: Row(children: [
              Icon(Icons.graphic_eq_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(listeningBarHint,
                        style: context.texts.labelSmall
                            .copyWith(color: cs.onSurfaceVariant)),
                    Text(
                      playback.title,
                      key: const ValueKey('listening-bar-title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700, color: cs.onSurface),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const ValueKey('listening-bar-toggle'),
                tooltip: playback.playing ? '멈춤' : '이어 듣기',
                onPressed: onTogglePlay,
                icon: Icon(playback.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded),
              ),
              IconButton(
                key: const ValueKey('listening-bar-close'),
                tooltip: '닫기',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
