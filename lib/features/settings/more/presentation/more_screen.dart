// ============================================================================
// lib/features/more/presentation/more_screen.dart
// ============================================================================
//
// [역할]
// 설정/더보기 화면.
//
// [레이어]
// Presentation Layer - View
//
// [구성 요소]
// - AccountSection: 계정 섹션
// - PlayerSettingsSection: 플레이어 설정
// - ShortsSettingsSection: 쇼츠 설정
// - AppSettingsSection: 앱 설정
// - PaymentSection: 결제 섹션
// - BackupSection: 백업 섹션
// - InfoSection: 정보 섹션
// ============================================================================

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'sections/account_section.dart';
import 'sections/ad_reward_section.dart';
import 'sections/exchange_section.dart';
import 'sections/app_settings_section.dart';
import 'sections/backup_section.dart';
import 'sections/cache_section.dart';
import 'sections/logout_section.dart';
import 'sections/delete_account_section.dart';
import 'sections/info_section.dart';
import 'sections/remote_storage_section.dart';
import 'sections/storage_section.dart';

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
            const SizedBox(height: AppSpacing.md),

            // 계정
            const AccountSection(),
            const SizedBox(height: AppSpacing.sectionGap),

            // 광고 보기
            const AdRewardSection(),
            const SizedBox(height: AppSpacing.sectionGap),

            // 환전소
            const ExchangeSection(),
            const SizedBox(height: AppSpacing.sectionGap),

            // // 결제 (광고 제거 + 코인 충전 + 구매 내역)
            // const PaymentSection(),
            // const SizedBox(height: AppSpacing.sectionGap),

            // 앱 설정
            const AppSettingsSection(),
            const SizedBox(height: AppSpacing.sectionGap),

            // 백업
            const BackupSection(),
            const SizedBox(height: AppSpacing.sectionGap),

            // 저장 공간
            const StorageSection(),
            const SizedBox(height: AppSpacing.sectionGap),

            // 원격 저장소
            const RemoteStorageSection(),
            const SizedBox(height: AppSpacing.sectionGap),

            // 캐시 관리
            const CacheSection(),
            const SizedBox(height: AppSpacing.sectionGap),

            // 정보
            const InfoSection(),
            const SizedBox(height: AppSpacing.sectionGap),

            // 로그아웃
            const LogoutSection(),

            // 회원탈퇴
            const DeleteAccountSection(),
          ],
        ),
      ),
    );
  }
}
