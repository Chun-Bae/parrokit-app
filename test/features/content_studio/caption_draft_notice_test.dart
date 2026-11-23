// 자막 초안에 빈 칸이 있을 때 알리기(5차 567).
//
// 서버가 소리를 알아들어도 해석·발음은 비어 올 수 있는데(말이 아닌
// 소리), 저장은 구간마다 셋을 다 요구한다. 기기에서 패롯을 쓰고
// '자막 생성 완료!'를 본 뒤에야 저장이 막힌 것을 알았다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/content-studio/captioning/domain/caption_draft_notice.dart';
import 'package:parrokit/features/content-studio/captioning/domain/models/clip_form_data.dart';

void main() {
  group('빈 칸 찾기', () {
    test('해석이 비면 빈 칸으로 본다', () {
      expect(
          draftHasBlankFields(const [
            SegmentInput(original: 'Hello', pron: '헬로', ko: ''),
          ]),
          isTrue);
    });

    test('발음이 비어도 빈 칸으로 본다', () {
      expect(
          draftHasBlankFields(const [
            SegmentInput(original: 'Hello', pron: '', ko: '안녕'),
          ]),
          isTrue);
    });

    test('셋이 다 차 있으면 아니다', () {
      expect(
          draftHasBlankFields(const [
            SegmentInput(original: 'Hello', pron: '헬로', ko: '안녕'),
          ]),
          isFalse);
    });

    // 원문부터 비었으면 그 구간은 아직 아무것도 없는 것이다. 자동 자막이
    // 못 알아들은 자리까지 '채워야 한다'고 말하면 시끄럽다.
    test('원문도 비었으면 세지 않는다', () {
      expect(draftHasBlankFields(const [SegmentInput()]), isFalse);
    });

    test('여러 구간 가운데 하나만 비어도 찾는다', () {
      expect(
          draftHasBlankFields(const [
            SegmentInput(original: 'A', pron: '에이', ko: '가'),
            SegmentInput(original: 'B', pron: '비', ko: ''),
          ]),
          isTrue);
    });

    test('빈 공백만 있는 것도 빈 칸이다', () {
      expect(
          draftHasBlankFields(const [
            SegmentInput(original: 'Hello', pron: '  ', ko: '안녕'),
          ]),
          isTrue);
    });
  });

  group('알림 글', () {
    test('빈 칸이 없으면 값만 적는다', () {
      expect(captionDraftToast(charged: 1, hasBlank: false),
          '자막 생성 완료! (1패롯 소모)');
    });

    test('패롯을 안 썼으면 값을 적지 않는다', () {
      expect(captionDraftToast(charged: 0, hasBlank: false), '자막 생성 완료!');
    });

    test('빈 칸이 있으면 채워야 저장된다고 말한다', () {
      final text = captionDraftToast(charged: 1, hasBlank: true);
      expect(text, contains('1패롯 소모'));
      expect(text, contains('해석·발음이 빈 구간이 있어요'));
      expect(text, contains('저장'));
    });
  });

  // 화면이 이 말을 실제로 쓰는지. 한 쪽만 고쳐 놓으면 소용없다.
  test('자막 화면이 이 말을 쓴다', () {
    final source = File(
      'lib/features/content-studio/captioning/presentation/providers/'
      'captioning_provider.dart',
    ).readAsStringSync();
    expect(source, contains('captionDraftToast('));
    expect(source, contains('draftHasBlankFields('));
    // 예전처럼 글을 그 자리에서 짓고 있으면 둘이 또 갈린다.
    expect(source.contains("showToast('자막 생성 완료!')"), isFalse);
  });
}
