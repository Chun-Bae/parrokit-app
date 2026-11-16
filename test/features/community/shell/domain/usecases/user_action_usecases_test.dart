import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parrokit/features/community/shell/domain/usecases/user_action/user_action_usecases.dart';
import 'mocks.mocks.dart';

void main() {
  late MockCommunityRepository mockRepository;

  setUp(() {
    mockRepository = MockCommunityRepository();
    SharedPreferences.setMockInitialValues({});
  });

  group('UserActionUseCases', () {
    test('ToggleLikeUseCase - 정상적으로 상태를 토글해야 한다', () async {
      final toggleLikeUseCase = ToggleLikeUseCase(mockRepository);

      when(mockRepository.toggleLike(any, any, any))
          .thenAnswer((_) async => {});

      await toggleLikeUseCase.execute('post_123', 'user_1', true);

      verify(mockRepository.toggleLike('post_123', 'user_1', true)).called(1);
    });

    test('ToggleScrapUseCase - 정상적으로 상태를 토글해야 한다', () async {
      final toggleScrapUseCase = ToggleScrapUseCase(mockRepository);

      when(mockRepository.toggleScrap(any, any, any))
          .thenAnswer((_) async => {});

      await toggleScrapUseCase.execute('post_123', 'user_1', false);

      verify(mockRepository.toggleScrap('post_123', 'user_1', false)).called(1);
    });

    test('LoadUserActionsUseCase - 저장된 유저 액션을 반환해야 한다', () async {
      final loadUserActionsUseCase = LoadUserActionsUseCase(mockRepository);

      when(mockRepository.getUserPostActions(any, any))
          .thenAnswer((_) async => {
                'isLiked': true,
                'isScrapped': false,
              });

      final result = await loadUserActionsUseCase.execute('post_123', 'user_1');

      expect(result['isLiked'], true);
      expect(result['isScrapped'], false);
    });

    test(
        'IncrementViewCountUseCase - 조회수를 처음 증가시키면 true 반환하고 SharedPreferences에 저장한다',
        () async {
      final incrementViewCountUseCase =
          IncrementViewCountUseCase(mockRepository);

      when(mockRepository.incrementViewCount(any)).thenAnswer((_) async => {});

      final result =
          await incrementViewCountUseCase.execute('post_123', userId: 'user_1');

      expect(result, true);
      verify(mockRepository.incrementViewCount('post_123')).called(1);

      // 두 번째 호출 시 24시간이 지나지 않았으므로 false 반환 및 repository 미호출
      final result2 =
          await incrementViewCountUseCase.execute('post_123', userId: 'user_1');
      expect(result2, false);
      verifyNever(mockRepository.incrementViewCount('post_123'));
    });
  });
}
