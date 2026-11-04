/// 사용자가 직접 복사해 붙여넣은 영상 스크립트를 문장 목록으로 나눈다.
///
/// 시간 표시(`0:12`, `1:02:03`)와 `[Music]`·`(박수)` 같은 소리 설명을 지우고,
/// 문장부호가 있으면 문장부호로, 없으면 줄 단위로 자른다.
class ScriptSplitter {
  const ScriptSplitter._();

  static final _timestamp = RegExp(r'(^|\s)\d{1,2}:\d{2}(:\d{2})?(?=\s|$)');
  static final _soundTag = RegExp(r'[\[(（【][^\])）】\n]{0,30}[\])）】]');
  static final _terminator = RegExp(r'[.?!。？！…]');
  static final _sentenceEnd = RegExp(r'(?<=[.?!。？！…])["”’)\]]*\s+|(?<=[。？！])');

  /// 줄 수에 비해 문장부호가 이 비율보다 적으면 자막 조각으로 보고 줄 단위로 자른다.
  static const _punctuatedRatio = 0.4;

  static List<String> split(String raw) {
    final lines = [
      for (final line in raw.split(RegExp(r'\r?\n'))) _clean(line),
    ].where((line) => line.isNotEmpty).toList();
    if (lines.isEmpty) return const [];

    final terminators = lines
        .map((l) => _terminator.allMatches(l).length)
        .fold(0, (a, b) => a + b);
    final punctuated = terminators >= lines.length * _punctuatedRatio;
    final pieces = punctuated
        ? lines
            .join(' ')
            .splitMapJoin(
              _sentenceEnd,
              onMatch: (m) => '${m.group(0)!.trim()}\n',
              onNonMatch: (s) => s,
            )
            .split('\n')
        : lines;

    final seen = <String>{};
    return [
      for (final piece in pieces)
        if (piece.trim().length >= 2 && seen.add(piece.trim().toLowerCase()))
          piece.trim(),
    ];
  }

  static String _clean(String line) => line
      .replaceAll(_soundTag, ' ')
      .replaceAll(_timestamp, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
