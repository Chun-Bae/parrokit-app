import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
double xpGain(double? score) => math.max(minXpGain, score ?? 0).clamp(0.0, 1.0);

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

/// XP를 저장하는 자리. 홈 무대와 문장 상세가 같은 값을 쌓는다.
String speakingXpKey(String accountId) => 'parrokit.speaking.xp.v1.$accountId';

/// 따라 말하기 한 번의 XP를 더하고 쌓인 값을 돌려준다. 저장에 실패하면 null.
Future<double?> addSpeakingXp(String accountId, double? score) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final key = speakingXpKey(accountId);
    final previous = (prefs.get(key) as num?)?.toDouble() ?? 0;
    final next = nextXp(previous, xpGain(score));
    if (!await prefs.setDouble(key, next)) return null;
    return next;
  } catch (_) {
    return null;
  }
}

// ───────────────────────────────────────────────────────────────────
// 새 경험치(5차 566, 사용자 요청: "경험치 시스템을 좀 더 고도화")
//
// 전에는 한 단계가 늘 10 XP였다. Lv.1→2와 Lv.49→50이 같은 값이라 레벨이
// 커져도 체감이 같았고, 한 번 연습이 0.1 XP라 레벨 하나에 100번이 들었다.
// 막대가 안 움직이니 숫자가 헛돌았다.
//
// 이제 XP는 **한 번만 생기는 일**에만 붙는다 - 문장 단계가 오를 때, 하루
// 첫 연습, 하루 목표 달성. 반복은 크래커(뽑기)가 맡는다. 같은 행동이 두
// 주머니를 동시에 채우지 않는다.
// ───────────────────────────────────────────────────────────────────

/// Lv.1에서 Lv.2로 가는 데 드는 XP.
///
/// 첫 레벨업은 **첫날 안에** 일어나야 한다. 하루 첫 연습(2) + 목표
/// 달성(6) + 문장 두 단계(6)면 그날 넘는다. 10으로 뒀다가 너무 빨리
/// 오른다는 말을 듣고 15로 올렸다(5차 566, 사용자 지적).
const int baseLevelXp = 15;

/// 레벨이 하나 오를 때마다 늘어나는 XP.
///
/// 5였을 때는 꾸준히 쓰면 한 달에 Lv.20이었다. 10이면 Lv.10에 누적
/// 495, Lv.20에 1,995 - 같은 사용량으로 두 배쯤 걸린다. 배수로 늘리면
/// Lv.20 한 칸이 수천이 되어 사실상 거기서 끝나므로 더하기로 둔다.
const int levelXpStep = 10;

/// [level]에서 다음 단계로 가는 데 드는 XP.
int xpForLevel(int level) =>
    baseLevelXp + levelXpStep * (math.max(1, level) - 1);

/// [level]에 **도달**하는 데 드는 누적 XP. Lv.1은 0이다.
int cumulativeXpFor(int level) {
  final l = math.max(1, level);
  return baseLevelXp * (l - 1) + levelXpStep * (l - 1) * (l - 2) ~/ 2;
}

/// 쌓인 XP로 보는 레벨. 0 XP가 Lv.1이다.
int levelForXp(int totalXp) {
  final xp = math.max(0, totalXp);
  var level = 1;
  var spent = 0;
  while (spent + xpForLevel(level) <= xp) {
    spent += xpForLevel(level);
    level++;
  }
  return level;
}

/// 이번 단계에서 쌓은 XP(0 이상 [xpForLevel] 미만).
int xpInLevelOf(int totalXp) =>
    math.max(0, totalXp) - cumulativeXpFor(levelForXp(totalXp));

/// XP가 바뀔 때마다 오른다(5차 566).
///
/// 성취 XP를 주는 곳이 한 군데가 아니다 - 홈 무대(첫 연습·문장 단계),
/// 대시보드(하루 목표), 문장 상세, 단어 복습. 그런데 머리의 막대는 홈
/// 무대가 제 상태로 들고 있어서, 다른 곳에서 준 XP는 탭을 나갔다 와야
/// 보였다. 목표를 채워 받는 +6이 가장 큰 덩이인데 그게 안 보였다.
final ValueNotifier<int> parrotXpRevision = ValueNotifier<int>(0);

/// 새 XP를 적는 자리. v1은 건드리지 않는다.
///
/// practice_calendar가 v1 자리를 '예전 누적 문장 수'로도 읽는다. 거기에
/// 다른 스케일을 쓰면 학습 캘린더 누계가 조용히 틀어진다.
String parrotXpKey(String accountId) => 'parrokit.parrot.xp.v2.$accountId';

/// 옛 XP를 새 XP로 옮긴다.
///
/// 옛 값을 그대로 새 곡선에 넣으면 레벨이 내려간다(79.9 XP는 옛 Lv.8,
/// 새 곡선에서는 Lv.5다). 그래서 **화면에 보이던 레벨과 막대 비율**을
/// 그대로 옮긴다. 레벨은 절대 내려가지 않는다.
int migrateXp(double oldXp) {
  final shown = speakingLevel(oldXp);
  final fraction = xpPerLevel == 0 ? 0.0 : xpInLevel(oldXp) / xpPerLevel;
  // 내림한다. 반올림하면 막대가 거의 찬 사람(9.95/10)이 옮기는 것만으로
  // 레벨이 하나 올라간다. 내려가지도, 공짜로 올라가지도 않아야 한다.
  final inLevel =
      (fraction * xpForLevel(shown)).floor().clamp(0, xpForLevel(shown) - 1);
  return cumulativeXpFor(shown) + inLevel;
}

/// 쌓인 XP를 읽는다. 아직 옮기지 않았으면 옛 값에서 옮겨 적는다.
Future<int> loadParrotXp(String accountId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final key = parrotXpKey(accountId);
    final stored = prefs.get(key);
    if (stored is num) return stored.toInt();
    final old = (prefs.get(speakingXpKey(accountId)) as num?)?.toDouble() ?? 0;
    final moved = migrateXp(old);
    await prefs.setInt(key, moved);
    return moved;
  } catch (_) {
    return 0;
  }
}

/// XP를 더하고 쌓인 값을 돌려준다. 저장에 실패하면 null.
Future<int?> addParrotXp(String accountId, int gain) async {
  if (gain <= 0) return loadParrotXp(accountId);
  try {
    final prefs = await SharedPreferences.getInstance();
    final previous = await loadParrotXp(accountId);
    final next = previous + gain;
    if (!await prefs.setInt(parrotXpKey(accountId), next)) return null;
    // 어디서 줬든 머리의 막대가 바로 따라오게 알린다.
    parrotXpRevision.value++;
    return next;
  } catch (_) {
    return null;
  }
}
