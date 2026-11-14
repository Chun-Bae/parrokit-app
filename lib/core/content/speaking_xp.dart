import 'dart:math' as math;

/// 따라 말하기 XP 계산. 화면(stage_preview_screen)이 들고 있던 식을 꺼내
/// 따로 둔다. 홈에 그대로 보이는 숫자인데 테스트가 없었다(5차).

/// 한 단계에 필요한 XP.
const double xpPerLevel = 10;

/// 점수가 없거나 0에 가까워도 주는 최소 XP.
const double minXpGain = 0.1;

/// 쌓인 XP로 보는 레벨. 0 XP가 Lv.1이다.
int speakingLevel(double totalXp) =>
    (math.max(0, totalXp) ~/ xpPerLevel).toInt() + 1;

/// 이번 단계에서 쌓은 XP(0 이상 [xpPerLevel] 미만).
double xpInLevel(double totalXp) => math.max(0, totalXp) % xpPerLevel;

/// 점수(0~1)로 받는 XP. 100점이면 1 XP.
double xpGain(double? score) =>
    math.max(minXpGain, score ?? 0).clamp(0.0, 1.0);

/// 저장할 XP. 소수 둘째 자리까지만 남긴다.
double nextXp(double previous, double gain) =>
    ((math.max(0, previous) + gain) * 100).round() / 100;

/// XP를 소수 첫째 자리까지만 보여준다. (예: 3.5 → '3.5', 4.0 → '4')
String xpText(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? '${rounded.round()}'
      : rounded.toStringAsFixed(1);
}

/// 홈의 'N / 10 XP'에서 N. 반올림하면 9.99가 '10'이 돼, 아직 레벨이 안
/// 올랐는데 '10 / 10 XP'로 보였다. 내림해서 한 단계를 다 채워야 10이 된다.
String xpProgressText(double totalXp) =>
    xpText((xpInLevel(totalXp) * 10).floor() / 10);
