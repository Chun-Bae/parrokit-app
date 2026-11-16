import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/features/community/shell/domain/usecases/question/add_question_usecase.dart';
import 'package:parrokit/features/community/shell/domain/usecases/question/accept_answer_usecase.dart';
import 'mocks.mocks.dart';

void main() {
  late MockCommunityRepository mockRepository;
  late MockCommunityImageService mockImageService;

  setUp(() {
    mockRepository = MockCommunityRepository();
    mockImageService = MockCommunityImageService();
  });

  group('QuestionUseCases', () {
    test('AddQuestionUseCase - 정상적으로 질문 포스트가 추가되어야 한다', () async {
      final addQuestionUseCase =
          AddQuestionUseCase(mockRepository, mockImageService);

      when(mockRepository.generatePostId()).thenReturn('q_123');
      final dummyPost = Post(
        id: 'q_123',
        postType: 'question',
        category: '질문',
        title: '질문 제목',
        content: '질문 내용',
        authorId: 'user_1',
        authorNickname: 'Nickname',
        snippet: 'snippet',
      );
      when(mockRepository.addQuestion(any, any, any))
          .thenAnswer((_) async => dummyPost);

      await addQuestionUseCase.execute(
        title: '질문 제목',
        content: '질문 내용',
        category: '질문',
        authorId: 'user_1',
        authorNickname: 'Nickname',
        rewardCrackers: 100,
        expireAt: DateTime.now().add(const Duration(days: 1)),
      );

      verify(mockRepository.generatePostId()).called(1);
      verify(mockRepository.addQuestion(any, 'user_1', 100)).called(1);
    });

    test('AcceptAnswerUseCase - 정상적으로 채택되어야 한다', () async {
      final acceptAnswerUseCase = AcceptAnswerUseCase(mockRepository);

      when(mockRepository.acceptAnswer(
        postId: anyNamed('postId'),
        commentId: anyNamed('commentId'),
        answererId: anyNamed('answererId'),
        rewardCrackers: anyNamed('rewardCrackers'),
      )).thenAnswer((_) async => {});

      await acceptAnswerUseCase.execute(
        postId: 'q_123',
        commentId: 'c_123',
        answererId: 'user_2',
        rewardCrackers: 100,
      );

      verify(mockRepository.acceptAnswer(
        postId: 'q_123',
        commentId: 'c_123',
        answererId: 'user_2',
        rewardCrackers: 100,
      )).called(1);
    });
  });
}
