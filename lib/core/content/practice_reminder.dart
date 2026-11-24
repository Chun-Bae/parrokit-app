import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'practice_reward.dart';

/// 연습 알림(기기에서 예약하는 알림).
///
/// 서버를 쓰지 않는다. 앱이 켜져 있을 때 앞으로 며칠치를 한꺼번에 예약하고,
/// 알림에 띄울 문장도 그때 골라 기기에 적어 둔다. 내 문장은 로그인 상태에서
/// 서버에만 있어서(MySentenceStore) 알림을 만들 때 읽을 수 없기 때문이다
/// (5차, 사용자와 정한 방식).
class PracticeReminder {
  PracticeReminder._();

  static const enabledKey = 'parrokit.practice_reminder.enabled.v1';
  static const hourKey = 'parrokit.practice_reminder.hour.v1';
  static const minuteKey = 'parrokit.practice_reminder.minute.v1';
  static const linesKey = 'parrokit.practice_reminder.lines.v1';
  static const lineIdsKey = 'parrokit.practice_reminder.line_ids.v1';
  static const pickKey = 'parrokit.practice_reminder.pick.v1';
  static const intervalKey = 'parrokit.practice_reminder.interval.v1';
  static const endHourKey = 'parrokit.practice_reminder.end_hour.v1';
  static const endMinuteKey = 'parrokit.practice_reminder.end_minute.v1';
  static const chosenKey = 'parrokit.practice_reminder.chosen.v1';

  /// 기본 시각(저녁 8시). 간격으로 받을 때는 그날 첫 알림 시각이다.
  static const defaultHour = 20;
  static const defaultMinute = 0;

  /// 간격으로 받을 때 그날 알림을 그만 받는 시각(기본 밤 10시).
  static const defaultEndHour = 22;

  /// 한 번에 예약해 둘 수 있는 알림 수. iOS가 64개까지만 들고 있어서
  /// 조금 남겨 둔다(다른 알림이 끼어도 밀리지 않게).
  static const maxPending = 60;

  /// 한 번에 예약해 두는 날수. iOS는 예약 알림을 64개까지만 들고 있어서
  /// 넉넉히 잡아도 이 아래면 된다. 앱을 열 때마다 다시 채운다.
  static const scheduleDays = 14;

  static Future<PracticeReminderSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return PracticeReminderSettings(
      enabled: prefs.getBool(enabledKey) ?? false,
      hour: prefs.getInt(hourKey) ?? defaultHour,
      minute: prefs.getInt(minuteKey) ?? defaultMinute,
      pick: reminderPickFromKey(prefs.getString(pickKey)),
      intervalMinutes: prefs.getInt(intervalKey) ?? 0,
      endHour: prefs.getInt(endHourKey) ?? defaultEndHour,
      endMinute: prefs.getInt(endMinuteKey) ?? 0,
    );
  }

  static Future<void> save(PracticeReminderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, settings.enabled);
    await prefs.setInt(hourKey, settings.hour);
    await prefs.setInt(minuteKey, settings.minute);
    await prefs.setString(pickKey, settings.pick.key);
    await prefs.setInt(intervalKey, settings.intervalMinutes);
    await prefs.setInt(endHourKey, settings.endHour);
    await prefs.setInt(endMinuteKey, settings.endMinute);
  }

  /// 알림에 띄우려고 적어 둔 문장.
  static Future<List<String>> loadLines() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(linesKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is String && item.trim().isNotEmpty) item,
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> saveLines(List<String> lines) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(linesKey, jsonEncode(lines));
  }

  /// 적어 둔 문장과 같은 차례의 문장 id. 글과 따로 두는 까닭은 예전에
  /// 적어 둔 글만 있는 기기에서도 그대로 읽히게 하려는 것이다(5차 508).
  static Future<List<String>> loadLineIds() async {
    final prefs = await SharedPreferences.getInstance();
    return [...?prefs.getStringList(lineIdsKey)];
  }

  static Future<void> saveLineIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(lineIdsKey, ids);
  }

  /// 알림에 쓸 문장으로 고른 것들의 id. 비어 있으면 내 문장 전부를 쓴다.
  static Future<Set<String>> loadChosen() async {
    final prefs = await SharedPreferences.getInstance();
    return {...?prefs.getStringList(chosenKey)};
  }

  static Future<void> saveChosen(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(chosenKey, ids.toList());
  }
}

/// 어떤 문장을 어떤 차례로 알릴지.
enum ReminderPick {
  /// 저장한 차례대로 하나씩.
  inOrder('in_order', '저장한 순서대로', '저장한 차례대로 하나씩 알려 줘요'),

  /// 섞어서. 예약할 때 한 번 섞고 그 차례를 쓴다.
  random('random', '랜덤', '문장을 섞어서 번갈아 알려 줘요'),

