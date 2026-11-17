// ============================================================================
// lib/features/more/presentation/sections/app_settings_section.dart
// ============================================================================
//
// [역할]
// 앱 설정 섹션 위젯 (테마 등).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:parrokit/core/state/provider/theme_provider.dart';
import '../widgets/practice_reminder_tile.dart';
import '../widgets/theme_tile.dart';

/// 앱 설정 섹션.
class AppSettingsSection extends StatelessWidget {
  const AppSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    // 카드 테두리·그림자·여백 없이 목록으로 붙인다.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          ThemeTile(
            value: context.watch<ThemeProvider>().themeMode,
            onChanged: (mode) {
              context.read<ThemeProvider>().setTheme(mode);
            },
          ),
          const PracticeReminderTile(),
          // '새 클립 화면' 스위치는 없앴다(사용자 결정 2026-11-17).
          // 클립 탭은 새 화면만 쓴다.
        ],
      ),
    );
  }
}
