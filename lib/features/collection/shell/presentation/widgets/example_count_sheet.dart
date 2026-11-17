// 예문을 몇 개 받을지 고르는 시트(5차 474).
//
// 추가 시트와 고치기 창이 같은 창을 쓴다. 전에는 고치기 창에만 있어서,
// 추가 시트에서는 몇 개가 오는지도 상한이 몇 개인지도 알 수 없었다
// (사용자 지적: "예문 채우기 개수 제한 안보이는데").

import 'package:flutter/cupertino.dart';
import 'package:parrokit/core/content/my_word_store.dart';

/// [room]만큼까지 고르게 한다. 고르지 않으면 null.
/// [already]는 지금 들고 있는 예문 수 - 상한과 함께 적어 준다.
Future<int?> askExampleCount(
  BuildContext context, {
  required int room,
  required int already,
}) {
  final choices = [for (var n = 1; n <= room && n <= 5; n++) n];
  return showCupertinoModalPopup<int>(
    context: context,
    builder: (sheetContext) => CupertinoActionSheet(
      title: const Text('예문 몇 개를 만들까요?'),
      message: Text(already == 0
          ? '$examplesMaxCount개까지 둘 수 있어요.'
          : '지금 $already개 있어요. $examplesMaxCount개까지 둘 수 있어요.'),
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