  /// 따라 말한 횟수가 적은 문장부터.
  leastPracticed('least_practiced', '덜 익숙한 순', '따라 말한 횟수가 적은 문장부터 알려 줘요');

  const ReminderPick(this.key, this.label, this.hint);

  final String key;
  final String label;
  final String hint;
}

ReminderPick reminderPickFromKey(String? key) {
  for (final pick in ReminderPick.values) {
    if (pick.key == key) return pick;
  }
  return ReminderPick.inOrder;
}

/// 알림에 띄울 문장 후보. 고르는 방식에 따라 연습 기록도 본다.
class ReminderCandidate {
  const ReminderCandidate({
    required this.text,
    this.id = '',
    this.practiceCount = 0,
    this.lastPracticedAt,
  });

  final String text;

  /// 내 문장 id. 고른 문장만 쓸 때 이 id로 가린다.
  final String id;
  final int practiceCount;
  final DateTime? lastPracticedAt;
}

/// 고를 수 있는 간격(분). 0은 하루 한 번. 가장 짧은 간격은 1분이다
/// (사용자와 정함). 짧게 잡으면 기기가 들고 있을 수 있는 수(maxPending)에서
/// 끊기지만, 앱을 열 때마다 다시 채운다.
const reminderIntervalChoices = <int>[0, 1, 5, 10, 30, 60, 120, 180, 360];

String reminderIntervalLabel(int minutes) {
  if (minutes <= 0) return '하루 한 번';
  if (minutes < 60) return '$minutes분마다';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours시간마다' : '$hours시간 $rest분마다';
}

/// '오후 10:00'처럼 보여 준다.
String reminderTimeLabel(int hour, int minute) {
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  final mm = minute.toString().padLeft(2, '0');
  return '${hour >= 12 ? '오후' : '오전'} $h12:$mm';
}

class PracticeReminderSettings {
  const PracticeReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
    this.pick = ReminderPick.inOrder,
    this.intervalMinutes = 0,
    this.endHour = PracticeReminder.defaultEndHour,
    this.endMinute = 0,
  });

  final bool enabled;
  final int hour;
  final int minute;
  final ReminderPick pick;

  /// 몇 분마다 받을지. 0이면 하루 한 번([hour]:[minute]에).
  final int intervalMinutes;

  /// 간격으로 받을 때 그날 알림을 그만 받는 시각.
  final int endHour;
  final int endMinute;

  bool get repeats => intervalMinutes > 0;

  PracticeReminderSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    ReminderPick? pick,
    int? intervalMinutes,
    int? endHour,
    int? endMinute,
  }) =>
      PracticeReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        pick: pick ?? this.pick,
        intervalMinutes: intervalMinutes ?? this.intervalMinutes,
        endHour: endHour ?? this.endHour,
        endMinute: endMinute ?? this.endMinute,
      );

  /// 언제 받는지 한 줄로. '오후 8:00에' 또는 '오전 9:00~오후 10:00, 2시간마다'.
  String get whenLabel => repeats
      ? '$label~$endLabel, ${reminderIntervalLabel(intervalMinutes)}'
      : '$label에';

  /// '오후 8:00'처럼 보여 준다.
  String get label => reminderTimeLabel(hour, minute);

  /// 그만 받을 시각.
  String get endLabel => reminderTimeLabel(endHour, endMinute);
}

/// 지금과 첫 알림 사이에 적어도 이만큼은 둔다.
///
/// 몇 초 뒤로 잡으면 예약이 끝나기도 전에 그 시각이 지나 알림이 그냥 사라지거나
/// 바로 울려 버린다(5차, 사용자와 정함).
const reminderMinLead = Duration(seconds: 10);

/// 알림 시각을 앞뒤로 이만큼까지 흔든다(5차 505, 사용자 요청).
///
/// 매일 같은 시각에 오면 금세 지루해진다. 그렇다고 아무 때나 뽑으면 하루에
/// 한 번도 안 오는 날이 생기고, 왜 그 시각에 왔는지 설명할 수도 없다.
/// 그래서 간격은 그대로 두고 시각만 흔든다. 흔드는 값은 날짜로 정해지므로
/// 같은 날에 몇 번을 다시 예약해도 같은 시각이 나온다(테스트가 볼 수 있다).
const int reminderJitterMinutes = 15;

/// [seed]·[day]·[slot]으로 정해지는 -[jitter]~+[jitter]분.
///
/// Random을 쓰지 않는다. 앱을 열 때마다 다시 예약하는데, 그때마다 다른 값이
/// 나오면 같은 알림이 이리저리 움직인다.
int reminderJitterFor(int seed, int day, int slot, int jitter) {
  if (jitter <= 0) return 0;
  var h = 0x811c9dc5 ^ seed;
  for (final value in [day, slot]) {
    h = (h ^ (value + 0x9e3779b9)) & 0x7fffffff;
    h = (h * 16777619) & 0x7fffffff;
  }
  return h % (jitter * 2 + 1) - jitter;
}

