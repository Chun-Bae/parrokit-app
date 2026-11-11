import 'dart:async';

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/core/infrastructure/services/ad_service.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 광고 보고 코인 받기 섹션.
///
/// 자체적으로 광고 로드/시청/보상 처리. more_screen에서 독립적으로 사용.
class AdRewardSection extends StatefulWidget {
  const AdRewardSection({super.key});

  @override
  State<AdRewardSection> createState() => _AdRewardSectionState();
}

class _AdRewardSectionState extends State<AdRewardSection> {
  static const _cooldown = Duration(minutes: 3);
  static const _prefKey = 'ad_reward_last_time';

  Duration? _remaining;
  StreamSubscription<int>? _timerSub;

  @override
  void initState() {
    super.initState();
    AdService().loadRewardedAd();
    _initCooldown();
  }

  @override
  void dispose() {
    _timerSub?.cancel();
    super.dispose();
  }

  Future<void> _initCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_prefKey);
    if (lastMs == null) return;
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastMs;
    final remainingMs = _cooldown.inMilliseconds - elapsed;
    if (remainingMs > 0) {
      _startTimer(Duration(milliseconds: remainingMs));
    }
  }

  void _startTimer(Duration initial) {
    _timerSub?.cancel();
    setState(() => _remaining = initial);
    _timerSub =
        Stream.periodic(const Duration(seconds: 1), (i) => i).listen((_) {
      if (!mounted) return;
      final next = _remaining! - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        setState(() => _remaining = null);
        _timerSub?.cancel();
      } else {
        setState(() => _remaining = next);
      }
    });
  }

  void _onWatchAd() {
    // 광고는 전체 화면으로 30초쯤 돈다. 그 사이에 이 섹션이 사라질 수 있으니
    // Provider는 미리 잡아 둔다.
    final userProvider = context.read<UserProvider>();

    AdService().showRewardedAd(
      onRewarded: (coins) async {
        if (coins == null) {
          showToast('광고가 아직 준비 중이에요. 잠시 후 다시 시도해 주세요.');
          return;
        }

        // 보상 지급에 `if (!mounted) return;`이 걸려 있었다. 사용자가 광고를
        // 끝까지 봤는데 그 사이 화면을 떠났으면 코인을 못 받았다. 지급과
        // 쿨다운 기록은 화면 수명과 상관없이 한다.
        try {
          await userProvider.addCoins(coins);
        } catch (e) {
          AppLogger.e('[AdReward] 광고 보상 지급 실패 coins=$coins', error: e);
          showToast('광고 보상 지급에 실패했어요. 잠시 후 다시 시도해 주세요.');
          return;
        }

        showToast('코인 $coins개를 받았어요!');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_prefKey, DateTime.now().millisecondsSinceEpoch);

        // 타이머는 화면이 살아 있을 때만 의미가 있다.
        if (mounted) _startTimer(_cooldown);
      },
    );
  }

  String _formatRemaining(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    if (minutes > 0) {
      return '$minutes분 ${seconds.toString().padLeft(2, '0')}초 후 가능';
    }
    return '$seconds초 후 가능';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isCooldown = _remaining != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '패롯 받기',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '광고를 시청하면 패롯 ${AdService.rewardCoins}개를 받을 수 있어요. '
          '패롯이 있으면 자막 생성을 이용할 수 있어요.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ValueListenableBuilder<bool>(
            valueListenable: AdService().isRewardedAdReadyListenable,
            builder: (context, isAdReady, _) {
              return OutlinedButton.icon(
                onPressed: (isCooldown || !isAdReady) ? null : _onWatchAd,
                icon: isCooldown
                    ? const Icon(Icons.timer_outlined, size: 18)
                    : !isAdReady
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_circle_outline_rounded,
                            size: 18),
                label: Text(
                  isCooldown
                      ? _formatRemaining(_remaining!)
                      : !isAdReady
                          ? '광고 준비 중...'
                          : '광고 보고 패롯 ${AdService.rewardCoins}개 받기',
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
