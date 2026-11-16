import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/practice_reminder.dart';
import 'package:parrokit/core/infrastructure/services/local_notification_service.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';
import 'package:parrokit/core/shared/widgets/app_time_picker_sheet.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/features/settings/more/presentation/widgets/leading_icon.dart';
import 'package:parrokit/features/settings/more/presentation/widgets/reminder_sentence_picker.dart';

/// 더보기 > 앱의 '연습 알림' 줄. 켜면 정한 시각에 기기가 알려 준다.
/// 서버를 쓰지 않으므로 비용이 들지 않고 오프라인에서도 울린다.
///
/// 줄에는 지금 설정만 한 줄로 보여 주고, 누르면 설정 시트를 연다. 전에는
/// 옵션 네 줄이 더보기 목록 안에 그대로 펼쳐져 있어 지저분했다(5차, 사용자 의견).
class PracticeReminderTile extends StatefulWidget {
  const PracticeReminderTile({super.key});

  @override
  State<PracticeReminderTile> createState() => _PracticeReminderTileState();
}

class _PracticeReminderTileState extends State<PracticeReminderTile> {
  PracticeReminderSettings? _settings;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await PracticeReminder.load();
    if (!mounted) return;
    setState(() => _settings = loaded);
  }

  Future<void> _openSettings() async {
    final settings = _settings;
    if (settings == null) return;
    await showAppSheet<void>(
      context: context,
      fullHeight: false,
      builder: (context) => const PracticeReminderSheet(),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _toggleFromTile(bool on) async {
    final current = _settings;
    if (current == null) return;
    setState(() => _busy = true);
    final next = await applyReminderToggle(
      context: context,
      current: current,
      on: on,
    );
    if (!mounted) return;
    setState(() {
      _settings = next;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final cs = Theme.of(context).colorScheme;
    // 같은 '앱' 칸의 테마·새 클립 화면 줄과 똑같이 그린다. 예전에는 이 줄만
    // ListTile이라 아이콘과 글자가 오른쪽으로 더 들어가 있었다(5차).
    return InkWell(
      key: const ValueKey('practice-reminder-tile'),
      onTap: settings == null || _busy ? null : _openSettings,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            const LeadingIcon(icon: Icons.alarm_rounded),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('연습 알림',
                      style: context.texts.bodyLarge
                          .copyWith(fontWeight: FontWeight.w700)),
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      settings == null
                          ? '불러오는 중…'
                          : settings.enabled
                              ? '${settings.whenLabel} ${settings.pick.hint}'
                              : '정한 시각에 따라 말할 문장을 알려 줘요',
                      style: context.texts.bodySmall
                          .copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              key: const ValueKey('practice-reminder-switch'),
              value: settings?.enabled ?? false,
              onChanged: settings == null || _busy ? null : _toggleFromTile,
            ),
          ],
        ),
      ),
    );
  }
}

/// 알림을 켜고 끈다. 켤 때는 휴대폰 알림 권한을 묻고, 거절하면 켜지 않는다.
/// 바뀐 설정을 돌려준다.
Future<PracticeReminderSettings> applyReminderToggle({
  required BuildContext context,
  required PracticeReminderSettings current,
  required bool on,
}) async {
  final accountId = context.read<UserProvider>().currentUser?.id ?? 'guest';
  if (!on) {
    final next = current.copyWith(enabled: false);
    await PracticeReminder.save(next);
    await applyPracticeReminder(settings: next, candidates: const []);
    return next;
  }
  final allowed = await LocalNotificationService.requestPermission();
  if (!allowed) {
    showToast('휴대폰 설정에서 패로킷 알림을 켜야 받을 수 있어요.');
    return current;
  }
  final next = current.copyWith(enabled: true);
  await PracticeReminder.save(next);
  await applyPracticeReminder(
      settings: next, candidates: await reminderCandidates(accountId));
  return next;
}

/// 알림에 띄울 문장 후보. 못 읽어도 알림은 기본 문구로 울린다.
Future<List<ReminderCandidate>> reminderCandidates(String accountId) async {
  try {
    final mine = await MySentenceStore.load(accountId);
    return reminderCandidatesFor(accountId, mine);
  } catch (_) {
    return const [];
  }
}

