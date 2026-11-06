import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/content/sentence_transfer.dart';
import 'package:parrokit/core/content/sentence_url_import.dart';

void main() {
  group('downloadUri', () {
    test('https 주소는 그대로 쓴다', () {
      expect(SentenceUrlImport.downloadUri(' https://example.com/a.csv '),
          Uri.parse('https://example.com/a.csv'));
    });

    test('http나 주소가 아닌 값은 거절한다', () {
      expect(() => SentenceUrlImport.downloadUri('http://example.com/a.csv'),
          throwsFormatException);
      expect(() => SentenceUrlImport.downloadUri('file:///tmp/a.csv'),
          throwsFormatException);
      expect(() => SentenceUrlImport.downloadUri('아무 글자'),
          throwsFormatException);
    });

    test('구글 스프레드시트 공유 주소는 CSV 내보내기 주소로 바꾼다', () {
      expect(
        SentenceUrlImport.downloadUri(
            'https://docs.google.com/spreadsheets/d/abc_123-X/edit?usp=sharing#gid=456'),
        Uri.parse(
            'https://docs.google.com/spreadsheets/d/abc_123-X/export?format=csv&gid=456'),
      );
      expect(
        SentenceUrlImport.downloadUri(
            'https://docs.google.com/spreadsheets/d/abc/edit'),
        Uri.parse(
            'https://docs.google.com/spreadsheets/d/abc/export?format=csv'),
      );
    });
  });

  group('parseDownloaded', () {
    test('내용이 CSV면 CSV로 읽는다', () {
      final items = SentenceTransfer.parseDownloaded(
          Uint8List.fromList(utf8.encode('문장,뜻\nHello,안녕\n')));
      expect(items.single.text, 'Hello');
      expect(items.single.translation, '안녕');
    });

    test('내용이 xlsx(zip)면 xlsx로 읽는다', () {
      final bytes = SentenceTransfer.exportXlsx(const [
        DefaultConversationSentence(
          id: 'a',
          language: '영어',
          text: 'Good morning',
          translation: '좋은 아침',
          pronunciation: '',
          topic: '내 문장',
        ),
      ]);
      final items = SentenceTransfer.parseDownloaded(bytes);
      expect(items.single.text, 'Good morning');
      expect(items.single.language, '영어');
    });

    test('웹 페이지가 내려오면 거절한다', () {
      expect(
        () => SentenceTransfer.parseDownloaded(Uint8List.fromList(
            utf8.encode('<!DOCTYPE html><html><body>로그인</body></html>'))),
        throwsFormatException,
      );
    });
  });
}
