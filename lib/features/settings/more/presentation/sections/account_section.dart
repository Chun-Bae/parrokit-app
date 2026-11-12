// ============================================================================
// lib/features/more/presentation/sections/account_section.dart
// ============================================================================
//
// [역할]
// 더보기 맨 위 프로필 한 줄과 이메일 인증 안내.
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'email_verification_section.dart';
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.currentUser;
    final isEmailVerified =
        FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    final needsVerification = user?.email != null && !isEmailVerified;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 프로필 한 줄. 전에는 가운데 정렬 큰 카드에 사진·이름·인증·잔액
        // 배지가 세로로 쌓여 있었다. 잔액은 바로 아래 지갑 카드로 옮겼다.
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () => context.pushNamed(AppRoutes.profileEdit),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.surfaceContainerHighest,
                    ),
                    child: ClipOval(
                      child: user?.photoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: user!.photoUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Shimmer.fromColors(
                                baseColor: context.tokens.skeleton,
                                highlightColor:
                                    context.tokens.skeletonHighlight,
                                child: Container(color: Colors.white),
                              ),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.person, size: 28),
                            )
                          : const Icon(Icons.person, size: 28),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? user?.email ?? '-',
                          style: context.texts.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (user?.email != null)
                          _StatusBadge(
                            icon: needsVerification
                                ? Icons.error_outline_rounded
                                : Icons.verified_rounded,
                            label: needsVerification ? '이메일 미인증' : '이메일 인증됨',
                            color: needsVerification
                                ? cs.error
                                : context.tokens.primary,
                            backgroundColor: (needsVerification
                                    ? cs.error
                                    : context.tokens.primary)
                                .withValues(alpha: 0.1),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '프로필 편집',
                    style: context.texts.labelMedium
                        .copyWith(color: cs.onSurfaceVariant),
                  ),
                  Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),

        // ── 이메일 미인증 경고
        if (needsVerification) ...[
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

  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}
