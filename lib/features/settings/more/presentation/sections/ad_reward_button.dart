import 'dart:async';

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/core/infrastructure/services/ad_service.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 광고 버튼의 상태. 화면 글자와 누를 수 있는지는 [adRewardButtonLabel]이 정한다.
enum AdRewardButtonState { cooldown, loading, failed, ready }

AdRewardButtonState adRewardButtonState(
    {required bool cooldown, required bool ready, required bool failed}) {
  if (cooldown) return AdRewardButtonState.cooldown;
  if (ready) return AdRewardButtonState.ready;
  if (failed) return AdRewardButtonState.failed;
  return AdRewardButtonState.loading;
}

/// 버튼 글자. 예전 '광고 보고 +3'은 무엇이 3개인지 몰라 '패롯'을 넣었다(5차).
String adRewardButtonLabel(AdRewardButtonState state,
    {required int coins, String cooldownText = ''}) {
  return switch (state) {
    AdRewardButtonState.cooldown => cooldownText,
    AdRewardButtonState.loading => '광고 준비 중',
    AdRewardButtonState.failed => '광고 다시 불러오기',
    AdRewardButtonState.ready => '광고 보고 패롯 +$coins',
  };
}

/// 광고 보고 패롯 받기 버튼. 지갑 카드 안에 들어간다.
///
/// 광고 로드·시청·보상·쿨다운을 스스로 처리한다.
class AdRewardButton extends StatefulWidget {
  const AdRewardButton({super.key, required this.style});

  /// 지갑 카드의 다른 버튼과 모양을 맞추려고 밖에서 받는다.
  final ButtonStyle style;

  @override
  State<AdRewardButton> createState() => _AdRewardButtonState();
}

class _AdRewardButtonState extends State<AdRewardButton> {
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
        if (AdService.serverCreditsReward) {
          // 서버가 AdMob 확인을 받고 지급한다. 잔액은 사용자 문서 구독으로
          // 곧 바뀐다.
          showToast('패롯 $coins개를 곧 받아요!');
        } else {
          try {
            await userProvider.addCoins(coins);
          } catch (e) {
            AppLogger.e('[AdReward] 광고 보상 지급 실패 coins=$coins', error: e);
            showToast('광고 보상 지급에 실패했어요. 잠시 후 다시 시도해 주세요.');
            return;
          }
          showToast('패롯 $coins개를 받았어요!');
        }

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
    final isCooldown = _remaining != null;

    final ads = AdService();
    return ListenableBuilder(
      listenable: Listenable.merge([
        ads.isRewardedAdReadyListenable,
        ads.isRewardedAdFailedListenable,
      ]),
      builder: (context, _) {
        final state = adRewardButtonState(
          cooldown: isCooldown,
          ready: ads.isRewardedAdReadyListenable.value,
          failed: ads.isRewardedAdFailedListenable.value,
        );
        return FilledButton.icon(
          style: widget.style,
          onPressed: switch (state) {
            AdRewardButtonState.ready => _onWatchAd,
            AdRewardButtonState.failed => ads.loadRewardedAd,
            _ => null,
          },
          icon: switch (state) {
            AdRewardButtonState.cooldown =>
              const Icon(Icons.timer_outlined, size: 18),
            AdRewardButtonState.loading => const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            AdRewardButtonState.failed =>
              const Icon(Icons.refresh_rounded, size: 18),
            AdRewardButtonState.ready =>
              const Icon(Icons.play_circle_outline_rounded, size: 18),
          },
          // 큰 글자 설정에서 '광고 보고 …'로 잘려 받을 패롯 수가 안 보였다(5차).
          // 한 줄을 지키며 칸에 맞게 줄인다.
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              adRewardButtonLabel(state,
                  coins: AdService.rewardCoins,
                  cooldownText:
                      isCooldown ? _formatRemaining(_remaining!) : ''),
              maxLines: 1,
            ),
          ),
        );
      },
    );
  }
}
