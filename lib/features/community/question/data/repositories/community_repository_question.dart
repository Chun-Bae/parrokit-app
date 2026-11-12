part of '../../../shell/data/repositories/community_repository.dart';

/// 질문 등록과 답변 채택은 크래커가 오가서 서버 함수(createQuestion,
/// acceptAnswer)로 한다. 전에는 앱이 트랜잭션으로 자기 크래커를 깎고,
/// 채택할 때 답변자의 크래커를 직접 올렸다. 그래서 규칙이 "남의 크래커를
/// 올리는 것"을 열어 둬야 했다.
mixin CommunityRepositoryQuestion {
  FirebaseFunctions get _functions;

  /// [requiredCrackers]는 [post]의 rewardCrackers와 같다. 서버는 글의 값을 쓴다.
  Future<Post> addQuestion(Post post, String userId, int requiredCrackers) async {
    try {
      final json = post.copyWith(rewardCrackers: requiredCrackers).toJson();
      // 서버는 시간대가 없는 문자열을 UTC로 읽는다. 마감 시각이 9시간
      // 밀리지 않게 UTC로 보낸다.
      if (post.expireAt != null) {
        json['expireAt'] = post.expireAt!.toUtc().toIso8601String();
      }
      final result = await _functions
          .httpsCallable('createQuestion')
          .call({'post': json});
      final data = Map<String, dynamic>.from(result.data as Map);
      return Post.fromJson(Map<String, dynamic>.from(data['post'] as Map));
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? '질문 등록에 실패했습니다.');
    }
  }

  /// 보상 액수와 답변자는 서버가 질문 글과 댓글에서 읽는다.
  /// [answererId]와 [rewardCrackers]는 예전 호출 모양을 맞추려고 남겨 둔다.
  Future<void> acceptAnswer({
    required String postId,
    required String commentId,
    required String answererId,
    required int rewardCrackers,
  }) async {
    try {
      await _functions.httpsCallable('acceptAnswer').call({
        'postId': postId,
        'commentId': commentId,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? '답변 채택에 실패했습니다.');
    }
  }
}
