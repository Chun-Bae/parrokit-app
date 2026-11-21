// '자막 넣어 내보내기' 화면(5차, 사용자 요청).
//
// 백업과 달리 앱 밖으로 가지고 나가는 길이다. 구우면 자막을 못 고치고
// 시간이 걸리므로, 무엇을 하는지와 얼마나 걸리는지 먼저 알리고 시작한다.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';
import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/features/collection/clip/export/data/subtitle_burn_service.dart';
import 'package:parrokit/features/collection/clip/export/domain/subtitle_burn.dart';

const String subtitleExportTitle = '자막 넣어 내보내기';
const String subtitleExportBody =
    '원문과 해석을 영상에 넣어 새 파일을 만들어요. 자막이 박히므로 나중에 고칠 수 없어요.';
const String subtitleExportStartLabel = '만들기';
const String subtitleExportCancelLabel = '그만두기';
const String subtitleExportShareLabel = '공유하기';
const String subtitleExportRunningText = '영상을 만드는 중이에요. 앱을 닫지 말아 주세요.';
const String subtitleExportDoneText = '다 됐어요. 공유하거나 사진 앱에 저장할 수 있어요.';
const String subtitleExportFailedText = '만들지 못했어요.';

Future<void> showSubtitleExportSheet(
  BuildContext context, {
  required String videoPath,
  required List<Segment> segments,
  required String clipTitle,
  required Duration videoLength,
  SubtitleBurnService? service,
}) {
  return showAppSheet<void>(
    context: context,
    dismissible: false,
    builder: (_) => SubtitleExportSheet(
      videoPath: videoPath,
      segments: segments,
      clipTitle: clipTitle,
      videoLength: videoLength,
      service: service,
    ),
  );
}

class SubtitleExportSheet extends StatefulWidget {
  const SubtitleExportSheet({
    super.key,
    required this.videoPath,
    required this.segments,
    required this.clipTitle,
    required this.videoLength,
    this.service,
  });

  final String videoPath;
  final List<Segment> segments;
  final String clipTitle;
  final Duration videoLength;

  /// 테스트에서 가짜를 넣기 위한 자리.
  final SubtitleBurnService? service;

  @override
  State<SubtitleExportSheet> createState() => SubtitleExportSheetState();
}

enum SubtitleExportStage { ready, running, done, failed }

class SubtitleExportSheetState extends State<SubtitleExportSheet> {
  late final SubtitleBurnService service =
      widget.service ?? SubtitleBurnService();
  SubtitleExportStage stage = SubtitleExportStage.ready;
  double progress = 0;
  String? resultPath;
  String? message;

  Future<void> start() async {
    setState(() {
      stage = SubtitleExportStage.running;
      progress = 0;
      message = null;
    });
    final result = await service.burn(
      videoPath: widget.videoPath,
      segments: widget.segments,
      clipTitle: widget.clipTitle,
      videoLength: widget.videoLength,
      onProgress: (value) {
        if (mounted) setState(() => progress = value);
      },
    );
    if (!mounted) return;
    if (result.canceled) {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
      return;
    }
    setState(() {
      stage = result.isSuccess
          ? SubtitleExportStage.done
          : SubtitleExportStage.failed;
      resultPath = result.path;
      message = result.message;
    });
  }

  /// 그만두라고 눌렀는지. dispose가 또 멈추라고 하지 않게 들고 있는다.
  bool stopped = false;

  Future<void> cancel() async {
    stopped = true;
    await service.cancel();
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  Future<void> share() async {
    final path = resultPath;
    if (path == null) return;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: widget.clipTitle),
    );
  }

  String get bodyText => switch (stage) {
        SubtitleExportStage.ready =>
          '$subtitleExportBody ${burnTimeHint(widget.videoLength)}',
        SubtitleExportStage.running => subtitleExportRunningText,
        SubtitleExportStage.done => subtitleExportDoneText,
        SubtitleExportStage.failed => message ?? subtitleExportFailedText,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(subtitleExportTitle, style: context.texts.titleLarge),
            const SizedBox(height: 6),
            Text(
              bodyText,
              key: const ValueKey('subtitle-export-body'),
              style: context.texts.bodyReading
                  .copyWith(color: cs.onSurfaceVariant),
            ),
            if (stage == SubtitleExportStage.running) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                key: const ValueKey('subtitle-export-progress'),
                value: progress == 0 ? null : progress,
                minHeight: 8,
              ),
              const SizedBox(height: 6),
              Text('${(progress * 100).round()}%',
                  style: context.texts.labelSmall
                      .copyWith(color: cs.onSurfaceVariant)),
            ],
            const SizedBox(height: 20),
            if (stage == SubtitleExportStage.ready)
              FilledButton(
                key: const ValueKey('subtitle-export-start'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                onPressed: start,
                child: const Text(subtitleExportStartLabel),
              )
            else if (stage == SubtitleExportStage.running)
              OutlinedButton(
                key: const ValueKey('subtitle-export-cancel'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                onPressed: cancel,
                child: const Text(subtitleExportCancelLabel),
              )
            else if (stage == SubtitleExportStage.done)
              FilledButton(
                key: const ValueKey('subtitle-export-share'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                onPressed: share,
                child: const Text(subtitleExportShareLabel),
              )
            else
              FilledButton(
                key: const ValueKey('subtitle-export-retry'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                onPressed: start,
                child: const Text('다시 시도'),
              ),
            if (stage != SubtitleExportStage.running) ...[
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('subtitle-export-close'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('닫기'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // 창을 닫으면 굽던 것도 멈춘다. 만든 파일은 임시 폴더에 남아 다음에 정리된다.
    if (stage == SubtitleExportStage.running && !stopped) {
      unawaited(service.cancel());
    }
    super.dispose();
  }
}

/// 영상 파일이 있는지 미리 본다. 없으면 시트를 띄우지 않는다.
Future<bool> videoExists(String path) => File(path).exists();
