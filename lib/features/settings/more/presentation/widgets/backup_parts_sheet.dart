// 백업·불러오기에서 무엇을 다룰지 고르는 시트(5차 345, 사용자 요청).
//
// 전에는 백업이 클립과 자막만 담았는데 이름이 그냥 '백업'이라 문장까지 담기는
// 줄 알기 쉬웠다. 이제 문장·단어·클립을 골라서 담고 불러온다.
//
// 되돌리는 쪽 이름은 '불러오기'다(5차 487). 여는 단추와 진행 창은
// '불러오기'인데 이 시트만 '되돌리기'라, 한 흐름이 두 이름으로
// 불렸다.

import 'package:flutter/material.dart';

import 'package:parrokit/core/content/study_data_transfer.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';

/// 고르는 시트를 띄운다. 취소하면 null.
Future<BackupParts?> showBackupPartsSheet(
  BuildContext context, {
  required bool restoring,
  BackupParts initial = const BackupParts.all(),
}) =>
    showAppSheet<BackupParts>(
      context: context,
      builder: (_) => BackupPartsSheet(restoring: restoring, initial: initial),
    );

class BackupPartsSheet extends StatefulWidget {
  const BackupPartsSheet({
    super.key,
    required this.restoring,
    this.initial = const BackupParts.all(),
  });

  /// true면 불러오기, false면 백업.
  final bool restoring;

  /// 처음 켜져 있을 것. 클립 화면에서 열면 클립만 켜 둔다(5차 349).
  final BackupParts initial;

  @override
  State<BackupPartsSheet> createState() => _BackupPartsSheetState();
}

class _BackupPartsSheetState extends State<BackupPartsSheet> {
  late BackupParts parts = widget.initial;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final restoring = widget.restoring;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(restoring ? '무엇을 불러올까요?' : '무엇을 백업할까요?',
                style: context.texts.titleLarge
                    .copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
                restoring
                    ? '고른 것만 백업 파일에서 불러와요. 파일에 없는 것은 건너뛰어요.'
                    : '고른 것만 한 파일에 담아요.',
                style: context.texts.bodySmall
                    .copyWith(color: colors.onSurfaceVariant)),
            const SizedBox(height: 10),
            _Row(
              keyValue: const ValueKey('backup-part-sentences'),
              icon: Icons.format_quote_rounded,
              title: '내 문장',
              subtitle: '문장과 뜻·발음. 연습 기록은 담지 않아요',
              value: parts.sentences,
              onChanged: (v) => setState(() => parts = parts.copyWith(
                    sentences: v,
                  )),
            ),
            _Row(
              keyValue: const ValueKey('backup-part-words'),
              icon: Icons.spellcheck_rounded,
              title: '내 단어',
              subtitle: '단어와 뜻·유의어·예문. 복습 진도는 담지 않아요',
              value: parts.words,
              onChanged: (v) =>
                  setState(() => parts = parts.copyWith(words: v)),
            ),
            _Row(
              keyValue: const ValueKey('backup-part-clips'),
              icon: Icons.smart_display_rounded,
              title: '클립과 자막',
              subtitle: restoring ? '불러온 뒤 앱이 다시 켜져요' : '영상 파일까지 담아서 파일이 커요',
              value: parts.clips,
              onChanged: (v) =>
                  setState(() => parts = parts.copyWith(clips: v)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('backup-parts-confirm'),
                onPressed:
                    parts.isEmpty ? null : () => Navigator.pop(context, parts),
                child: Text(restoring ? '불러오기' : '백업하기'),
              ),
            ),
            if (parts.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(backupNoPartsMessage,
                    key: const ValueKey('backup-parts-blocked-reason'),
                    style: context.texts.bodySmall
                        .copyWith(color: colors.onSurfaceVariant)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.keyValue,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final Key keyValue;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
        key: keyValue,
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.trailing,
        secondary: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
      );
}
