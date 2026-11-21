// 예문을 몇 개 받을지 고르는 시트(5차 474).
//
// 추가 시트와 고치기 창이 같은 창을 쓴다. 전에는 고치기 창에만 있어서,
// 추가 시트에서는 몇 개가 오는지도 상한이 몇 개인지도 알 수 없었다
// (사용자 지적: "예문 채우기 개수 제한 안보이는데").

import 'package:flutter/cupertino.dart';

/// [room]만큼까지 고르게 한다. 고르지 않으면 null.
/// [already]는 지금 들고 있는 예문 수 - 상한과 함께 적어 준다.
/// [maxPerWord]는 구독 단계의 낱말당 상한, [remainingToday]는 오늘 더 만들 수
/// 있는 예문 수. 둘 다 서버가 알려 준 값이다.
///
/// [maxPerWord]가 null이면 상한을 아직 모르는 것이라 개수를 말하지 않는다.
/// 전에는 모를 때 상수 10을 적어서, 무료 단계(3개)인데도 '10개까지 둘 수
/// 있어요'라고 틀린 수를 단언했다(5차 507).
/// 남은 수를 어떻게 적을지(5차 532).
///
/// [remainingToday]에는 패롯으로 사 둔 몫이 이미 더해져 있다. 그걸 통째로
/// '오늘 N개'라고 적으면 거짓말이 된다 - 산 몫은 내일도 쓸 수 있다.
/// 그래서 둘을 나눠 적는다.
String exampleRoomLine(int? remainingToday, int? credits) {
  if (remainingToday == null) return '';
  final bought = credits ?? 0;
  if (bought <= 0) return ' 오늘 $remainingToday개 더 만들 수 있어요.';
  final today = remainingToday - bought;
  if (today <= 0) return ' 사 둔 $bought개를 쓸 수 있어요.';
  return ' 오늘 $today개와 사 둔 $bought개를 쓸 수 있어요.';
}

Future<int?> askExampleCount(
  BuildContext context, {
  required int room,
  required int already,
  int? maxPerWord,
  int? remainingToday,
  int? exampleCredits,
}) {
  var most = room < 5 ? room : 5;
  if (remainingToday != null && remainingToday < most) most = remainingToday;
  final choices = [for (var n = 1; n <= most; n++) n];
  final hasLine = already == 0 ? '' : '지금 $already개 있어요.';
  final capLine = maxPerWord == null
      ? ''
      : (already == 0
          ? '$maxPerWord개까지 둘 수 있어요.'
          : ' $maxPerWord개까지 둘 수 있어요.');
  final todayLine = exampleRoomLine(remainingToday, exampleCredits);
  return showCupertinoModalPopup<int>(
    context: context,
    builder: (sheetContext) => CupertinoActionSheet(
      title: const Text('예문 몇 개를 만들까요?'),
      message: Text(('$hasLine$capLine$todayLine').trim()),
      actions: [
        for (final n in choices)
          CupertinoActionSheetAction(
            key: ValueKey('example-count-$n'),
            onPressed: () => Navigator.of(sheetContext).pop(n),
            child: Text('$n개'),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.of(sheetContext).pop(),
        child: const Text('취소'),
      ),
    ),
  );
}
