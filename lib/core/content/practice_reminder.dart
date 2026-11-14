import 'dart:convert';

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

  /// 기본 시각(저녁 8시).
  static const defaultHour = 20;
  static const defaultMinute = 0;

  /// 한 번에 예약해 두는 날수. iOS는 예약 알림을 64개까지만 들고 있어서
  /// 넉넉히 잡아도 이 아래면 된다. 앱을 열 때마다 다시 채운다.
  static const scheduleDays = 14;

  static Future<PracticeReminderSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return PracticeReminderSettings(
      enabled: prefs.getBool(enabledKey) ?? false,
      hour: prefs.getInt(hourKey) ?? defaultHour,
      minute: prefs.getInt(minuteKey) ?? defaultMinute,
    );
  }

  static Future<void> save(PracticeReminderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, settings.enabled);
    await prefs.setInt(hourKey, settings.hour);
    await prefs.setInt(minuteKey, settings.minute);
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
}

class PracticeReminderSettings {
  const PracticeReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final bool enabled;
  final int hour;
  final int minute;

  PracticeReminderSettings copyWith({bool? enabled, int? hour, int? minute}) =>
      PracticeReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );

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

/// [now] 다음으로 오는 알림 시각들. 오늘 그 시각이 지났거나
/// [minLead]보다 가까우면 내일부터.
List<DateTime> reminderTimes(
  DateTime now,
  int hour,
  int minute, {
  int days = PracticeReminder.scheduleDays,
  Duration minLead = reminderMinLead,
}) {
  var first = DateTime(now.year, now.month, now.day, hour, minute);
  if (first.difference(now) < minLead) {
    first = first.add(const Duration(days: 1));
  }
  return [
    for (var i = 0; i < days; i++)
      DateTime(first.year, first.month, first.day + i, hour, minute),
  ];
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
