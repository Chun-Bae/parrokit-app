// 예전에 Google Drive에 올린 클립이 남아 있을 때 보관함 맨 위에 뜨는 안내.
//
// Drive 저장은 더 쓰지 않는다(5차). 새로 올리는 길은 이미 막았고, 남은
// 클립은 기기로 가져오면 계속 볼 수 있다. 가져오면 Drive에 있던 파일은
// 지워지므로 그 사실을 먼저 적고 한 번 더 묻는다.

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

const String driveNoticeTitle = 'Google Drive 저장은 이제 쓰지 않아요';

String driveNoticeBody(int count) =>
    '여기 있는 클립 $count개를 기기로 가져오면 계속 볼 수 있어요.\n가져오면 Drive에 있던 파일은 지워져요.';

const String driveNoticeActionLabel = '기기로 가져오기';
const String driveNoticeConfirmTitle = '기기로 가져오기';
String driveNoticeConfirmBody(int count) =>
    '클립 $count개를 이 기기로 가져올까요?\n가져오면 Drive에 있던 파일은 지워져요.';
const String driveNoticeDoneToast = '기기로 가져왔어요.';
const String driveNoticeFailToast = '가져오지 못했어요. 잠시 뒤 다시 해 주세요.';

class DriveMigrationNotice extends StatelessWidget {
  const DriveMigrationNotice({
    super.key,
    required this.clipCount,
    required this.onImport,
    this.busy = false,
  });

  final int clipCount;
  final VoidCallback onImport;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (clipCount <= 0) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        key: const ValueKey('drive-migration-notice'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(driveNoticeTitle, style: context.texts.titleMedium),
            const SizedBox(height: 6),
            Text(
              driveNoticeBody(clipCount),
              style: context.texts.bodySmall
                  .copyWith(color: cs.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                key: const ValueKey('drive-migration-import'),
                onPressed: busy ? null : onImport,
                child: busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text(driveNoticeActionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
