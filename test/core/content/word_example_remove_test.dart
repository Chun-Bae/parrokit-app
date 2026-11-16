// 저장해 둔 예문을 뺄 수 있다(5차 328).

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<String> seed() async {
    await MyWordStore.add('guest',
        language: '영어',
        word: 'projection',
        examples: const [
          WordExample(text: '첫 예문'),
          WordExample(text: '두 번째 예문'),
        ]);
    return (await MyWordStore.loadFor('guest', '영어')).single.id;
  }

  test('고른 예문만 빠지고 단어는 그대로다', () async {
    final id = await seed();
    expect(await MyWordStore.removeExample('guest', id, 0), isTrue);

    final after = (await MyWordStore.loadFor('guest', '영어')).single;
    expect(after.word, 'projection');
    expect(after.examples.map((e) => e.text), ['두 번째 예문']);
  });

  test('없는 자리나 없는 단어는 건드리지 않는다', () async {
    final id = await seed();
    expect(await MyWordStore.removeExample('guest', id, 5), isFalse);
    expect(await MyWordStore.removeExample('guest', id, -1), isFalse);
    expect(await MyWordStore.removeExample('guest', 'no-such', 0), isFalse);
    expect((await MyWordStore.loadFor('guest', '영어')).single.examples.length, 2);
  });

  test('마지막 예문까지 뺄 수 있다', () async {
    final id = await seed();
    await MyWordStore.removeExample('guest', id, 1);
    await MyWordStore.removeExample('guest', id, 0);
    expect((await MyWordStore.loadFor('guest', '영어')).single.examples, isEmpty);
  });
}
