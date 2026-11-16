import 'package:flutter/material.dart';

/// 글쓰기 화면에서 꼭 봐야 하는 안내를 띄운다.
///
/// 이 화면들에서는 토스트(SnackBar)가 실제 기기에서 그려지지 않았다(5차 304~306).
/// 그래서 '올리지 못했다', '로그인이 필요하다'처럼 못 보면 사용자가 멈추는 안내는
/// 토스트 대신 창으로 띄운다. 같은 화면에서 '올리는 중' 창은 잘 떠서,
/// 창은 뜨는 것이 확인된 방법이다.
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
