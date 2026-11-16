// 투표가 막히면 까닭을 알린다(5차 381).
//
// 이미 투표했거나 글이 지워졌으면 고른 것이 조용히 되돌아갔다. 목록 화면은
// 아무 말도 하지 않았고, 투표 상세 화면은 결과를 보지도 않았다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/shared/presentation/community_error_text.dart';
import 'package:parrokit/features/community/vote/presentation/vote_confirm_text.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('막혔을 때 쓸 말이 있다', () {
    expect(voteFailedText, contains('투표하지 못했어요'));
    // 까닭을 받았으면 그 말을 먼저 쓴다.
    expect(communityErrorText(CommunityJob.vote, Exception('x')),
        '투표하지 못했어요. 잠시 뒤 다시 해 주세요.');
  });

  test('목록 화면은 실패를 알린다', () {
    final code =
        _read('lib/features/community/vote/presentation/vote_screen.dart');
    expect(code, contains('showToast(provider.errorMessage ?? voteFailedText)'));
    // 전에는 성공이 아니면 그냥 돌아갔다.
    expect(code.contains('if (!mounted || !success) return;'), isFalse);
  });

  test('투표 상세도 결과를 보고 알린다', () {
    final code =
        _read('lib/features/community/vote/presentation/vote_view_screen.dart');
    expect(code, contains('await provider.votePost('));
    expect(code, contains('showToast(provider.errorMessage ?? voteFailedText)'));
  });
}
