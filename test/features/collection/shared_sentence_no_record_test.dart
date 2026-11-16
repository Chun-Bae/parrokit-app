// 저장하지 않은 남의 문장은 들어도 내 기록이 쌓이지 않는다(5차 410, 사용자 신고).
//
// 둘러보기·홈에서 남의 문장 소리를 듣기만 해도 그 문장의 '듣기 N회'가
// 쌓여 친밀도(숙련도)가 올라갔다. 따라 말하기와 기록 칸은 이미 내 문장일
// 때만 보이는데 듣기만 새어 나갔다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _sheetBody() {
  final source = File('lib/features/collection/shell/presentation/widgets/'
          'sentence_collection_preview.dart')
      .readAsStringSync();
  const start = 'class _SentenceDetailSheetState';
  final from = source.indexOf(start);
  expect(from, greaterThan(0));
  final to = source.indexOf('\nclass ', from + start.length);
  return source.substring(from, to == -1 ? source.length : to);
}

void main() {
  test('듣기 수는 내 문장일 때만 센다', () {
    final body = _sheetBody();
    final at = body.indexOf('void countListen()');
    expect(at, greaterThan(0));
    final head = body.substring(at, at + 200);
    expect(head, contains('if (!widget.saved) return;'),
        reason: '저장하지 않은 문장은 듣기 수를 세지 않는다');
  });

  test('친밀도 표시도 내 문장일 때만 그린다', () {
    final body = _sheetBody();
    final at = body.indexOf('_MasteryBadge(');
    expect(at, greaterThan(0));
    final before = body.substring(at < 220 ? 0 : at - 220, at);
    expect(before, contains('if (widget.saved)'));
  });

  test('홈 공유 문장 카드는 눌러서 상세를 연다', () {
    final code = File('lib/features/home/dashboard/presentation/widgets/'
            'trending_sentences_preview.dart')
        .readAsStringSync();
    // 전에는 좋아요·저장 단추만 있고 카드 자체는 눌러도 아무 일이 없었다.
    expect(code, contains('onTap: onOpen'));
    expect(code, contains('showSentenceDetails('));
    expect(code, contains("ValueKey('trending-card-"));
  });
}
