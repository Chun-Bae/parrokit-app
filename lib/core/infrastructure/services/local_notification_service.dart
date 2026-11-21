import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:parrokit/core/app/router/app_router.dart';
import 'package:parrokit/core/content/practice_reminder.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/sentence_collection_preview.dart'
    show showSentenceDetails;

/// 연습 알림에 붙이는 표. 눌렀을 때 어디로 갈지 가린다(5차 378).
const String practiceReminderPayload = 'practice_reminder';

/// 문장 id를 실은 표. 누르면 그 문장의 시트까지 연다(5차 508).
///
/// 예전 표(`practice_reminder`)도 그대로 받는다. 며칠 전에 깔아 둔 알림이
/// 아직 기기에 남아 있기 때문이다.
String practiceReminderPayloadFor(String sentenceId) =>
    sentenceId.trim().isEmpty
        ? practiceReminderPayload
        : '$practiceReminderPayload:${sentenceId.trim()}';

/// 표에 실린 문장 id. 없으면 null.
String? reminderSentenceIdFor(String? payload) {
  if (payload == null) return null;
  const prefix = '$practiceReminderPayload:';
  if (!payload.startsWith(prefix)) return null;
  final id = payload.substring(prefix.length).trim();
  return id.isEmpty ? null : id;
}

