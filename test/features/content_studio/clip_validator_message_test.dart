import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/content-studio/captioning/domain/models/clip_form_data.dart';
import 'package:parrokit/features/content-studio/captioning/domain/validators/clip_validator.dart';

void main() {
  final validator = ClipValidator();
  const full = SegmentInput(
      start: '00:00.000', end: '00:01.000', original: 'Hi', pron: '하이', ko: '안녕');

  String? message(List<SegmentInput> segments, {int durationMs = 6000}) =>
      validator.validateSegments(segments, durationMs).errorMessage;

  test('구간 오류 문구는 화면 말(구간·A·B·원문·해석·발음)을 쓴다', () {
    expect(message([]), '구간을 하나 이상 만들어 주세요.');
    expect(message([full.copyWith(ko: '')]), '구간 1: 원문·해석·발음을 모두 적어 주세요.');
    expect(message([full.copyWith(start: '0:0')]), '구간 1: A 시각을 다시 확인해 주세요.');
    expect(message([full.copyWith(end: '1')]), '구간 1: B 시각을 다시 확인해 주세요.');
    expect(message([full.copyWith(end: '00:00.000')]), '구간 1: B가 A보다 뒤여야 해요.');
    expect(message([full], durationMs: 500), '구간 1: 영상 길이를 넘어요.');
    expect(
        message([full, full.copyWith(start: '00:00.500', end: '00:02.000')]),
        '겹치는 구간이 있어요: 1번, 2번');
    expect(message([full]), isNull);
  });

  test('어떤 오류 문구에도 세그먼트·필드·컬렉션 같은 내부 말이 없다', () {
    final all = [
      message([]),
      message([full.copyWith(ko: '')]),
      message([full.copyWith(start: 'x')]),
      message([full.copyWith(end: 'x')]),
      message([full.copyWith(end: '00:00.000')]),
      message([full], durationMs: 500),
      message([full, full]),
    ];
    for (final m in all) {
      expect(m, isNotNull);
      expect(m, isNot(contains('세그먼트')));
      expect(m, isNot(contains('필드')));
    }
  });
}
