import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/shared_sentence_repository.dart';

import '../../support/sentence_seed.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreSharedSentenceRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = FirestoreSharedSentenceRepository(firestore: firestore);
  });

  test('공개된 문장만 작성자와 함께 목록에 나오고 언어별로 나뉜다', () async {
    await seedSentence(firestore, 'my-1', visibility: 'public');
    await seedSentence(firestore, 'my-2',
        text: 'ありがとう', language: '일본어', visibility: 'public');
    await seedSentence(firestore, 'my-3', text: 'Only me');
    final english = await repo.list(language: '영어', viewerId: 'v');
    expect(english, hasLength(1));
    expect(english.single.id, 'my-1');
    expect(english.single.text, 'Hello there');
    expect(english.single.authorId, 'u1');
    expect(english.single.authorName, '앵무');
    expect(english.single.likeCount, 0);
    expect(english.single.liked, isFalse);
  });

  test('공개하면 같은 문서가 둘러보기에 나오고 좋아요와 공개 취소 뒤에도 유지된다', () async {
    await seedSentence(firestore, 'my-1');
    expect(await repo.isPublished(sentenceId: 'my-1'), isFalse);
    expect(await repo.list(language: '영어', viewerId: 'v'), isEmpty);

    await repo.publish(sentenceId: 'my-1', authorName: '새 닉네임');
    expect(await repo.isPublished(sentenceId: 'my-1'), isTrue);
    await repo.setLiked(sharedId: 'my-1', viewerId: 'v', liked: true);
    var list = await repo.list(language: '영어', viewerId: 'v');
    expect(list, hasLength(1));
    expect(list.single.authorName, '새 닉네임');
    expect(list.single.likeCount, 1);

    // 공개를 취소해도 문서와 좋아요 수는 남고, 다시 공개하면 그대로 이어진다.
    await repo.unpublish(sentenceId: 'my-1');
    expect(await repo.isPublished(sentenceId: 'my-1'), isFalse);
    expect(await repo.list(language: '영어', viewerId: 'v'), isEmpty);
    expect((await firestore.collection('sentences').doc('my-1').get()).exists,
        isTrue);
    await repo.publish(sentenceId: 'my-1', authorName: '새 닉네임');
    list = await repo.list(language: '영어', viewerId: 'v');
    expect(list.single.likeCount, 1);
  });

  test('좋아요는 사람마다 한 번만 올라가고 취소하면 내려간다', () async {
    await seedSentence(firestore, 'my-1', visibility: 'public');
    await repo.setLiked(sharedId: 'my-1', viewerId: 'a', liked: true);
    await repo.setLiked(sharedId: 'my-1', viewerId: 'a', liked: true);
    await repo.setLiked(sharedId: 'my-1', viewerId: 'b', liked: true);
    var list = await repo.list(language: '영어', viewerId: 'a');
    expect(list.single.likeCount, 2);
    expect(list.single.liked, isTrue);
    expect(
        (await repo.list(language: '영어', viewerId: 'c')).single.liked, isFalse);
    await repo.setLiked(sharedId: 'my-1', viewerId: 'a', liked: false);
    await repo.setLiked(sharedId: 'my-1', viewerId: 'a', liked: false);
    list = await repo.list(language: '영어', viewerId: 'a');
    expect(list.single.likeCount, 1);
    expect(list.single.liked, isFalse);
  });

  test('하루에 10개까지만 새로 공개할 수 있고 이미 공개한 문장 갱신은 한도를 쓰지 않는다', () async {
    for (var i = 0; i < 11; i++) {
      await seedSentence(firestore, 'my-$i', text: 'Sentence $i');
    }
    for (var i = 0; i < 10; i++) {
      await repo.publish(sentenceId: 'my-$i', authorName: '앵무');
    }
    await expectLater(repo.publish(sentenceId: 'my-10', authorName: '앵무'),
        throwsA(isA<ShareLimitReachedException>()));
    expect(await repo.isPublished(sentenceId: 'my-10'), isFalse);

    // 이미 공개한 문장의 닉네임 갱신은 한도와 상관없이 된다.
    await repo.publish(sentenceId: 'my-0', authorName: '바뀐 닉네임');
    final list = await repo.list(language: '영어', viewerId: 'v');
    expect(list.firstWhere((s) => s.id == 'my-0').authorName, '바뀐 닉네임');

    // 취소했다가 다시 공개해도 한도를 다시 쓴다.
    await repo.unpublish(sentenceId: 'my-0');
    await expectLater(repo.publish(sentenceId: 'my-0', authorName: '앵무'),
        throwsA(isA<ShareLimitReachedException>()));
  });

  test('공개와 공개 취소는 목록 갱신 신호를 올린다', () async {
    await seedSentence(firestore, 'my-1');
    final before = SharedSentenceRepository.revision.value;
    await repo.publish(sentenceId: 'my-1', authorName: '앵무');
    expect(SharedSentenceRepository.revision.value, before + 1);
    await repo.unpublish(sentenceId: 'my-1');
    expect(SharedSentenceRepository.revision.value, before + 2);
  });

  test('인기순은 좋아요, 가져간 수, 최신 순으로 정렬하고 개수를 자른다', () async {
    final now = DateTime.now();
    await seedSentence(firestore, 'a', visibility: 'public', likeCount: 1);
    await seedSentence(firestore, 'b',
        visibility: 'public', likeCount: 5, text: 'B');
    await seedSentence(firestore, 'c',
        visibility: 'public', likeCount: 1, importCount: 3, text: 'C');
    await seedSentence(firestore, 'd',
        visibility: 'public',
        likeCount: 1,
        text: 'D',
        createdAt: now.add(const Duration(minutes: 1)));
    await seedSentence(firestore, 'private', likeCount: 99, text: 'P');
    await seedSentence(firestore, 'ja',
        visibility: 'public', likeCount: 50, language: '일본어', text: 'J');

    final top = await repo.popular(language: '영어', viewerId: 'v', limit: 3);
    expect(top.map((e) => e.id), ['b', 'c', 'd']);
  });
}
