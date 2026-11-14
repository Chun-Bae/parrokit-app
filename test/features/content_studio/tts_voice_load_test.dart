import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/features/content-studio/tts/domain/repositories/tts_generation_repository.dart';
import 'package:parrokit/features/content-studio/tts/domain/usecases/generate_tts_usecase.dart';
import 'package:parrokit/features/content-studio/tts/presentation/providers/tts_provider.dart';

class _User extends Fake implements UserProvider {}

class _FakeRepo implements TtsGenerationRepository {
  _FakeRepo({this.fail = false, this.hang = false});

  bool fail;
  bool hang;
  int calls = 0;

  @override
  Future<List<Map<String, dynamic>>> listVoices(String languageCode) async {
    calls++;
    if (hang) {
      await Future<void>.delayed(const Duration(seconds: 60));
    }
    if (fail) throw Exception('network');
    return [
      {'name': 'ko-KR-Chirp3-HD-A', 'ssmlGender': 'FEMALE'},
    ];
  }

  @override
  Future<String> generateTts({
    required String text,
    required String language,
    TtsProviderType provider = TtsProviderType.google,
    String? voiceId,
    String? modelId,
    double? speakingRate,
    double? pitch,
    ElevenLabsVoiceSettings? elevenLabsSettings,
    bool serverCharge = false,
    void Function(int chargedParrots)? onCharged,
  }) async =>
      '/tmp/a.mp3';
}

TtsProvider _makeProvider(_FakeRepo repo) => TtsProvider(
      userProvider: _User(),
      useCase: GenerateTtsUseCase(repo),
    );

void main() {
  test('보이스 목록을 가져오면 실패 표시가 없다', () async {
    final repo = _FakeRepo();
    final vm = _makeProvider(repo);
    addTearDown(vm.dispose);

    await vm.fetchAvailableVoices();
    expect(vm.isLoadingVoices, isFalse);
    expect(vm.voicesFailed, isFalse);
    expect(vm.availableVoices, isNotEmpty);
  });

  test('실패하면 불러오는 중이 아니라 실패로 남는다', () async {
    final repo = _FakeRepo(fail: true);
    final vm = _makeProvider(repo);
    addTearDown(vm.dispose);

    await vm.fetchAvailableVoices();
    // 전에는 실패해도 빈 목록이 돼 '선택 (기본값)'처럼 보였다.
    expect(vm.isLoadingVoices, isFalse);
    expect(vm.voicesFailed, isTrue);
    expect(vm.availableVoices, isEmpty);
  });

  test('다시 시도하면 실패 표시가 풀리고 목록이 들어온다', () async {
    final repo = _FakeRepo(fail: true);
    final vm = _makeProvider(repo);
    addTearDown(vm.dispose);

    await vm.fetchAvailableVoices();
    expect(vm.voicesFailed, isTrue);

    repo.fail = false;
    await vm.fetchAvailableVoices();
    expect(vm.voicesFailed, isFalse);
    expect(vm.availableVoices, isNotEmpty);
    expect(repo.calls, 2);
  });

  test('응답이 없으면 기다리다 끝나지 않고 실패로 바뀐다', () async {
    fakeAsync((async) {
      final repo = _FakeRepo(hang: true);
      final vm = _makeProvider(repo);
      vm.fetchAvailableVoices();
      async.flushMicrotasks();
      expect(vm.isLoadingVoices, isTrue);

      async.elapse(TtsProvider.voicesTimeout + const Duration(seconds: 1));
      expect(vm.isLoadingVoices, isFalse);
      expect(vm.voicesFailed, isTrue);
      vm.dispose();
    });
  });
}