/// 연습 알림 설정 시트. 더보기 줄을 누르면 열린다.
class PracticeReminderSheet extends StatefulWidget {
  const PracticeReminderSheet({super.key});

  @override
  State<PracticeReminderSheet> createState() => _PracticeReminderSheetState();
}

class _PracticeReminderSheetState extends State<PracticeReminderSheet> {
  PracticeReminderSettings? _settings;
  Set<String> _chosen = const {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await PracticeReminder.load();
    final chosen = await PracticeReminder.loadChosen();
    if (!mounted) return;
    setState(() {
      _settings = loaded;
      _chosen = chosen;
    });
  }

  String get _accountId =>
      context.read<UserProvider>().currentUser?.id ?? 'guest';

  Future<List<ReminderCandidate>> _candidates() => reminderCandidates(_accountId);

  Future<void> _apply(PracticeReminderSettings next) async {
    setState(() {
      _settings = next;
      _busy = true;
    });
    await PracticeReminder.save(next);
    final candidates =
        next.enabled ? await _candidates() : const <ReminderCandidate>[];
    await applyPracticeReminder(settings: next, candidates: candidates);
    if (!mounted) return;
    setState(() => _busy = false);
  }

  Future<void> _toggle(bool on) async {
    final current = _settings;
    if (current == null) return;
    setState(() => _busy = true);
    final next =
        await applyReminderToggle(context: context, current: current, on: on);
    if (!mounted) return;
    setState(() {
      _settings = next;
      _busy = false;
    });
  }

  Future<void> _pickTime() async {
    final current = _settings;
    if (current == null) return;
    final picked = await showAppTimePickerSheet(
      context: context,
      initial: TimeOfDay(hour: current.hour, minute: current.minute),
      title: current.repeats ? '알림을 받기 시작할 시각' : '알림 받을 시각',
    );
    if (!mounted || picked == null) return;
    await _apply(
        current.copyWith(hour: picked.hour, minute: picked.minute));
  }

  Future<void> _pickInterval(int minutes) async {
    final current = _settings;
    if (current == null || minutes == current.intervalMinutes) return;
    await _apply(current.copyWith(intervalMinutes: minutes));
  }

  /// 간격으로 받을 때 그날 그만 받을 시각.
  Future<void> _pickEndHour() async {
    final current = _settings;
    if (current == null) return;
    final picked = await showAppTimePickerSheet(
      context: context,
      initial: TimeOfDay(hour: current.endHour, minute: current.endMinute),
      title: '알림을 그만 받을 시각',
    );
    if (!mounted || picked == null) return;
    await _apply(
        current.copyWith(endHour: picked.hour, endMinute: picked.minute));
  }

  /// 알림에 쓸 문장 고르기.
  Future<void> _pickSentences() async {
    setState(() => _busy = true);
    List<DefaultConversationSentence> sentences = const [];
    try {
      sentences = await MySentenceStore.load(_accountId);
    } catch (_) {
      // 못 읽으면 빈 목록으로 연다(창이 그 사정을 알린다).
    }
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    final picked = await showReminderSentencePicker(
      context: context,
      sentences: sentences,
      chosen: _chosen,
    );
    if (!mounted || picked == null) return;
    setState(() => _chosen = picked);
    await PracticeReminder.saveChosen(picked);
    final current = _settings;
    // 고른 문장이 바로 반영되게 다시 예약한다.
    if (current != null && current.enabled) await _apply(current);
  }

