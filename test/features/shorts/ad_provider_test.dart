import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/clip/shorts/data/shorts_ad_repository.dart';
import 'package:parrokit/features/collection/clip/shorts/presentation/providers/ad_provider.dart';

/// SharedPreferences 대신 메모리에 두는 가짜 저장소.
class _MemoryAdRepository extends ShortsAdRepository {
  _MemoryAdRepository({this.count = 0, this.lastAdMs});

  int count;
  int? lastAdMs;

  @override
  Future<int> loadCount() async => count;

  @override
  Future<void> saveCount(int count) async => this.count = count;

  @override
  Future<void> clearCount() async => count = 0;

  @override
  Future<int?> loadLastAdTime() async => lastAdMs;

  @override
  Future<void> saveLastAdTime(int millisecondsSinceEpoch) async =>
      lastAdMs = millisecondsSinceEpoch;
}

Future<AdProvider> _provider(_MemoryAdRepository repo,
    {bool premium = false}) async {
  final provider = AdProvider(repository: repo, initialPremium: premium);
  // 생성자에서 저장된 값을 비동기로 읽는다.
  await Future<void>.delayed(Duration.zero);
  return provider;
}

/// 앞으로 [n]번 넘기고, 광고 신호가 온 번째(1부터)를 돌려준다.
List<int> _swipe(AdProvider ad, int n) => [
      for (var i = 1; i <= n; i++)
        if (ad.incrementBy(1)) i,
    ];

void main() {
  test('열 번째로 넘길 때마다 광고 신호를 준다', () async {
    final ad = await _provider(_MemoryAdRepository());
    expect(_swipe(ad, 25), [10, 20]);
    expect(ad.count, 5);
  });

  test('프리미엄이면 세지도 않고 광고도 없다', () async {
    final repo = _MemoryAdRepository();
    final ad = await _provider(repo, premium: true);
    expect(_swipe(ad, 30), isEmpty);
    expect(ad.count, 0);
    expect(repo.count, 0);
  });

  test('뒤로 넘기거나 제자리는 세지 않는다', () async {
    final ad = await _provider(_MemoryAdRepository());
    expect(ad.incrementBy(0), isFalse);
    expect(ad.incrementBy(-3), isFalse);
    expect(ad.count, 0);
  });

  test('앱을 다시 열어도 넘긴 횟수를 이어 센다', () async {
    final repo = _MemoryAdRepository();
    final first = await _provider(repo);
    _swipe(first, 7);
    expect(repo.count, 7);

    final again = await _provider(repo);
    expect(again.count, 7);
    expect(_swipe(again, 3), [3]);
  });

  test('광고를 본 지 2분이 안 됐으면 이번 차례는 건너뛴다', () async {
    final repo = _MemoryAdRepository(
        lastAdMs: DateTime.now()
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch);
    final ad = await _provider(repo);
    expect(_swipe(ad, 10), isEmpty);
  });

  test('광고를 본 지 2분이 지났으면 보여 준다', () async {
    final repo = _MemoryAdRepository(
        lastAdMs: DateTime.now()
            .subtract(const Duration(minutes: 3))
            .millisecondsSinceEpoch);
    final ad = await _provider(repo);
    expect(_swipe(ad, 10), [10]);
  });

  test('광고를 보여 준 시각을 저장해 바로 다음 차례를 막는다', () async {
    final repo = _MemoryAdRepository();
    final ad = await _provider(repo);
    expect(_swipe(ad, 10), [10]);
    ad.recordAdShown();
    expect(repo.lastAdMs, isNotNull);
    expect(_swipe(ad, 10), isEmpty);
  });

  test('reset은 횟수를 0으로 되돌린다', () async {
    final repo = _MemoryAdRepository(count: 6);
    final ad = await _provider(repo);
    ad.reset();
    expect(ad.count, 0);
    expect(repo.count, 0);
  });
}
