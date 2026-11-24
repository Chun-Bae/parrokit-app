import 'dart:async';

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/shared/widgets/currency_icon.dart';
import 'package:parrokit/core/shared/widgets/reward_celebration.dart';
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
    if (!mounted) return;
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

  /// 서버가 넣어 준 패롯이 잔액에 닿을 때까지 기다린다.
  ///
  /// 사용자 문서 구독(watchUserById)이 올려 주므로 그 알림을 듣는다.
  /// [coins]만큼 다 오르기를 기다리지 않고 **오르기만 하면** 참이다 -
  /// 그 사이 다른 보상이 함께 들어와 더 오를 수 있고, 적게 올랐다고
  /// 덮개를 안 띄우면 받은 것을 안 받은 것처럼 보인다.
  ///
  /// 화면을 떠나도 계속 듣는다. 덮개를 띄울지는 부르는 쪽이 mounted로 가른다.
  Future<bool> _waitForCoins(UserProvider provider, int coins) async {
    final before = provider.coins;
    if (provider.coins > before) return true;
    final done = Completer<bool>();
    void check() {
      if (!done.isCompleted && provider.coins > before) done.complete(true);
    }

    provider.addListener(check);
    // 찬 함수가 깨고 AdMob 콜백까지 오는 데 걸리는 시간이다. 넘기면
    // 기다리기를 그만두되, 지급 자체는 서버에서 그대로 진행된다.
    final timer = Timer(const Duration(seconds: 20), () {
      if (!done.isCompleted) done.complete(false);
    });
    try {
      return await done.future;
    } finally {
      timer.cancel();
      provider.removeListener(check);
    }
  }

  void _onWatchAd() {
    // 광고는 전체 화면으로 30초쯤 돈다. 그 사이에 이 섹션이 사라질 수 있으니
    // Provider는 미리 잡아 둔다.
    final userProvider = context.read<UserProvider>();

    // 광고를 트는 동안 보상 서버를 미리 깨운다(5차, 사용자 요청). 30초면
    // 넉넉하다. 기다리지 않는다 - 못 깨워도 광고는 그대로 튼다.
    unawaited(AdService.warmUpRewardServer());

    AdService().showRewardedAd(
      onRewarded: (coins) async {
        if (coins == null) {
          showToast('광고가 아직 준비 중이에요. 잠시 뒤 다시 시도해 주세요.');
          return;
        }

        // 보상 지급에 `if (!mounted) return;`이 걸려 있었다. 사용자가 광고를
        // 끝까지 봤는데 그 사이 화면을 떠났으면 코인을 못 받았다. 지급과
        // 쿨다운 기록은 화면 수명과 상관없이 한다.
        if (AdService.serverCreditsReward) {
          // 서버가 AdMob 확인을 받고 지급한다. 잔액은 사용자 문서 구독으로
          // 따라온다.
          //
          // 568에서는 '아직 안 들어온 것을 축하하지 않는다'며 글 한 줄로
          // 바꿨다. 그 바람에 출시 빌드에서 덮개가 통째로 사라졌다 - 덮개는
          // 사용자가 원해서 넣은 것이다(5차 568).
          //
          // 없애는 대신 **기다리는 것을 보여 준다**(5차, 사용자 요청).
          // 광고가 닫히자마자 '받는 중' 덮개를 띄우고, 잔액이 실제로 오르면
          // 같은 자리에서 '짜잔'으로 바꾼다. 토스트 한 줄은 광고가 닫히는
          // 어수선한 순간에 묻혔고, 받은 건지 만 건지도 알 수 없었다.
          final arrived = mounted
              ? await showRewardPending<bool>(
                  context,
                  until: _waitForCoins(userProvider, coins),
                  icon: const CurrencyIcon(Currency.parrot, size: 56),
                  text: '패롯 +$coins',
                )
              : await _waitForCoins(userProvider, coins);
          if (!arrived) {
            // 못 기다렸다. 지급 자체는 서버에서 그대로 간다. 거짓으로
            // 축하하느니 늦게 말한다.
            showToast('패롯 $coins개를 곧 받아요!');
          } else if (mounted) {
            await showRewardCelebration(
              context,
              amount: coins,
              currency: Currency.parrot,
            );
          } else {
            showToast('패롯 $coins개를 받았어요!');
          }
        } else {
          try {
            await userProvider.addCoins(coins);
          } catch (e) {
            AppLogger.e('[AdReward] 광고 보상 지급 실패 coins=$coins', error: e);
            showToast('광고 보상 지급에 실패했어요. 잠시 뒤 다시 시도해 주세요.');
            return;
          }
          // 단어 복습을 마쳤을 때와 같은 덮개로 띄운다(5차 568, 사용자 요청).
          // 토스트 한 줄은 광고가 닫히는 어수선한 순간에 묻혔다.
          if (mounted) {
            await showRewardCelebration(
              context,
              amount: coins,
              currency: Currency.parrot,
            );
          } else {
            showToast('패롯 $coins개를 받았어요!');
          }
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
