// ============================================================================
// lib/features/more/presentation/sections/backup_section.dart
// ============================================================================
//
// [역할]
// 백업 섹션 위젯.
// ============================================================================

import 'package:flutter/material.dart';

import 'package:parrokit/core/infrastructure/services/backup_service.dart';
import '../widgets/card_container.dart';
import '../widgets/hairline_divider.dart';
import '../widgets/nav_tile.dart';
import '../widgets/section_title.dart';
import '../widgets/backup_progress_dialog.dart';

/// 백업 섹션.
class BackupSection extends StatelessWidget {
  const BackupSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('백업'),
        const SizedBox(height: 10),
        CardContainer(
          child: Column(
            children: [
              NavTile(
                icon: Icons.settings_backup_restore_rounded,
                title: '불러오기',
                onTap: () async {
                  await showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => BackupProgressDialog(
                      type: BackupDialogType.restore,
                      onStart: (onProgress) => BackupService.instance
                          .restoreBackup(onProgress: onProgress),
                    ),
                  );
                },
              ),
              const HairlineDivider(),
              NavTile(
                icon: Icons.save_alt_rounded,
                title: '저장하기',
                onTap: () async {
                  await showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => BackupProgressDialog(
                      type: BackupDialogType.backup,
                      onStart: (onProgress) => BackupService.instance
                          .createBackup(onProgress: onProgress),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
