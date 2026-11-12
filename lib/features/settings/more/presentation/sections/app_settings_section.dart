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
        ],
      ),
    );
  }
}
