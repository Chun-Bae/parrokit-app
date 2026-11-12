import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/features/community/shell/domain/usecases/post/add_post_usecase.dart';
import 'package:parrokit/features/community/shell/domain/usecases/post/delete_post_usecase.dart';
import 'package:parrokit/features/community/shell/domain/usecases/post/edit_post_usecase.dart';
import 'mocks.mocks.dart';

void main() {
  late MockCommunityRepository mockRepository;
  late MockCommunityImageService mockImageService;

  setUp(() {
    mockRepository = MockCommunityRepository();
    mockImageService = MockCommunityImageService();
  });

  group('PostUseCases', () {
    test('AddPostUseCase - 성공적으로 포스트가 추가되어야 한다', () async {
      final addPostUseCase = AddPostUseCase(mockRepository, mockImageService);
      
      when(mockRepository.generatePostId()).thenReturn('post_123');
      final dummyPost = Post(
        id: 'post_123',
        postType: 'board',
        category: '자유',
        title: 'Test Title',
        content: 'Test Content',
        authorId: 'user_1',
        authorNickname: 'Nickname',
        snippet: 'snippet',
      );
      when(mockRepository.addPost(any)).thenAnswer((_) async => dummyPost);

      await addPostUseCase.execute(
        title: 'Test Title',
        content: 'Test Content',
        category: '자유',
        authorId: 'user_1',
        authorNickname: 'Nickname',
      );

      verify(mockRepository.generatePostId()).called(1);
      verify(mockRepository.addPost(any)).called(1);
    });

    test('DeletePostUseCase - 삭제 시 포스트와 이미지가 삭제되어야 한다', () async {
      final deletePostUseCase = DeletePostUseCase(mockRepository, mockImageService);
      
      final post = Post(
        id: 'post_123',
        postType: 'board',
        category: '자유',
        title: 'Title',
        content: 'Content',
        authorId: 'user_1',
        authorNickname: 'Nickname',
        hasImage: true,
        imageUrls: ['url1', 'url2'],
        snippet: 'snippet',
      );

      when(mockImageService.deleteImageFromStorage(any)).thenAnswer((_) async => true);
      when(mockRepository.deletePost(any)).thenAnswer((_) async => {});

      await deletePostUseCase.execute(post);

      verify(mockImageService.deleteImageFromStorage('url1')).called(1);
      verify(mockImageService.deleteImageFromStorage('url2')).called(1);
      verify(mockRepository.deletePost('post_123')).called(1);
    });

    test('EditPostUseCase - 정상적으로 업데이트 되어야 한다', () async {
      final editPostUseCase = EditPostUseCase(mockRepository, mockImageService);
      
      final post = Post(
        id: 'post_123',
        postType: 'board',
        category: '자유',
        title: 'Title',
        content: 'Content',
        authorId: 'user_1',
        authorNickname: 'Nickname',
        hasImage: true,
        imageUrls: ['url1', 'url2'],
        snippet: 'snippet',
      );

      when(mockImageService.deleteImagesQuietly(any))
          .thenAnswer((_) async {});
      when(mockRepository.updatePost(any, any)).thenAnswer((_) async => {});

      await editPostUseCase.execute(
        existingPost: post,
        title: 'New Title',
        content: 'New Content',
        category: '질문',
        tags: [],
        existingImageUrls: ['url1'], // 'url2' was deleted
        newImageFiles: [],
        authorId: 'user_1',
      );

      verify(mockRepository.updatePost('post_123', argThat(isMap))).called(1);
      verify(mockImageService.deleteImagesQuietly(['url2'])).called(1);
    });

    test('EditPostUseCase - 저장이 실패하면 뺀 이미지를 지우지 않는다', () async {
      // 전에는 저장보다 먼저 지웠다. 저장이 실패하면 사용자가 뺀 이미지는
      // 이미 사라졌는데 글은 그대로라, 되돌릴 방법이 없었다.
      final editPostUseCase = EditPostUseCase(mockRepository, mockImageService);

      final post = Post(
        id: 'post_123',
        postType: 'board',
        category: '자유',
        title: 'Title',
        content: 'Content',
        authorId: 'user_1',
        authorNickname: 'Nickname',
        hasImage: true,
        imageUrls: ['url1', 'url2'],
        snippet: 'snippet',
      );

      when(mockImageService.deleteImagesQuietly(any))
          .thenAnswer((_) async {});
      when(mockRepository.updatePost(any, any))
          .thenThrow(Exception('저장 실패'));

      await expectLater(
        editPostUseCase.execute(
          existingPost: post,
          title: 'New Title',
          content: 'New Content',
          category: '질문',
          tags: [],
          existingImageUrls: ['url1'],
          newImageFiles: [],
          authorId: 'user_1',
        ),
        throwsA(isA<Exception>()),
      );

      // 뺀 이미지(url2)는 아직 살아 있어야 한다.
      verifyNever(mockImageService.deleteImagesQuietly(['url2']));
    });
  });
}
