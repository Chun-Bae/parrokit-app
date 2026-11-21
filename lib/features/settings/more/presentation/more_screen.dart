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

import 'package:parrokit/features/settings/more/presentation/sections/ads_removal_section.dart';
import 'package:parrokit/features/settings/more/presentation/sections/parrot_topup_section.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/app/router/tab_reselect.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'sections/account_section.dart';
import 'sections/app_settings_section.dart';
import 'sections/data_section.dart';
import 'sections/delete_account_section.dart';
import 'sections/info_section.dart';
import 'sections/logout_section.dart';
import 'sections/assist_usage_section.dart';
import 'sections/wallet_section.dart';
import 'sections/subscription_section.dart';

/// 설정/더보기 화면.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    TabReselect.instance.addListener(_onTabReselected);
  }

  /// 더보기에서 더보기 탭을 다시 누르면 맨 위로.
  void _onTabReselected() {
    if (TabReselect.instance.lastIndex != 4) return;
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    TabReselect.instance.removeListener(_onTabReselected);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      backgroundColor: t.colorScheme.surface,
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
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
            // 잔액 바로 아래에 하루 한도를 둔다(사용자 요청). 전에는 단어나
            // 문장 창을 열어야만 보여서, 다 쓴 뒤에야 알게 됐다.
            const AssistUsageSection(),
            // 칸 이름이 '구독'인데 그 안에 '구독'과 '광고 제거'가 함께
            // 있어 겹쳐 보였다. 파는 것을 묶는 칸이므로 '상품'으로 둔다(5차 465).
            const _GroupLabel('상품'),
            const SubscriptionSection(),
            // 광고 제거는 한 번 사는 것이라 구독과 다른 줄로 둔다(5차 463).
            const AdsRemovalSection(),
            // 패롯도 파는 것이라 상품 칸에 둔다(5차 466). 지갑 카드의
            // '충전' 버튼은 그대로 둔다 - 잔액을 보고 바로 누르는 자리다.
            const ParrotTopupSection(),
            const _GroupLabel('데이터'),
            const DataSection(),
            const _GroupLabel('앱'),
            const AppSettingsSection(),
            const _GroupLabel('정보'),
            const InfoSection(),
            // 네이티브 플레이어 **시험 화면**은 출시 빌드에 안 보인다(5차 1단계).
            // 스위치는 '앱' 칸으로 옮겼다 — 테스트 배포는 release 빌드라
            // 이 칸이 통째로 숨겨져서, 켜 볼 길이 없었다.
            if (!kReleaseMode) ...[
              const _GroupLabel('개발'),
              TextButton(
                key: const ValueKey('dev-native-player'),
                onPressed: () => context.push(AppRoutes.devNativePlayerPath),
                child: const Text('네이티브 플레이어 시험'),
              ),
            ],
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
