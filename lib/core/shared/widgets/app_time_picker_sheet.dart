import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';

/// 시각 고르기 시트. 돌리는 휠(아이폰 알람과 같은 모양)로 고른다.
///
/// Material의 showTimePicker는 시계판·숫자 입력 전환이 있는 큰 대화상자라
/// 앱의 다른 시트와 따로 놀았다(5차, 사용자 의견). 고른 시각을 돌려주고,
/// 닫기만 하면 null.
Future<TimeOfDay?> showAppTimePickerSheet({
  required BuildContext context,
  required TimeOfDay initial,
  required String title,
  int minuteInterval = 1,
}) {
  return showAppSheet<TimeOfDay>(
    context: context,
    fullHeight: false,
    builder: (context) => _AppTimePickerSheet(
      initial: initial,
      title: title,
      minuteInterval: minuteInterval,
    ),
  );
}

class _AppTimePickerSheet extends StatefulWidget {
  const _AppTimePickerSheet({
    required this.initial,
    required this.title,
    required this.minuteInterval,
  });

  final TimeOfDay initial;
  final String title;
  final int minuteInterval;

  @override
  State<_AppTimePickerSheet> createState() => _AppTimePickerSheetState();
}

class _AppTimePickerSheetState extends State<_AppTimePickerSheet> {
  late TimeOfDay _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // 휠은 '오늘 그 시각'을 보여 주면 된다(날짜는 쓰지 않는다).
    final today = DateTime.now();
    final initialDateTime = DateTime(today.year, today.month, today.day,
        widget.initial.hour, widget.initial.minute);
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.title,
                      style: context.texts.titleLarge
                          .copyWith(fontWeight: FontWeight.w800)),
                ),
                Text(_label(_value),
                    style: context.texts.titleMedium.copyWith(
                        color: cs.primary, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          SizedBox(
            height: 196,
            child: CupertinoTheme(
              // 휠 글자는 앱 테마(다크 포함)를 따라야 한다.
              data: CupertinoThemeData(
                brightness: Theme.of(context).brightness,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: context.texts.titleLarge
                      .copyWith(color: cs.onSurface, fontSize: 21),
                ),
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: false,
                minuteInterval: widget.minuteInterval,
                initialDateTime: initialDateTime,
                onDateTimeChanged: (at) => setState(
                    () => _value = TimeOfDay(hour: at.hour, minute: at.minute)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm,
                AppSpacing.lg, AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('time-sheet-cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg)),
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    key: const ValueKey('time-sheet-done'),
                    onPressed: () => Navigator.of(context).pop(_value),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg)),
                    ),
                    child: const Text('이 시각으로'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _label(TimeOfDay at) {
    final h12 = at.hour % 12 == 0 ? 12 : at.hour % 12;
    return '${at.hour >= 12 ? '오후' : '오전'} $h12:${at.minute.toString().padLeft(2, '0')}';
  }
}
