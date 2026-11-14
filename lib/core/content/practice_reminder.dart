import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

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
  static const pickKey = 'parrokit.practice_reminder.pick.v1';
  static const intervalKey = 'parrokit.practice_reminder.interval.v1';
  static const endHourKey = 'parrokit.practice_reminder.end_hour.v1';
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

String reminderHourLabel(int hour) {
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  return '${hour >= 12 ? '오후' : '오전'} $h12시';
}

class PracticeReminderSettings {
  const PracticeReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
    this.pick = ReminderPick.inOrder,
    this.intervalMinutes = 0,
    this.endHour = PracticeReminder.defaultEndHour,
  });

  final bool enabled;
  final int hour;
  final int minute;
  final ReminderPick pick;

  /// 몇 분마다 받을지. 0이면 하루 한 번([hour]:[minute]에).
  final int intervalMinutes;

  /// 간격으로 받을 때 그날 알림을 그만 받는 시각.
  final int endHour;

  bool get repeats => intervalMinutes > 0;

  PracticeReminderSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    ReminderPick? pick,
    int? intervalMinutes,
    int? endHour,
  }) =>
      PracticeReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        pick: pick ?? this.pick,
        intervalMinutes: intervalMinutes ?? this.intervalMinutes,
        endHour: endHour ?? this.endHour,
      );

  /// 언제 받는지 한 줄로. '오후 8:00에' 또는 '오전 9:00~오후 10시, 2시간마다'.
  String get whenLabel => repeats
      ? '$label~${reminderHourLabel(endHour)}, ${reminderIntervalLabel(intervalMinutes)}'
      : '$label에';

  /// '오후 8:00'처럼 보여 준다.
  String get label {
    final isAfternoon = hour >= 12;
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final mm = minute.toString().padLeft(2, '0');
    return '${isAfternoon ? '오후' : '오전'} $h12:$mm';
  }
}

/// 지금과 첫 알림 사이에 적어도 이만큼은 둔다.
///
/// 몇 초 뒤로 잡으면 예약이 끝나기도 전에 그 시각이 지나 알림이 그냥 사라지거나
/// 바로 울려 버린다(5차, 사용자와 정함).
const reminderMinLead = Duration(seconds: 10);

/// [now] 다음으로 오는 알림 시각들.
///
/// [intervalMinutes]가 0이면 하루 한 번 [hour]:[minute]에. 0보다 크면 그날
/// [hour]:[minute]부터 [endHour]시까지 그 간격마다. 어느 쪽이든 지금보다
/// [minLead]만큼은 뒤의 것만 담고, 기기가 들고 있을 수 있는 수([maxCount])에서
/// 끊는다.
List<DateTime> reminderTimes(
  DateTime now,
  int hour,
  int minute, {
  int days = PracticeReminder.scheduleDays,
  Duration minLead = reminderMinLead,
  int intervalMinutes = 0,
  int endHour = PracticeReminder.defaultEndHour,
  int maxCount = PracticeReminder.maxPending,
}) {
  if (intervalMinutes <= 0) {
    var first = DateTime(now.year, now.month, now.day, hour, minute);
    if (first.difference(now) < minLead) {
      first = first.add(const Duration(days: 1));
    }
    return [
      for (var i = 0; i < days && i < maxCount; i++)
        DateTime(first.year, first.month, first.day + i, hour, minute),
    ];
  }

  final earliest = now.add(minLead);
  final times = <DateTime>[];
  for (var day = 0; day < days && times.length < maxCount; day++) {
    final start = DateTime(now.year, now.month, now.day + day, hour, minute);
    final end = DateTime(now.year, now.month, now.day + day, endHour, 0);
    var at = start;
    // 시작이 끝보다 늦으면(예: 밤 11시 시작, 밤 10시까지) 그날은 한 번만.
    final last = end.isBefore(start) ? start : end;
    while (!at.isAfter(last) && times.length < maxCount) {
      if (!at.isBefore(earliest)) times.add(at);
      at = at.add(Duration(minutes: intervalMinutes));
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
  return [for (final c in usable) c.text];
}

/// 알림에 넣을 문장을 날짜 수만큼 고른다. 문장이 적으면 돌려 쓴다.
/// 문장이 없으면 빈 목록(그러면 기본 문구로 알린다).
List<String> pickReminderLines(List<String> sentences, int count) {
  final usable = [
    for (final s in sentences)
      if (s.trim().isNotEmpty) s.trim(),
  ];
  if (usable.isEmpty || count <= 0) return const [];
  return [for (var i = 0; i < count; i++) usable[i % usable.length]];
}

/// 알림에 보일 제목과 본문. 적어 둔 문장이 없으면 문장 없이 부른다.
({String title, String body}) reminderContent(String? sentence) {
  const title = '오늘 따라 말하기';
  final text = sentence?.trim() ?? '';
  return text.isEmpty
      ? (title: title, body: '앵무새가 기다려요. 한 문장만 따라 말해 볼까요?')
      : (title: title, body: text);
}
