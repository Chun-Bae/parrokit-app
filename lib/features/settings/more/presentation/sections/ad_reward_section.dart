import 'dart:async';

import 'package:flutter/material.dart';
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
    AdService().showRewardedAd(
      onRewarded: (coins) async {
        if (!mounted) return;
        if (coins < 0) {
          showToast('광고가 아직 준비 중이에요. 잠시 후 다시 시도해 주세요.');
          return;
        }
        context.read<UserProvider>().addCoins(coins);
        showToast('코인 $coins개를 받았어요!');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_prefKey, DateTime.now().millisecondsSinceEpoch);
        _startTimer(_cooldown);
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
          child: OutlinedButton.icon(
            onPressed: isCooldown ? null : _onWatchAd,
            icon: Icon(
              isCooldown
                  ? Icons.timer_outlined
                  : Icons.play_circle_outline_rounded,
              size: 18,
            ),
            label: Text(
              isCooldown
                  ? _formatRemaining(_remaining!)
                  : '광고 보고 패롯 ${AdService.rewardCoins}개 받기',
            ),
          ),
        ),
      ],
    );
  }
}
