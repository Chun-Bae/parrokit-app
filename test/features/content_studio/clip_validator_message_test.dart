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

  group('저장 버튼을 끌 때 쓰는 까닭', () {
    test('영상 → 폴더 → 제목 순으로 알린다', () {
      expect(
          ClipValidator.blockedReason(filePath: '', folder: '', title: ''),
          ClipValidator.noFileMessage);
      expect(
          ClipValidator.blockedReason(
              filePath: '/tmp/a.mp4', folder: '  ', title: ''),
          ClipValidator.noFolderMessage);
      expect(
          ClipValidator.blockedReason(
              filePath: '/tmp/a.mp4', folder: '여행', title: '   '),
          ClipValidator.noTitleMessage);
      expect(
          ClipValidator.blockedReason(
              filePath: '/tmp/a.mp4', folder: '여행', title: '오사카'),
          isNull);
    });

    test('구간이 비어 있으면 그 까닭까지 알린다', () {
      // 전에는 영상·폴더·제목만 봐서 버튼이 켜져 있었다. 눌러도 화면은
      // 그대로고 잠깐 뜨는 토스트만 알려 줬다(5차).
      expect(
          ClipValidator.blockedReason(
            filePath: '/tmp/a.mp4',
            folder: '여행',
            title: '오사카',
            segments: const [
              SegmentInput(
                  start: '00:00.000', end: '00:05.000', original: '', pron: '', ko: ''),
            ],
            durationMs: 8000,
          ),
          '구간 1: 원문·해석·발음을 모두 적어 주세요.');
    });

    test('구간이 다 채워져 있으면 막지 않는다', () {
      expect(
          ClipValidator.blockedReason(
            filePath: '/tmp/a.mp4',
            folder: '여행',
            title: '오사카',
            segments: const [
              SegmentInput(
                  start: '00:00.000',
                  end: '00:05.000',
                  original: 'Where is the station?',
                  pron: 'eki wa doko',
                  ko: '역이 어디예요?'),
            ],
            durationMs: 8000,
          ),
          isNull);
    });

    test('영상 길이를 아직 모르면 구간은 따지지 않는다', () {
      expect(
          ClipValidator.blockedReason(
            filePath: '/tmp/a.mp4',
            folder: '여행',
            title: '오사카',
            segments: const [],
            durationMs: null,
          ),
          isNull);
    });

    test('구간 까닭도 눌렀을 때 문구와 같다', () {
      const segments = [
        SegmentInput(
            start: '00:00.000', end: '00:00.000', original: 'a', pron: 'b', ko: 'c'),
      ];
      final validator = ClipValidator();
      expect(
          ClipValidator.blockedReason(
            filePath: '/tmp/a.mp4',
            folder: '여행',
            title: '오사카',
            segments: segments,
            durationMs: 8000,
          ),
          validator
              .validateForm(const ClipFormData(
                filePath: '/tmp/a.mp4',
                collectionName: '여행',
                clipTitle: '오사카',
                durationMs: 8000,
                segments: segments,
              ))
              .errorMessage);
    });

    test('버튼 아래 안내와 눌렀을 때 문구가 같다', () {
      final validator = ClipValidator();
      String? formMessage(ClipFormData form) =>
          validator.validateForm(form).errorMessage;

      expect(
          formMessage(const ClipFormData(
              filePath: null,
              collectionName: null,
              clipTitle: '',
              durationMs: null,
              segments: [])),
          ClipValidator.blockedReason(filePath: '', folder: '', title: ''));
    });
  });
}
