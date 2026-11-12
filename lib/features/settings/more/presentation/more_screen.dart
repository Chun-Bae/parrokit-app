// ============================================================================
// lib/features/settings/more/presentation/more_screen.dart
// ============================================================================
//
// 더보기 화면.
//
// 위에서부터 프로필 한 줄, 지갑(패롯·크래커와 광고·환전), 데이터(백업·복원·
// 보관 영상·임시 파일 + 저장 용량), 앱 설정, 정보, 맨 아래 로그아웃·회원탈퇴.
// 전에는 섹션마다 큰 제목과 설명문이 붙어 글이 많았다. 기능은 그대로 두고
// 제목은 작은 머리말로, 설명은 ? 버튼과 시트로 옮겼다. 목록은 카드와
// 구분선 없이 붙이고, 묶음은 여백과 머리말로만 나눈다.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'sections/account_section.dart';
import 'sections/app_settings_section.dart';
import 'sections/data_section.dart';
import 'sections/delete_account_section.dart';
import 'sections/info_section.dart';
import 'sections/logout_section.dart';
import 'sections/wallet_section.dart';

/// 설정/더보기 화면.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      backgroundColor: t.colorScheme.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ).copyWith(bottom: AppSpacing.xxl),
          children: [
            Text('더보기', style: context.texts.headlineMedium),
            const SizedBox(height: AppSpacing.md),
            const AccountSection(),
            const SizedBox(height: AppSpacing.md),
            const WalletSection(),
            const _GroupLabel('데이터'),
            const DataSection(),
            const _GroupLabel('앱'),
            const AppSettingsSection(),
            const _GroupLabel('정보'),
            const InfoSection(),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const LogoutSection(),
                Text('·',
                    style: context.texts.labelMedium
                        .copyWith(color: t.colorScheme.onSurfaceVariant)),
                const DeleteAccountSection(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 묶음 위의 작은 머리말. 카드도 구분선도 없이 여백과 머리말로만 묶음을
/// 나눈다.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xl),
          child: Text(
            text,
            style: context.texts.labelLarge.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