/// [now] 다음으로 오는 알림 시각들.
///
/// [intervalMinutes]가 0이면 하루 한 번 [hour]:[minute]에. 0보다 크면 그날
/// [hour]:[minute]부터 [endHour]시까지 그 간격마다. 어느 쪽이든 지금보다
/// [minLead]만큼은 뒤의 것만 담고, 기기가 들고 있을 수 있는 수([maxCount])에서
/// 끊는다.
///
/// 간격으로 받을 때 **오늘치는 지금([now])부터 다시 센다**(5차 505, 사용자
/// 요청). 전에는 날마다 같은 격자(8:00·10:00·12:00…)에 박혀 있어서, 앱을 쓴
/// 직후에도 늘 같은 시각에 왔다. 이제 앱을 열면 그때부터 한 간격 뒤가 첫
/// 알림이다. 간격은 그대로인데 오는 시각은 매일 달라진다.
///
/// 거기에 [jitterMinutes]만큼 앞뒤로 흔든다. 흔드는 값은 날짜로 정해지므로
/// 같은 날 다시 예약해도 같은 시각이 나온다. [hour]~[endHour] 밖으로는
/// 나가지 않으므로 새벽에 울리지 않는다.
List<DateTime> reminderTimes(
  DateTime now,
  int hour,
  int minute, {
  int days = PracticeReminder.scheduleDays,
  Duration minLead = reminderMinLead,
  int intervalMinutes = 0,
  int endHour = PracticeReminder.defaultEndHour,
  int endMinute = 0,
  int maxCount = PracticeReminder.maxPending,
  int jitterMinutes = reminderJitterMinutes,
  int seed = 0,
}) {
  final earliest = now.add(minLead);

  if (intervalMinutes <= 0) {
    var first = DateTime(now.year, now.month, now.day, hour, minute);
    if (first.difference(now) < minLead) {
      first = first.add(const Duration(days: 1));
    }
    final times = <DateTime>[];
    for (var i = 0; i < days && times.length < maxCount; i++) {
      final at = DateTime(first.year, first.month, first.day + i, hour, minute);
      // 하루 한 번일 때는 그날 안에서만 흔든다(날이 넘어가면 안 온 날이 생긴다).
      final shifted = at.add(Duration(
          minutes: reminderJitterFor(seed, i, 0, jitterMinutes)));
      final kept = shifted.day == at.day && !shifted.isBefore(earliest)
          ? shifted
          : at;
      if (!kept.isBefore(earliest)) times.add(kept);
    }
    return times;
  }

  final interval = Duration(minutes: intervalMinutes);
  // 흔들림은 간격의 절반을 넘지 않는다(5차).
  //
  // 넘으면 흔든 시각이 앞 알림보다 뒤로 가지 못해 그 칸이 통째로 버려진다.
  // 그래서 '1분마다'를 골라도 실제로는 평균 3분, '5분마다'는 8분 간격으로
  // 왔다 - 화면이 적은 간격과 다르다. 절반까지면 어느 칸도 앞칸을 앞지르지
  // 않아 간격이 그대로 지켜지면서 시각만 흔들린다.
  final jitter = jitterMinutes <= 0
      ? 0
      : min(jitterMinutes, intervalMinutes ~/ 2);
  final times = <DateTime>[];
  for (var day = 0; day < days && times.length < maxCount; day++) {
    final start = DateTime(now.year, now.month, now.day + day, hour, minute);
    final end =
        DateTime(now.year, now.month, now.day + day, endHour, endMinute);
    // 시작이 끝보다 늦으면(예: 밤 11시 시작, 밤 10시까지) 그날은 한 번만.
    final last = end.isBefore(start) ? start : end;

    // 오늘치는 앱을 연 지금부터 한 간격 뒤에 시작한다. 아직 시작 시각이
    // 안 됐으면(아침에 열었는데 저녁부터 받는 설정) 시작 시각부터다.
    var at = start;
    if (day == 0 && !now.isBefore(start)) {
      final fromNow = now.add(interval);
      if (fromNow.isAfter(start)) at = fromNow;
    }

    var slot = 0;
    while (!at.isAfter(last) && times.length < maxCount) {
      final shifted =
          at.add(Duration(minutes: reminderJitterFor(seed, day, slot, jitter)));
      // 흔들어도 그날 창 안에, 앞 알림보다 뒤에, 지금보다 뒤에 둔다.
      var kept = shifted;
      if (kept.isBefore(start)) kept = start;
      if (kept.isAfter(last)) kept = last;
      if (times.isNotEmpty && !kept.isAfter(times.last)) kept = at;
      if (!kept.isBefore(earliest) &&
          (times.isEmpty || kept.isAfter(times.last))) {
        times.add(kept);
      }
      at = at.add(interval);
      slot++;
    }
  }
  return times;
}

