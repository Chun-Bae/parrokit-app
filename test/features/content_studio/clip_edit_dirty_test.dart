// 편집으로 연 클립을 구경만 하고 나가도 경고가 떴다(5차 523).
//
// isUntouchedNew가 clipId == null을 요구해서 편집 모드는 아예 빠져 있었다.
// 파일 정보 칸을 펼쳤다 닫기만 해도 '지금 나가면 적은 내용이 모두 사라져요'가
// 떴다. 매번 뜨는 경고는 읽히지 않아서, 정작 고친 것이 있을 때도 그냥 눌러
// 버리게 된다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/content-studio/captioning/domain/models/clip_form_data.dart';

const _base = ClipFormData(
  collectionName: 'shorts-test',
  clipTitle: 'Shorts test clip v3',
  durationMs: 8000,
  filePath: '/tmp/a.mp4',
  tags: ['토익'],
  segments: [
    SegmentInput(
      start: '00:00.000',
      end: '00:08.000',
      original: 'The bell is invited to sound three times.',
      pron: '더 벨 이즈 인바이티드 투 사운드 쓰리 타임스.',
      ko: '종이 세 번 울리도록 초대되었습니다.',
    ),
  ],
);

void main() {
  test('아무것도 안 바꾸면 같은 줄이 나온다', () {
    expect(clipFormFingerprint(_base), clipFormFingerprint(_base));
  });

  test('제목을 고치면 줄이 달라진다', () {
    final changed = _base.copyWith(clipTitle: 'Shorts test clip v4');
    expect(clipFormFingerprint(changed) == clipFormFingerprint(_base), isFalse);
  });

  test('구간의 해석만 고쳐도 줄이 달라진다', () {
    final changed = _base.copyWith(segments: [
      _base.segments.first.copyWith(ko: '종이 세 번 울립니다.'),
    ]);
    expect(clipFormFingerprint(changed) == clipFormFingerprint(_base), isFalse);
  });

  test('태그를 더하면 줄이 달라진다', () {
    final changed = _base.copyWith(tags: ['토익', '회화']);
    expect(clipFormFingerprint(changed) == clipFormFingerprint(_base), isFalse);
  });

  test('구간을 하나 더해도 줄이 달라진다', () {
    final changed = _base.copyWith(segments: [
      ..._base.segments,
      const SegmentInput(
          start: '00:08.000', end: '00:10.000', original: 'Again.', pron: '', ko: ''),
    ]);
    expect(clipFormFingerprint(changed) == clipFormFingerprint(_base), isFalse);
  });

  test('나가기 확인은 편집 모드에서도 안 바뀐 것을 본다', () {
    final provider = File(
            'lib/features/content-studio/captioning/presentation/providers/captioning_provider.dart')
        .readAsStringSync();
    expect(provider, contains('bool get isUnchangedEdit'));
    // 불러오기가 끝난 뒤에 스냅샷을 적어야 한다. 안 적으면 늘 묻는다.
    expect(provider, contains('_loadedFingerprint = _formFingerprint()'));

    final screen = File(
            'lib/features/content-studio/captioning/presentation/screens/captioning_screen.dart')
        .readAsStringSync();
    expect(screen, contains('vm.isUntouchedNew || vm.isUnchangedEdit'));
  });
}
