import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:parrokit/data/models/comment.dart';
import 'package:parrokit/features/community/shell/domain/usecases/comment/add_comment_usecase.dart';
import 'package:parrokit/features/community/shell/domain/usecases/comment/delete_comment_usecase.dart';
import 'mocks.mocks.dart';

void main() {
  late MockCommunityRepository mockRepository;

  setUp(() {
    mockRepository = MockCommunityRepository();
  });

  group('CommentUseCases', () {
    test('AddCommentUseCase - 정상적으로 댓글이 추가되어야 한다', () async {
      final addCommentUseCase = AddCommentUseCase(mockRepository);

      final returnedComment = Comment(
        id: 'c_123',
        authorId: 'user_1',
        authorNickname: 'Nickname',
        content: '테스트 댓글',
      );

      when(mockRepository.addComment(any, any)).thenAnswer((_) async => returnedComment);

      final result = await addCommentUseCase.execute(
        'post_123',
        '테스트 댓글',
        postType: 'board',
        authorId: 'user_1',
        authorNickname: '테스터',
      );

      expect(result.id, 'c_123');
      verify(mockRepository.addComment('post_123', any)).called(1);
    });

    test('DeleteCommentUseCase - 정상적으로 댓글이 삭제(상태 변경)되어야 한다', () async {
      final deleteCommentUseCase = DeleteCommentUseCase(mockRepository);

      when(mockRepository.deleteComment(any, any)).thenAnswer((_) async => {});

      await deleteCommentUseCase.execute('post_123', 'c_123');

      verify(mockRepository.deleteComment('post_123', 'c_123')).called(1);
    });
  });
}
