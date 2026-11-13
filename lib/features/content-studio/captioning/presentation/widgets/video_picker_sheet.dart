import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';

void showVideoPickerSheet({
  required BuildContext context,
  required VoidCallback onPickFile,
  required VoidCallback onPickPhotos,
  String title = '영상 선택',
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  showAppSheet(
    context: context,
    builder: (context) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.file_open_rounded),
                title: Text(
                  '파일에서 선택',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onPickFile();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: Text(
                  '사진에서 선택',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onPickPhotos();
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
