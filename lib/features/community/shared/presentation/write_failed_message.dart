import 'package:flutter/material.dart';

/// 글을 올리지 못했을 때 띄우는 창.
///
/// 가벼운 안내(빠진 칸, 개수 한도)는 토스트로 충분하지만, '올리지 못했어요'와
/// '로그인하고 다시 해 주세요.'는 누른 일이 실패했다는 뜻이다. 2.5초 토스트를
/// 놓치면 글이 올라간 줄 알고 화면을 닫게 된다. 그래서 이것만 창으로 띄운다.
Future<void> showWriteFailedMessage(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey('write-failed-dialog'),
      content: Text(message),
      actions: [
        TextButton(
          key: const ValueKey('write-failed-ok'),
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}