/// 연습 알림을 눌렀을 때 열 화면. 그 밖의 표는 null(그냥 앱만 연다).
///
/// 전에는 표가 없어서 눌러도 보던 화면이 그대로였다. 연습하라고 부른
/// 알림이니 앵무새가 있는 홈으로 간다.
String? reminderRouteFor(String? payload) =>
    payload == practiceReminderPayload ||
            reminderSentenceIdFor(payload) != null
        ? AppRoutes.dashboardPath
        : null;

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

  /// 알림을 눌렀을 때 화면을 옮기는 길. 테스트에서 바꿔 끼운다.
  @visibleForTesting
  static void Function(String route) go = _goWithRouter;

  static void _goWithRouter(String route) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    context.go(route);
  }

  /// 알림에 실린 문장의 시트를 여는 길. 테스트에서 바꿔 끼운다.
  @visibleForTesting
  static Future<void> Function(String sentenceId) openSentence =
      _openSentenceSheet;

  /// 알림을 눌렀을 때. 표가 연습 알림이면 홈으로 간다(5차 378).
  ///
  /// 표에 문장 id가 실려 있으면 그 문장의 시트까지 연다(5차 508). 홈으로
  /// 먼저 옮기는 것은 그대로다. 시트를 닫으면 연습하던 자리가 나온다.
  static void handleTap(String? payload) {
    final route = reminderRouteFor(payload);
    if (route == null) return;
    go(route);
    final sentenceId = reminderSentenceIdFor(payload);
    if (sentenceId == null) return;
    unawaited(openSentence(sentenceId));
  }

  /// 홈이 올라온 뒤에 그 문장의 시트를 연다. 문장을 못 찾으면 아무것도
  /// 하지 않는다(지운 문장일 수 있다).
  static Future<void> _openSentenceSheet(String sentenceId) async {
    try {
      final context = rootNavigatorKey.currentContext;
      if (context == null) return;
      final accountId =
          context.read<UserProvider?>()?.currentUser?.id ?? 'guest';
      final mine = await MySentenceStore.load(accountId);
      DefaultConversationSentence? found;
      for (final s in mine) {
        if (s.id == sentenceId) {
          found = s;
          break;
        }
      }
      if (found == null) return;
      final sentence = found;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx == null) return;
        unawaited(showSentenceDetails(
          ctx,
          sentence: sentence,
          accountId: accountId,
        ));
      });
    } catch (e) {
      AppLogger.w('[Reminder] 문장 시트를 열지 못했어요: $e');
    }
  }

  /// 알림을 눌러서 앱이 켜진 경우. 화면이 올라온 뒤에 옮긴다.
  static Future<void> handleLaunchByNotification() async {
    try {
      await init();
      final details = await plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return;
      handleTap(details?.notificationResponse?.payload);
    } catch (error) {
      AppLogger.w('[Reminder] 알림으로 열렸는지 보지 못했어요: $error');
    }
  }

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await plugin.initialize(
      onDidReceiveNotificationResponse: (response) =>
          handleTap(response.payload),
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
        return await ios?.requestPermissions(
                alert: true, badge: true, sound: true) ??
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
  /// [lines]는 같은 자리의 문장, [sentenceIds]는 같은 자리의 문장 id다.
  /// id가 모자라면 그 자리는 id 없이 깐다(예전처럼 홈까지만 간다).
  static Future<void> schedulePracticeReminders({
    required List<DateTime> times,
    required List<String> lines,
    List<String> sentenceIds = const [],
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
      final content = reminderContent(i < lines.length ? lines[i] : null);
      try {
        await plugin.zonedSchedule(
          practiceIdBase + i,
          content.title,
          content.body,
          tz.TZDateTime.from(times[i], tz.UTC),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: practiceReminderPayloadFor(
              i < sentenceIds.length ? sentenceIds[i] : ''),
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
    await PracticeReminder.saveLineIds(const []);
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
  final ordered = orderReminderCandidates(chosen, settings.pick, random: random);
  final picked = pickReminderCandidates(ordered, times.length);
  final lines = [for (final c in picked) c.text];
  final ids = [for (final c in picked) c.id];
  await PracticeReminder.saveLines(lines);
  await PracticeReminder.saveLineIds(ids);
  await LocalNotificationService.schedulePracticeReminders(
      times: times, lines: lines, sentenceIds: ids);
}

/// 앱을 열 때 호출한다. 꺼져 있으면 아무것도 하지 않는다.
///
/// 며칠치만 예약해 두므로 열 때마다 다시 채워야 알림이 끊기지 않는다.
/// 문장을 못 읽어도(오프라인·로그인 전) 적어 둔 문장으로 예약한다.
///
/// 간격으로 받을 때는 다시 예약하는 이 순간부터 오늘치를 다시 센다
/// (reminderTimes). 그래서 앱을 쓴 뒤에는 그만큼 뒤로 밀린다(5차 505).
Future<void> refreshPracticeReminder(String accountId) async {
  try {
    final settings = await PracticeReminder.load();
    if (!settings.enabled) return;
    await applyPracticeReminder(
      settings: settings,
      candidates: await _reminderCandidates(accountId),
    );
  } catch (e) {
    AppLogger.e('[Reminder] 앱 시작 때 다시 예약 실패', error: e);
  }
}

/// 오늘 받을 크래커를 다 받았을 때 부른다. 오늘 남은 알림을 지우고 내일부터
/// 다시 깐다(5차 505).
///
/// 예약 알림은 며칠 전에 미리 깔아 두므로 '오늘은 이미 다 받았다'를 알 수
/// 없다. 그대로 두면 더 줄 것이 없는데도 '따라 말하면 크래커를 받아요'라고
/// 부른다. 다 받은 그 순간에 다시 깔아서 못 지킬 약속을 지운다.
Future<void> skipTodayPracticeReminders(String accountId) async {
  try {
    final settings = await PracticeReminder.load();
    if (!settings.enabled) return;
    final now = DateTime.now();
    // 오늘 창이 끝난 시각으로 보고 예약하면 오늘치는 모두 빠진다.
    final afterToday = DateTime(
            now.year, now.month, now.day, settings.endHour, settings.endMinute)
        .add(const Duration(minutes: 1));
    await applyPracticeReminder(
      settings: settings,
      candidates: await _reminderCandidates(accountId),
      now: afterToday.isAfter(now) ? afterToday : now,
    );
  } catch (e) {
    AppLogger.e('[Reminder] 오늘 알림 건너뛰기 실패', error: e);
  }
}

/// 알림에 띄울 후보. 문장을 못 읽으면 지난번에 적어 둔 문장을 그대로 쓴다.
Future<List<ReminderCandidate>> _reminderCandidates(String accountId) async {
  final savedLines = await PracticeReminder.loadLines();
  final savedIds = await PracticeReminder.loadLineIds();
  var candidates = [
    for (var i = 0; i < savedLines.length; i++)
      ReminderCandidate(
        text: savedLines[i],
        id: i < savedIds.length ? savedIds[i] : '',
      ),
  ];
  try {
    final mine = await MySentenceStore.load(accountId);
    if (mine.isNotEmpty) {
      candidates = await reminderCandidatesFor(accountId, mine);
    }
  } catch (_) {
    // 못 읽으면 지난번에 적어 둔 문장을 그대로 쓴다.
  }
  return candidates;
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
