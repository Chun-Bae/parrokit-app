// 연습 보상의 기댓값을 찍어 본다. 화면 없이 바로 확인하려고 둔 도구다.
//
//   dart run tool/reward_forecast.dart
//   dart run tool/reward_forecast.dart 5        # 주 5일만 연습할 때
//
// 숫자를 고치려면 lib/core/content/practice_reward.dart의 rewardTiers와
// rewardDailyCap·rewardWeeklyCap·rewardMonthlyCap을 고친다.

// 찍어 보는 것이 이 도구의 일이다. 앱에 들어가지 않는다.
// ignore_for_file: avoid_print

import 'package:parrokit/core/content/practice_reward.dart';

void main(List<String> args) {
  final daysPerWeek = args.isEmpty ? 7 : int.tryParse(args.first) ?? 7;

  print('연습 보상 기댓값 (주 $daysPerWeek일 연습)');
  print('');
  print('뽑기 표');
  for (final tier in rewardTiers) {
    final percent = tier.weight * 100 / rewardTotalWeight;
    print('  ${tier.crackers.toString().padLeft(5)} 크래커 · '
        '${percent.toStringAsFixed(1).padLeft(5)}% '
        '(1,000번에 ${tier.weight}번)');
  }
  print('  한 번 평균 ${rewardRollExpected.toStringAsFixed(1)} 크래커 (상한 없을 때)');
  print('');
  print('상한  하루 $rewardDailyCap · 한 주 $rewardWeeklyCap · 한 달 $rewardMonthlyCap');
  print('');
  print('하루 연습  연습한 날      한 주       한 달(28일)   패롯/달');
  for (final rolls in [1, 2, 3, 5, 10, 20, 50]) {
    final f = rewardForecast(rollsPerDay: rolls, daysPerWeek: daysPerWeek);
    print('  ${rolls.toString().padLeft(2)}번'
        '   ${f.perPracticeDay.toStringAsFixed(1).padLeft(10)}'
        '   ${f.perWeek.toStringAsFixed(0).padLeft(9)}'
        '   ${f.perMonth.toStringAsFixed(0).padLeft(11)}'
        '   ${f.parrotsPerMonth.toStringAsFixed(2).padLeft(7)}');
  }
}
