// 지워졌거나 못 여는 글을 열었을 때의 화면(5차).
//
// 게시판은 제목이 '게시글을 찾을 수 없습니다.'인 가짜 글을 만들어 보통 글처럼
// 그렸고(공감·스크랩·댓글칸까지 살아 있었다), 질문·투표는 글자 한 줄만
// 보여 줬다. 투표는 그 화면에 위 바가 없어 뒤로 갈 길도 없었다.
import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/utils/korean_josa.dart';
import 'package:parrokit/core/shared/widgets/app_empty_state.dart';

/// 글 종류에 맞는 이름. 알림·목록에서 쓰는 말과 같게.
String missingPostWord(String boardType) {
  switch (boardType) {
    case 'question':
      return '질문';
    case 'vote':
      return '투표';
    default:
      return '글';
  }
}

// '투표을'이 되지 않게 받침에 맞춰 조사를 고른다.
String missingPostTitle(String boardType) =>
    '${eulReul(missingPostWord(boardType))} 볼 수 없어요';

const String missingPostDescription = '지워졌거나 비공개로 바뀌었어요.';
const String missingPostBackLabel = '뒤로 가기';

/// 게시판·질문·투표 상세가 글을 못 찾았을 때 그리는 화면.
class MissingPostView extends StatelessWidget {
  const MissingPostView({
    super.key,
    required this.boardType,
    required this.appBarTitle,
  });

  /// 'board' | 'question' | 'vote'
  final String boardType;

  /// 위 바에 쓰는 화면 이름('게시판'·'질문'·'투표').
  final String appBarTitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: '뒤로',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 24),
        ),
        title: Text(
          appBarTitle,
          style:
              context.texts.titleMedium.copyWith(color: colorScheme.onSurface),
        ),
      ),
      body: AppEmptyState(
        key: const ValueKey('missing-post'),
        icon: Icons.search_off_rounded,
        title: missingPostTitle(boardType),
        description: missingPostDescription,
        actionLabel: missingPostBackLabel,
        onAction: () => Navigator.maybePop(context),
      ),
    );
  }
}
