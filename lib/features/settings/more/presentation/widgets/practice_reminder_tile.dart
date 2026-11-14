import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/practice_reminder.dart';
import 'package:parrokit/core/infrastructure/services/local_notification_service.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';

/// 더보기 > 앱의 '연습 알림' 줄. 켜면 정한 시각에 기기가 알려 준다.
/// 서버를 쓰지 않으므로 비용이 들지 않고 오프라인에서도 울린다.
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

  String get _accountId =>
      context.read<UserProvider>().currentUser?.id ?? 'guest';

  /// 알림에 띄울 문장 후보. 못 읽어도 알림은 기본 문구로 울린다.
  Future<List<ReminderCandidate>> _candidates() async {
    try {
      final mine = await MySentenceStore.load(_accountId);
      return reminderCandidatesFor(_accountId, mine);
    } catch (_) {
      return const [];
    }
  }

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
    if (!on) {
      await _apply(current.copyWith(enabled: false));
      return;
    }
    final allowed = await LocalNotificationService.requestPermission();
    if (!mounted) return;
    if (!allowed) {
      showToast('휴대폰 설정에서 패로킷 알림을 켜야 받을 수 있어요.');
      return;
    }
    await _apply(current.copyWith(enabled: true));
  }

  Future<void> _pickTime() async {
    final current = _settings;
    if (current == null) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: '알림 받을 시각',
    );
    if (!mounted || picked == null) return;
    await _apply(
        current.copyWith(hour: picked.hour, minute: picked.minute));
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
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.alarm_rounded, size: 20, color: cs.onSurface),
          ),
          title: const Text('연습 알림',
              style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            settings == null
                ? '불러오는 중…'
                : settings.enabled
                    ? '${settings.label}에 ${settings.pick.hint}'
                    : '정한 시각에 따라 말할 문장을 알려 줘요',
            style: context.texts.bodySmall
                .copyWith(color: cs.onSurfaceVariant),
          ),
          trailing: Switch(
            key: const ValueKey('practice-reminder-switch'),
            value: settings?.enabled ?? false,
            onChanged: settings == null || _busy ? null : _toggle,
          ),
        ),
        if (settings != null && settings.enabled)
          Padding(
            padding: const EdgeInsets.only(left: 56, right: 4, bottom: 8),
            child: Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  key: const ValueKey('practice-reminder-time'),
                  onPressed: _busy ? null : _pickTime,
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text('${settings.label}에 받기'),
                ),
                PopupMenuButton<ReminderPick>(
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swap_vert_rounded,
                            size: 18, color: cs.primary),
                        const SizedBox(width: 6),
                        Text(settings.pick.label,
                            style: TextStyle(
                                color: cs.primary,
                                fontWeight: FontWeight.w600)),
                        Icon(Icons.keyboard_arrow_down,
                            size: 18, color: cs.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
