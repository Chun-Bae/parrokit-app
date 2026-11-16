import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/utils/korean_josa.dart';

/// 댓글을 지우기 전에 한 번 묻는다(5차 399).
///
/// 게시판만 물었고 질문·투표는 '지우기'를 누르는 순간 바로 지웠다. 되돌릴 수
/// 없다고 적어 두고 두 화면은 묻지도 않았다. 세 화면이 같은 창을 쓴다.
Future<bool> confirmDeleteComment(BuildContext context) =>
    _confirmDelete(context, kind: '댓글', keyName: 'delete-comment-confirm');

/// 글(질문·투표)을 지우기 전에 한 번 묻는다(5차 400).
///
/// 댓글과 마찬가지로 게시판만 물었다. 질문·투표는 '지우기'를 누르는 순간
/// 글이 사라졌다. [kind]는 '글'·'질문'·'투표'.
Future<bool> confirmDeletePost(BuildContext context, {required String kind}) =>
    _confirmDelete(context, kind: kind, keyName: 'delete-post-confirm');

Future<bool> _confirmDelete(
  BuildContext context, {
  required String kind,
  required String keyName,
}) async {
  final colorScheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: ValueKey(keyName),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: Text('$kind 지우기',
          style: const TextStyle(fontWeight: FontWeight.bold)),
      // 보관함 지우기 확인과 같은 말로(5차).
      content: Text('이 ${eulReul(kind)} 지울까요?\n지우면 되돌릴 수 없어요.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child:
              Text('취소', style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ),
        TextButton(
          key: ValueKey('$keyName-ok'),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('지우기',
              style: TextStyle(
                  color: context.tokens.danger, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
  return confirmed == true;
}
