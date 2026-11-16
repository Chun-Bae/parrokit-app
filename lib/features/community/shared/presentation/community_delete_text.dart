import 'package:parrokit/core/shared/utils/korean_josa.dart';

/// 커뮤니티에서 지운 뒤 하는 말(5차 327).
///
/// 전에는 게시판·질문·투표 세 화면에 '댓글이 삭제되었습니다.'와
/// '삭제에 실패했습니다.'가 각각 적혀 있었다. 한 곳만 다듬으면 나머지는
/// 예전 말로 남고, 말투도 앱의 다른 곳('~어요')과 달랐다.

/// 댓글(답변)을 지웠을 때.
const String commentDeletedMessage = '댓글을 지웠어요.';

/// 지우지 못했을 때. 글·댓글 모두 같은 말을 쓴다.
const String deleteFailedMessage = '지우지 못했어요. 잠시 뒤 다시 해 주세요.';

/// 글을 지웠을 때. [kind]는 '글'·'질문'·'투표'.
String postDeletedMessage(String kind) => '${eulReul(kind)} 지웠어요.';
