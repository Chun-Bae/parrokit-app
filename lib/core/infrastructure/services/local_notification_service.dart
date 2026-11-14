import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:parrokit/core/content/practice_reminder.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';

/// 기기에서 예약하는 알림. 서버(FCM)를 거치지 않는다.
///
/// 연습 알림만 쓴다. 예약은 '언제'(그 순간)로 걸기 때문에 기기 시간대 이름을
/// 따로 알아낼 필요가 없다. 서머타임이 있는 지역에서 예약해 둔 날짜가 전환일을
/// 넘기면 한 시간 어긋날 수 있는데, 앱을 열 때마다 다시 예약하므로 곧 맞는다.
class LocalNotificationService {
  LocalNotificationService._();

  static final plugin = FlutterLocalNotificationsPlugin();

  /// 연습 알림이 쓰는 id 범위. 지울 때 이 범위만 지운다.
  static const practiceIdBase = 9100;

  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await plugin.initialize(
      const InitializationSettings(
        iOS: DarwinInitializationSettings(
          // 권한은 설정을 켤 때 따로 묻는다. 앱을 처음 켤 때 묻지 않는다.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  /// 알림 권한을 묻는다. 허락했으면 true.
  static Future<bool> requestPermission() async {
    await init();
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        return await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
      final android = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (e) {
      AppLogger.e('[Reminder] 알림 권한 요청 실패', error: e);
      return false;
    }
  }

  static Future<void> cancelPracticeReminders() async {
    await init();
    for (var i = 0; i < PracticeReminder.maxPending; i++) {
      try {
        await plugin.cancel(practiceIdBase + i);
      } catch (_) {/* 없는 알림을 지우는 것은 그냥 넘어간다 */}
    }
  }

  /// [times]마다 하나씩 예약한다. [lines]는 같은 자리의 문장(없으면 기본 문구).
  static Future<void> schedulePracticeReminders({
    required List<DateTime> times,
    required List<String> lines,
  }) async {
    await init();
    await cancelPracticeReminders();

    const details = NotificationDetails(
      // 앱을 보고 있는 동안에도 뜨게 한다(5차, 사용자 요청). iOS 쪽
      // AppDelegate도 연습 알림은 배너로 띄우도록 함께 고쳤다.
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: true,
      ),
      android: AndroidNotificationDetails(
        'practice_reminder',
        '연습 알림',
        channelDescription: '정한 시각에 따라 말하기를 알려 줘요.',
        importance: Importance.defaultImportance,
      ),
    );

    for (var i = 0; i < times.length; i++) {
      final content =
          reminderContent(i < lines.length ? lines[i] : null);
      try {
        await plugin.zonedSchedule(
          practiceIdBase + i,
          content.title,
          content.body,
          tz.TZDateTime.from(times[i], tz.UTC),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e) {
        AppLogger.e('[Reminder] 알림 예약 실패', error: e);
        return;
      }
    }
  }
}

/// 설정대로 연습 알림을 다시 예약한다. 꺼져 있으면 모두 지운다.
///
/// [candidates]는 알림에 띄울 후보. 예약하는 이 순간에 읽어 둔 내 문장이다.
/// 차례는 설정의 고르는 방식(순서·랜덤·덜 익숙한 순)대로 정한다.
Future<void> applyPracticeReminder({
  required PracticeReminderSettings settings,
  required List<ReminderCandidate> candidates,
  DateTime? now,
  Random? random,
}) async {
  if (!settings.enabled) {
    await LocalNotificationService.cancelPracticeReminders();
    await PracticeReminder.saveLines(const []);
    return;
  }
  final times = reminderTimes(
    now ?? DateTime.now(),
    settings.hour,
    settings.minute,
    intervalMinutes: settings.intervalMinutes,
    endHour: settings.endHour,
    endMinute: settings.endMinute,
  );
  final chosen =
      chosenReminderCandidates(candidates, await PracticeReminder.loadChosen());
  final ordered = orderReminderLines(chosen, settings.pick, random: random);
  final lines = pickReminderLines(ordered, times.length);
  await PracticeReminder.saveLines(lines);
  await LocalNotificationService.schedulePracticeReminders(
      times: times, lines: lines);
}

/// 앱을 열 때 호출한다. 꺼져 있으면 아무것도 하지 않는다.
///
/// 며칠치만 예약해 두므로 열 때마다 다시 채워야 알림이 끊기지 않는다.
/// 문장을 못 읽어도(오프라인·로그인 전) 적어 둔 문장으로 예약한다.
Future<void> refreshPracticeReminder(String accountId) async {
  try {
    final settings = await PracticeReminder.load();
    if (!settings.enabled) return;
    var candidates = [
      for (final text in await PracticeReminder.loadLines())
        ReminderCandidate(text: text),
    ];
    try {
      final mine = await MySentenceStore.load(accountId);
      if (mine.isNotEmpty) {
        candidates = await reminderCandidatesFor(accountId, mine);
      }
    } catch (_) {
      // 못 읽으면 지난번에 적어 둔 문장을 그대로 쓴다.
    }
    await applyPracticeReminder(settings: settings, candidates: candidates);
  } catch (e) {
    AppLogger.e('[Reminder] 앱 시작 때 다시 예약 실패', error: e);
  }
}

/// 내 문장에 이 기기의 연습 기록을 붙여 알림 후보로 만든다.
/// 기록을 못 읽으면 횟수 0으로 둔다('덜 익숙한 순'은 저장한 차례가 된다).
Future<List<ReminderCandidate>> reminderCandidatesFor(
  String accountId,
  List<DefaultConversationSentence> sentences,
) async {
  Map<String, SentenceActivity> activity = const {};
  try {
    activity = await SentenceActivityStore.loadAll(accountId);
  } catch (e) {
    AppLogger.e('[Reminder] 연습 기록 읽기 실패', error: e);
  }
  return [
    for (final s in sentences)
      ReminderCandidate(
        text: s.text,
        id: s.id,
        practiceCount: activity[s.id]?.practiceCount ?? 0,
        lastPracticedAt: activity[s.id]?.lastPracticedAt,
      ),
  ];
}