/// 고른 문장만 남긴다. 고른 것이 없으면(또는 고른 문장이 모두 지워졌으면)
/// 전부 쓴다. 알림이 아예 안 오는 것보다 낫다.
List<ReminderCandidate> chosenReminderCandidates(
  List<ReminderCandidate> candidates,
  Set<String> chosenIds,
) {
  if (chosenIds.isEmpty) return candidates;
  final kept = [
    for (final c in candidates)
      if (chosenIds.contains(c.id)) c,
  ];
  return kept.isEmpty ? candidates : kept;
}

/// 고르는 방식대로 후보의 차례를 정한다. 빈 문장은 뺀다.
///
/// 랜덤은 예약할 때 한 번만 섞는다. 알림 하나하나를 그때 뽑을 수 없기
/// 때문이다(기기에 미리 예약해 둔다).
List<String> orderReminderLines(
  List<ReminderCandidate> candidates,
  ReminderPick pick, {
  Random? random,
}) =>
    [
      for (final c in orderReminderCandidates(candidates, pick, random: random))
        c.text,
    ];

/// 차례를 정하되 후보 그대로 돌려준다. 알림에 문장 id를 함께 실으려면
/// 글만으로는 모자라서, 누름을 받았을 때 그 문장을 찾을 수 있게 id를 들고
/// 간다(5차 508).
List<ReminderCandidate> orderReminderCandidates(
  List<ReminderCandidate> candidates,
  ReminderPick pick, {
  Random? random,
}) {
  final usable = [
    for (final c in candidates)
      if (c.text.trim().isNotEmpty)
        ReminderCandidate(
          text: c.text.trim(),
          id: c.id,
          practiceCount: c.practiceCount,
          lastPracticedAt: c.lastPracticedAt,
        ),
  ];
  if (usable.isEmpty) return const [];
  switch (pick) {
    case ReminderPick.inOrder:
      break;
    case ReminderPick.random:
      usable.shuffle(random ?? Random());
    case ReminderPick.leastPracticed:
      // 횟수가 같으면 오래 안 한 문장부터. 한 번도 안 한 문장이 가장 앞.
      final order = {for (var i = 0; i < usable.length; i++) usable[i]: i};
      usable.sort((a, b) {
        final byCount = a.practiceCount.compareTo(b.practiceCount);
        if (byCount != 0) return byCount;
        final at = a.lastPracticedAt;
        final bt = b.lastPracticedAt;
        if (at == null && bt != null) return -1;
        if (at != null && bt == null) return 1;
        if (at != null && bt != null) {
          final byTime = at.compareTo(bt);
          if (byTime != 0) return byTime;
        }
        return order[a]!.compareTo(order[b]!);
      });
  }
  return usable;
}

/// 알림에 넣을 문장을 날짜 수만큼 고른다. 문장이 적으면 돌려 쓴다.
/// 문장이 없으면 빈 목록(그러면 기본 문구로 알린다).
List<ReminderCandidate> pickReminderCandidates(
  List<ReminderCandidate> candidates,
  int count,
) {
  final usable = [
    for (final c in candidates)
      if (c.text.trim().isNotEmpty) c,
  ];
  if (usable.isEmpty || count <= 0) return const [];
  return [for (var i = 0; i < count; i++) usable[i % usable.length]];
}

List<String> pickReminderLines(List<String> sentences, int count) {
  final usable = [
    for (final s in sentences)
      if (s.trim().isNotEmpty) s.trim(),
  ];
  if (usable.isEmpty || count <= 0) return const [];
  return [for (var i = 0; i < count; i++) usable[i % usable.length]];
}

/// 알림에 보일 제목과 본문. 적어 둔 문장이 없으면 문장 없이 부른다.
///
/// 본문 끝에 크래커 한 줄을 붙인다(5차 505, 사용자 요청). 액수는 뽑기라
/// 적지 않는다. 며칠 전에 깔아 둔 알림은 그날 몇 개를 뽑을지 모른다.
({String title, String body}) reminderContent(String? sentence) {
  const title = '오늘 따라 말하기';
  final text = sentence?.trim() ?? '';
  return text.isEmpty
      ? (
          title: title,
          body: '앵무새가 기다려요. $practiceRewardShortInvite.',
        )
      : (title: title, body: '$text\n$practiceRewardShortInvite');
}
