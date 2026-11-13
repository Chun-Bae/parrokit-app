import 'package:flutter/foundation.dart';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/data/models/vote_option.dart';

/// 커뮤니티 화면 확인용 가짜 글.
///
/// 질문·투표 글이 실제로 하나도 없어서 그 화면들을 볼 수 없었다. 커뮤니티는
/// 출시 중이라 확인하려고 실제 글을 쓸 수도 없다. 그래서 개발 빌드에서
/// `--dart-define=PK_FAKE_COMMUNITY=true`를 줄 때만 목록을 이 가짜 글로 채운다.
/// kDebugMode가 상수라 출시 빌드에서는 이 갈래가 통째로 빠진다.
///
/// 가짜 글 id는 모두 [fakePostPrefix]로 시작하고, CommunityProvider는 이런 id로
/// 서버에 쓰는 동작(공감, 스크랩, 투표, 댓글, 조회수, 채택, 삭제)을 하지 않는다.
const bool kFakeCommunity =
    kDebugMode && bool.fromEnvironment('PK_FAKE_COMMUNITY');

const String fakePostPrefix = 'debug-fake-';

bool isFakePost(String postId) => postId.startsWith(fakePostPrefix);

List<Post> fakeCommunityPosts(String postType, {DateTime? now}) {
  final base = now ?? DateTime.now();
  DateTime ago(int hours) => base.subtract(Duration(hours: hours));
  Post post(
    String id, {
    required String title,
    required String content,
    String category = '자유',
    int likes = 0,
    int comments = 0,
    int views = 0,
    required DateTime at,
    String questionStatus = 'waiting',
    int reward = 0,
    List<VoteOption>? options,
    DateTime? voteEnd,
  }) =>
      Post(
        id: '$fakePostPrefix$postType-$id',
        postType: postType,
        category: category,
        title: title,
        content: content,
        authorId: '${fakePostPrefix}author',
        authorNickname: '테스트',
        snippet: content,
        likeCount: likes,
        commentCount: comments,
        viewCount: views,
        createdAt: at,
        questionStatus: questionStatus,
        rewardCrackers: reward,
        voteOptions: options,
        voteEndTime: voteEnd,
      );

  switch (postType) {
    case 'question':
      return [
        post('1',
            title: '“I’m good”와 “I’m fine” 차이가 뭔가요?',
            content: '안부 인사에 대답할 때 둘 다 써도 되나요?',
            category: '질문',
            likes: 2,
            comments: 1,
            views: 14,
            reward: 30,
            at: ago(2)),
        post('2',
            title: 'figure out 발음이 잘 안 돼요',
            content: '피겨 아웃처럼 끊어 읽으면 어색한가요?',
            category: '질문',
            likes: 9,
            comments: 4,
            views: 52,
            reward: 50,
            questionStatus: 'resolved',
            at: ago(30)),
        post('3',
            title: '일본어 존댓말은 언제부터 쓰면 되나요?',
            content: '처음 만난 사람에게는 무조건 です·ます인가요?',
            category: '질문',
            likes: 5,
            comments: 0,
            views: 21,
            at: ago(80)),
      ];
    case 'vote':
      return [
        post('1',
            title: '하루에 몇 문장 따라 말하세요?',
            content: '목표를 정하려고 해요.',
            category: '투표',
            likes: 3,
            comments: 2,
            views: 40,
            options: const [
              VoteOption(id: 'a', text: '1~3문장', count: 4),
              VoteOption(id: 'b', text: '5문장', count: 7),
              VoteOption(id: 'c', text: '10문장 넘게', count: 2),
            ],
            voteEnd: base.add(const Duration(days: 2)),
            at: ago(5)),
      ];
    default:
      return [
        post('1',
            title: '쉐도잉 2주째 후기',
            content: '처음보다 말이 덜 끊겨요.',
            likes: 4,
            comments: 3,
            views: 33,
            at: ago(1)),
        post('2',
            title: '자막 없이 보는 연습 꿀팁',
            content: '한 번은 자막, 두 번째는 없이 보기.',
            category: '꿀팁',
            likes: 11,
            comments: 5,
            views: 80,
            at: ago(26)),
      ];
  }
}
