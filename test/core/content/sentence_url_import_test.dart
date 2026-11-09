import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
      final rejected = throwsA(isA<SentenceUrlException>());
      expect(() => SentenceUrlImport.downloadUri('http://example.com/a.csv'),
          rejected);
      expect(
          () => SentenceUrlImport.downloadUri('file:///tmp/a.csv'), rejected);
      expect(() => SentenceUrlImport.downloadUri('아무 글자'), rejected);
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

  group('아이클라우드 공유 주소', () {
    final share = Uri.parse(
        'https://www.icloud.com/iclouddrive/055f0xMBeE17NH-xrQne_LHpQ#%ED%9A%8C%ED%99%94');

    test('공유 주소를 알아본다', () {
      expect(SentenceUrlImport.isICloudShare(share), isTrue);
      expect(
          SentenceUrlImport.isICloudShare(Uri.parse('https://example.com/a')),
          isFalse);
      expect(SentenceUrlImport.downloadUri(share.toString()).host,
          'www.icloud.com');
    });

    test('공유 코드로 파일 주소를 찾아 내려받는다', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          expect(jsonDecode(request.body)['shortGUIDs'][0]['value'],
              '055f0xMBeE17NH-xrQne_LHpQ');
          return http.Response(
              jsonEncode({
                'results': [
                  {
                    'rootRecord': {
                      'fields': {
                        'fileContent': {
                          'value': {
                            'downloadURL':
                                r'https://cvws.icloud-content.com/B/abc${f}'
                          }
                        }
                      }
                    }
                  }
                ]
              }),
              200);
        }
        return http.Response.bytes(utf8.encode('문장,뜻\nHello,안녕\n'), 200);
      });
      final bytes = await SentenceUrlImport.fetch(share, client: client);
      expect(utf8.decode(bytes), contains('Hello'));
      expect(requests.last.url.toString(),
          'https://cvws.icloud-content.com/B/abcfile');
    });

    test('폴더 링크처럼 파일이 없으면 이유를 알려준다', () async {
      final client = MockClient((request) async => http.Response(
          jsonEncode({
            'results': [
              {
                'rootRecord': {'fields': {}}
              }
            ]
          }),
          200));
      await expectLater(SentenceUrlImport.fetch(share, client: client),
          throwsA(isA<SentenceUrlException>()));
    });
  });
}
