// ============================================================================
// lib/features/more/presentation/sections/account_section.dart
// ============================================================================
//
// [역할]
// 계정 섹션 위젯. 계정 정보 + 코인 충전 + 로그아웃.
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'email_verification_section.dart';
import '../widgets/card_container.dart';
import '../widgets/section_title.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

/// 계정 섹션.
class AccountSection extends StatelessWidget {
  const AccountSection({super.key});

  Future<void> _checkEmailVerification(BuildContext context) async {
    final userProvider = context.read<UserProvider>();
    try {
      await userProvider.reloadFirebaseUser();
      final verified = await userProvider.isEmailVerified();
      if (!context.mounted) return;
      showToast(verified ? '이메일 인증이 완료되었습니다.' : '아직 이메일 인증이 완료되지 않았습니다.');
    } catch (e) {
      if (!context.mounted) return;
      showToast('이메일 인증 상태 확인 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> _resendVerificationEmail(BuildContext context) async {
    final userProvider = context.read<UserProvider>();
    try {
      await userProvider.sendEmailVerification();
      if (!context.mounted) return;
      showToast('인증 메일을 전송했습니다. 메일이 보이지 않는다면 스팸 메일함도 확인해 주세요.');
    } catch (e) {
      if (!context.mounted) return;
      showToast('인증 메일 재전송 중 오류가 발생했습니다: $e');
    }
  }

  void _showCurrencyInfo(
      BuildContext context, String title, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.currentUser;
    final isEmailVerified =
        FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('계정'),
        const SizedBox(height: 10),

        // ── 계정 카드
        CardContainer(
          padding: const EdgeInsets.all(20),
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.surfaceContainerHighest,
                      ),
                      child: ClipOval(
                        child: user?.photoUrl != null
                            ? CachedNetworkImage(
                                imageUrl: user!.photoUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    Shimmer.fromColors(
                                  baseColor: context.tokens.skeleton,
                                  highlightColor:
                                      context.tokens.skeletonHighlight,
                                  child: Container(color: Colors.white),
                                ),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.person, size: 40),
                              )
                            : const Icon(Icons.person, size: 40),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user?.displayName ?? user?.email ?? '-',
                      style: context.texts.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        if (user?.email != null && !isEmailVerified)
                          _StatusBadge(
                            icon: Icons.error_outline_rounded,
                            label: '이메일 미인증',
                            color: cs.error,
                            backgroundColor: cs.error.withValues(alpha: 0.1),
                          )
                        else if (user?.email != null)
                          _StatusBadge(
                            icon: Icons.verified_rounded,
                            label: '이메일 인증됨',
                            color: context.tokens.primary,
                            backgroundColor:
                                context.tokens.primary.withValues(alpha: 0.1),
                          ),
                        // 패롯 뱃지
                        _StatusBadge(
                          icon: Icons.auto_awesome_rounded,
                          label: '${_count.format(user?.parrots ?? 0)} 패롯',
                          color: AppColors.parrotCurrency,
                          backgroundColor:
                              AppColors.parrotCurrency.withValues(alpha: 0.1),
                          onHelpTap: () => _showCurrencyInfo(
                            context,
                            '패롯(Parrot)이란?',
                            '앱 안에서 쓰는 프리미엄 재화입니다.\n광고를 보거나 충전해서 얻고, 자막·음성·영상을 만들 때 씁니다.',
                          ),
                        ),
                        // 크래커 뱃지
                        _StatusBadge(
                          icon: Icons.cookie_rounded,
                          label: '${_count.format(user?.crackers ?? 0)} 크래커',
                          color: AppColors.crackerCurrency,
                          backgroundColor:
                              AppColors.crackerCurrency.withValues(alpha: 0.1),
                          onHelpTap: () => _showCurrencyInfo(
                            context,
                            '크래커(Cracker)란?',
                            '커뮤니티에서 쓰는 활동 재화입니다.\n질문을 올릴 때 보상으로 걸 수 있고, 내 답변이 채택되면 받습니다.',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 프로필 통합 편집 버튼 (우측 상단)
              Positioned(
                top: -8,
                right: -8,
                child: IconButton(
                  icon: Icon(
                    Icons.edit_rounded,
                    size: 20,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                  onPressed: () => context.pushNamed(AppRoutes.profileEdit),
                ),
              ),
            ],
          ),
        ),

        // ── 이메일 미인증 경고
        if (user?.email != null && !isEmailVerified) ...[
          const SizedBox(height: 12),
          EmailVerificationSection(
            isLoading: userProvider.isLoading,
            onCheckVerification: () => _checkEmailVerification(context),
            onResendEmail: () => _resendVerificationEmail(context),
          ),
        ],
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color backgroundColor;
  final VoidCallback? onHelpTap;

  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.backgroundColor,
    this.onHelpTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget badgeContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
          ),
          if (onHelpTap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.help_outline_rounded,
                size: 14, color: color.withValues(alpha: 0.8)),
          ]
        ],
      ),
    );

    if (onHelpTap != null) {
      return InkWell(
        onTap: onHelpTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: badgeContent,
      );
    }

    return badgeContent;
  }
}

/// 잔액 표시용. 전에는 '45900 크래커'처럼 쉼표가 없었고, 바로 아래
/// 환전소 설명은 '1,000 크래커'라 같은 화면에서 숫자 모양이 달랐다.
final _count = NumberFormat.decimalPattern('ko');
