import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/shared_sentence_repository.dart';

Future<void> publish(
  FirestoreSharedSentenceRepository repo, {
  String author = 'u1',
  String local = 'my-1',
  String text = 'Hello there',
  String language = '영어',
  String name = '앵무',
}) =>
    repo.publish(
      localSentenceId: local,
      authorId: author,
      authorName: name,
      language: language,
      text: text,
      translation: '안녕',
      pronunciation: '',
      topic: '내 문장',
    );

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreSharedSentenceRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = FirestoreSharedSentenceRepository(firestore: firestore);
  });

  test('공유하면 작성자와 함께 목록에 나오고 언어별로 나뉜다', () async {
    await publish(repo);
    await publish(repo, local: 'my-2', text: 'ありがとう', language: '일본어');
    final english = await repo.list(language: '영어', viewerId: 'v');
    expect(english, hasLength(1));
    expect(english.single.text, 'Hello there');
    expect(english.single.authorId, 'u1');
    expect(english.single.authorName, '앵무');
    expect(english.single.likeCount, 0);
    expect(english.single.liked, isFalse);
  });

  test('같은 문장을 다시 공유하면 한 개만 있고 좋아요는 유지된다', () async {
    await publish(repo);
    final id = FirestoreSharedSentenceRepository.idFor('u1', 'my-1');
    await repo.setLiked(sharedId: id, viewerId: 'v', liked: true);
    await publish(repo, name: '새 닉네임');
    final list = await repo.list(language: '영어', viewerId: 'v');
    expect(list, hasLength(1));
    expect(list.single.likeCount, 1);
    expect(list.single.authorName, '새 닉네임');
  });

  test('공유 취소하면 목록에서 사라지고 공개 여부가 바뀐다', () async {
    await publish(repo);
    expect(await repo.isPublished(authorId: 'u1', localSentenceId: 'my-1'),
        isTrue);
    await repo.unpublish(authorId: 'u1', localSentenceId: 'my-1');
    expect(await repo.isPublished(authorId: 'u1', localSentenceId: 'my-1'),
        isFalse);
    expect(await repo.list(language: '영어', viewerId: 'v'), isEmpty);
  });

  test('좋아요는 사람마다 한 번만 올라가고 취소하면 내려간다', () async {
    await publish(repo);
    final id = FirestoreSharedSentenceRepository.idFor('u1', 'my-1');
    await repo.setLiked(sharedId: id, viewerId: 'a', liked: true);
    await repo.setLiked(sharedId: id, viewerId: 'a', liked: true);
    await repo.setLiked(sharedId: id, viewerId: 'b', liked: true);
    var list = await repo.list(language: '영어', viewerId: 'a');
    expect(list.single.likeCount, 2);
    expect(list.single.liked, isTrue);
    expect((await repo.list(language: '영어', viewerId: 'c')).single.liked,
        isFalse);
    await repo.setLiked(sharedId: id, viewerId: 'a', liked: false);
    await repo.setLiked(sharedId: id, viewerId: 'a', liked: false);
    list = await repo.list(language: '영어', viewerId: 'a');
    expect(list.single.likeCount, 1);
    expect(list.single.liked, isFalse);
  });
}
