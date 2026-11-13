import 'package:flutter/material.dart';

import 'package:parrokit/core/shared/theme/app_tokens.dart';

/// 쓰던 내용을 버리고 나갈지 묻는다. 버리면 true.
Future<bool> confirmDiscardDraft(BuildContext context) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('쓰던 내용을 버릴까요?'),
      content: const Text('지금 나가면 쓴 내용이 사라져요.'),
      actions: [
        TextButton(
          key: const ValueKey('draft-keep'),
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('계속 쓰기'),
        ),
        TextButton(
          key: const ValueKey('draft-discard'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text('버리기',
              style: TextStyle(color: dialogContext.tokens.danger)),
        ),
      ],
    ),
  );
  return discard ?? false;
}

/// 커뮤니티 글쓰기 화면(게시판·질문·투표)을 감싼다. 쓰던 내용이 있으면 닫기(X)·
/// 뒤로·밀어서 닫기 때 한 번 묻는다(5차). 예전엔 X 한 번에 쓰던 글이 사라졌다.
///
/// 저장에 성공해 닫을 때는 Navigator.pop을 바로 부른다(이 확인을 거치지 않는다).
class DraftPopScope extends StatelessWidget {
  const DraftPopScope({super.key, required this.hasDraft, required this.child});

  final bool hasDraft;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !hasDraft,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await confirmDiscardDraft(context)) navigator.pop();
      },
      child: child,
    );
  }
}