  Future<void> _pickMode(ReminderPick pick) async {
    final current = _settings;
    if (current == null || pick == current.pick) return;
    await _apply(current.copyWith(pick: pick));
  }


  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final cs = Theme.of(context).colorScheme;
    if (settings == null) {
      return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('연습 알림',
                      style: context.texts.titleLarge
                          .copyWith(fontWeight: FontWeight.w800)),
                ),
                Switch(
                  key: const ValueKey('practice-reminder-sheet-switch'),
                  value: settings.enabled,
                  onChanged: _busy ? null : _toggle,
                ),
              ],
            ),
            Text(
              settings.enabled
                  ? '${settings.whenLabel} ${settings.pick.hint}'
                  : '켜면 정한 때에 따라 말할 문장을 알려 줘요',
              style:
                  context.texts.bodySmall.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Opacity(
              opacity: settings.enabled ? 1 : 0.45,
              child: IgnorePointer(
                ignoring: !settings.enabled,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Column(
                    children: [
                      _ReminderOptionRow(
                        label: settings.repeats ? '받는 때' : '받는 시각',
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          _ReminderValue(
                            valueKey: const ValueKey('practice-reminder-time'),
                            text: settings.label,
                            onTap: _busy ? null : _pickTime,
                          ),
                          if (settings.repeats) ...[
                            Text(' ~ ',
                                style: context.texts.bodyMedium
                                    .copyWith(color: cs.onSurfaceVariant)),
                            _ReminderValue(
                              valueKey: const ValueKey('practice-reminder-end'),
                              text: settings.endLabel,
                              onTap: _busy ? null : _pickEndHour,
                            ),
                          ],
                        ]),
                      ),
                      _ReminderOptionRow(
                        label: '얼마나 자주',
                        child: PopupMenuButton<int>(
                          key: const ValueKey('practice-reminder-interval'),
                          enabled: !_busy,
                          initialValue: settings.intervalMinutes,
                          tooltip: '알림 간격',
                          onSelected: _pickInterval,
                          itemBuilder: (context) => [
                            for (final minutes in reminderIntervalChoices)
                              PopupMenuItem<int>(
                                value: minutes,
                                child: Text(reminderIntervalLabel(minutes)),
                              ),
                          ],
                          child: _ReminderValue(
                            text:
                                reminderIntervalLabel(settings.intervalMinutes),
                            trailingArrow: true,
                          ),
                        ),
                      ),
                      _ReminderOptionRow(
                        label: '어떤 문장',
                        child: _ReminderValue(
                          valueKey:
                              const ValueKey('practice-reminder-sentences'),
                          text: _chosen.isEmpty
                              ? '내 문장 전부'
                              : '고른 ${_chosen.length}개',
                          onTap: _busy ? null : _pickSentences,
                        ),
                      ),
                      _ReminderOptionRow(
                        label: '어떤 차례로',
                        last: true,
                        child: PopupMenuButton<ReminderPick>(
                          key: const ValueKey('practice-reminder-pick'),
                          enabled: !_busy,
                          initialValue: settings.pick,
                          tooltip: '문장 고르는 방식',
                          onSelected: _pickMode,
                          itemBuilder: (context) => [
                            for (final pick in ReminderPick.values)
                              PopupMenuItem<ReminderPick>(
                                value: pick,
                                child: Text(pick.label),
                              ),
                          ],
                          child: _ReminderValue(
                            text: settings.pick.label,
                            trailingArrow: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('practice-reminder-done'),
                onPressed: () => Navigator.of(context).pop(),
                style:
                    FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: const Text('닫기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 연습 알림 설정 한 줄: 왼쪽에 이름, 오른쪽에 지금 값.
class _ReminderOptionRow extends StatelessWidget {
  const _ReminderOptionRow({
    required this.label,
    required this.child,
    this.last = false,
  });

  final String label;
  final Widget child;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.4)))),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: context.texts.bodyMedium
                    .copyWith(color: cs.onSurfaceVariant)),
          ),
          child,
        ],
      ),
    );
  }
}

/// 오른쪽에 놓이는 값. 누를 수 있으면 알약으로 보인다.
class _ReminderValue extends StatelessWidget {
  const _ReminderValue({
    required this.text,
    this.onTap,
    this.trailingArrow = false,
    this.valueKey,
  });

  final String text;
  final VoidCallback? onTap;
  final bool trailingArrow;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(text,
            style: context.texts.bodyMedium
                .copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
        if (trailingArrow)
          Icon(Icons.keyboard_arrow_down, size: 18, color: cs.primary),
      ]),
    );
    if (onTap == null) return content;
    return InkWell(
      key: valueKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: content,
    );
  }
}
