// 커뮤니티 실패 안내도 예외 글 대신 사람 말로(5차 310).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/shared/presentation/community_error_text.dart';

const providerFiles = [
  'lib/features/community/board/presentation/provider/community_provider_post.dart',
  'lib/features/community/question/presentation/provider/community_provider_question.dart',
  'lib/features/community/vote/presentation/provider/community_provider_vote.dart',
  'lib/features/community/shell/presentation/providers/community_provider_comment.dart',
  'lib/features/community/activity/presentation/providers/activity_provider.dart',
  'lib/features/community/notification/presentation/providers/community_notification_provider.dart',
];

void main() {
  test('무엇을 하다 실패했는지에 맞는 말을 쓴다', () {
    final failure = Exception('boom');
    expect(communityErrorText(CommunityJob.load, failure),
        '불러오지 못했어요. 잠시 뒤 다시 해 주세요.');
    expect(communityErrorText(CommunityJob.write, failure),
        '올리지 못했어요. 잠시 뒤 다시 해 주세요.');
    expect(communityErrorText(CommunityJob.edit, failure),
        '고치지 못했어요. 잠시 뒤 다시 해 주세요.');
    expect(communityErrorText(CommunityJob.delete, failure),
        '지우지 못했어요. 잠시 뒤 다시 해 주세요.');
    expect(communityErrorText(CommunityJob.like, failure), contains('공감'));
    expect(communityErrorText(CommunityJob.vote, failure), contains('투표'));
    expect(communityErrorText(CommunityJob.accept, failure), contains('채택'));
  });

  test('인터넷이 끊긴 것이면 그렇게 말한다', () {
    const offline = '[cloud_firestore/unavailable] Failed to get document '
        'because the client is offline.';
    expect(communityErrorText(CommunityJob.write, offline), contains('인터넷'));
    expect(communityErrorText(CommunityJob.load, 'SocketException: failed'),
        contains('인터넷'));
  });

  test('서버 규칙이 막은 것이면 로그인을 보라고 한다', () {
    const denied = '[cloud_firestore/permission-denied] Missing or '
        'insufficient permissions.';
    expect(communityErrorText(CommunityJob.write, denied), contains('로그인'));
    expect(communityErrorText(CommunityJob.delete, denied), contains('로그인'));
  });

  test('커뮤니티 Provider들은 예외 글을 그대로 담지 않는다', () {
    // 글쓰기 실패 창에 `[cloud_firestore/...]`가 그대로 떴었다.
    for (final path in providerFiles) {
      final code = File(path).readAsStringSync();
      expect(code.contains('= e.toString()'), isFalse, reason: path);
      expect(code.contains('= error.toString()'), isFalse, reason: path);
    }
  });

  test('끊긴 인터넷을 알아보는 규칙은 한 곳에만 있다', () {
    // 화면마다 따로 적으면 한 곳만 고쳐진다.
    final hits = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final code = file.readAsStringSync();
      if (code.contains("contains('unavailable')") &&
          !file.path.endsWith('network_error.dart')) {
        hits.add(file.path);
      }
    }
    expect(hits, isEmpty);
  });
}
