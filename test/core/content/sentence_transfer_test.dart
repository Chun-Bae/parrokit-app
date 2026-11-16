// 문장 내보내기·가져오기 형식(5차 357). 사용자 파일을 다루는 곳이라 규칙을
// 테스트로 묶어 둔다. 전에는 화면 테스트만 있었고 형식 자체는 덮이지 않았다.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/content/sentence_transfer.dart';

DefaultConversationSentence sentence({
  String language = '영어',
  String text = 'Hello there!',
  String translation = '안녕하세요!',
  String pronunciation = '헬로 데어',
}) =>
    DefaultConversationSentence(
      id: 'my-$language-$text',
      language: language,
      text: text,
      translation: translation,
      pronunciation: pronunciation,
      topic: '내 문장',
    );

Uint8List csvBytes(String raw) => Uint8List.fromList(utf8.encode(raw));

void main() {
  group('CSV 내보내기', () {
    test('머리글과 열 차례(언어·문장·뜻·발음)를 지킨다', () {
      final csv = SentenceTransfer.exportCsv([sentence()]);
      final lines = csv.replaceFirst('﻿', '').trim().split('\r\n');
      expect(lines.first, '언어,문장,뜻,발음');
      expect(lines[1], '영어,Hello there!,안녕하세요!,헬로 데어');
    });

    test('엑셀에서 한글이 깨지지 않게 BOM을 붙인다', () {
      expect(SentenceTransfer.exportCsv([]).startsWith('﻿'), isTrue);
    });

    test('쉼표·따옴표·줄바꿈이 든 칸은 따옴표로 감싸고 따옴표는 두 번 적는다', () {
      final csv = SentenceTransfer.exportCsv([
        sentence(text: 'He said "hi", then left', translation: '첫 줄\n둘째 줄'),
      ]);
      expect(csv, contains('"He said ""hi"", then left"'));
      expect(csv, contains('"첫 줄\n둘째 줄"'));
    });
  });

  group('CSV 가져오기', () {
    test('내보낸 파일을 그대로 다시 읽는다(왕복)', () {
      final csv = SentenceTransfer.exportCsv([
        sentence(),
        sentence(
            language: '일본어',
            text: 'ありがとう',
            translation: '고마워요',
            pronunciation: '아리가토'),
      ]);

      final parsed = SentenceTransfer.parse(csvBytes(csv), 'my.csv');

      expect(parsed.map((e) => e.text), ['Hello there!', 'ありがとう']);
      expect(parsed.first.language, '영어');
      expect(parsed.last.translation, '고마워요');
    });

    test('머리글 이름이 달라도(영어·순서 바뀜) 찾아 읽는다', () {
      final parsed = SentenceTransfer.parse(
        csvBytes('meaning,sentence,language\n좋은 아침,Good morning,영어\n'),
        'x.csv',
      );
      expect(parsed.single.text, 'Good morning');
      expect(parsed.single.translation, '좋은 아침');
      expect(parsed.single.language, '영어');
    });

    test('머리글이 없으면 문장·뜻·발음 차례로 읽는다', () {
      final parsed = SentenceTransfer.parse(
        csvBytes('Good morning,좋은 아침,굿모닝\n'),
        'x.csv',
      );
      expect(parsed.single.text, 'Good morning');
      expect(parsed.single.pronunciation, '굿모닝');
      expect(parsed.single.language, '', reason: '비면 고른 언어를 쓴다');
    });

    test('빈 줄과 문장이 없는 줄은 건너뛴다', () {
      final parsed = SentenceTransfer.parse(
        csvBytes('문장,뜻\n\nGood morning,좋은 아침\n,뜻만 있는 줄\n'),
        'x.csv',
      );
      expect(parsed.map((e) => e.text), ['Good morning']);
    });

    test('따옴표 안의 쉼표와 줄바꿈을 한 칸으로 읽는다', () {
      final parsed = SentenceTransfer.parse(
        csvBytes('문장,뜻\n"He said ""hi"", then left","첫 줄\n둘째 줄"\n'),
        'x.csv',
      );
      expect(parsed.single.text, 'He said "hi", then left');
      expect(parsed.single.translation, '첫 줄\n둘째 줄');
    });

    test('탭으로 나눈 파일도 읽는다', () {
      final parsed = SentenceTransfer.parse(
        csvBytes('문장\t뜻\nGood morning\t좋은 아침\n'),
        'x.csv',
      );
      expect(parsed.single.text, 'Good morning');
      expect(parsed.single.translation, '좋은 아침');
    });
  });

  group('엑셀(xlsx)', () {
    test('내보낸 엑셀을 그대로 다시 읽는다(왕복)', () {
      final bytes = SentenceTransfer.exportXlsx([
        sentence(),
        sentence(
            language: '중국어',
            text: '谢谢',
            translation: '고마워요',
            pronunciation: '셰셰'),
      ]);

      final parsed = SentenceTransfer.parse(bytes, 'my.xlsx');

      expect(parsed.map((e) => e.text), ['Hello there!', '谢谢']);
      expect(parsed.last.language, '중국어');
      expect(parsed.last.pronunciation, '셰셰');
    });

    test('주소로 받은 파일은 이름이 없어도 엑셀인지 알아본다', () {
      final bytes = SentenceTransfer.exportXlsx([sentence()]);
      expect(
          SentenceTransfer.parseDownloaded(bytes).single.text, 'Hello there!');

      final csv = SentenceTransfer.exportCsv([sentence(text: 'From CSV')]);
      expect(SentenceTransfer.parseDownloaded(csvBytes(csv)).single.text,
          'From CSV');
    });
  });
}
