// 시트 안에서 알리는 말은 시트 안에 보여야 한다 — 남아 있던 세 곳(5차 391).
//
// 368~371, 390에서 같은 문제를 고쳤는데 세 곳이 남아 있었다.
// 단어 추가 시트의 '웹에서 찾기', 그룹·폴더 묶기 시트, 목소리 고르기 시트.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/library/presentation/widgets/group_collection_manager_modal.dart'
    show groupCollectionSaveFailed;
import 'package:parrokit/features/content-studio/tts/presentation/widgets/tts_voice_selection_sheet.dart'
    show voicePreviewFailed;

String _read(String path) => File(path).readAsStringSync();

/// 주석을 뺀 줄만 돌려준다. 까닭을 적은 주석이 걸리지 않게.
Iterable<String> _codeLines(String source) =>
    source.split('\n').where((l) => !l.trimLeft().startsWith('//'));

/// [needle]이 들어 있는 줄 번호. 주석 줄은 뺀다.
Iterable<int> _lineNumbersWith(String source, String needle) {
  final lines = source.split('\n');
  return [
    for (final (i, line) in lines.indexed)
      if (!line.trimLeft().startsWith('//') && line.contains(needle)) i,
  ];
}

/// [at] 줄을 품고 있는 메서드의 선언 줄. 못 찾으면 빈 문자열.
/// if·for 같은 흐름 제어 줄은 건너뛴다.
const List<String> _notMethodStarts = [
  'if',
  'else',
  'for',
  'while',
  'switch',
  'case',
  'try',
  'catch',
  'finally',
  'do',
  'return',
];

String _enclosingMethod(String source, int at) {
  final lines = source.split('\n');
  for (var i = at; i >= 0; i--) {
    final line = lines[i].trim();
    if (!line.endsWith('{') || !line.contains('(')) continue;
    if (line.startsWith('//')) continue;
    final head = line.split(RegExp(r'[ (]')).first;
    if (_notMethodStarts.contains(head)) continue;
    return line.substring(0, line.length - 1).trim();
  }
  return '';
}

void main() {
  test('단어 추가 시트는 토스트를 쓰지 않는다', () {
    final source = _read('lib/features/collection/shell/presentation/'
        'widgets/word_collection_preview.dart');
    // 띄워 둔 시트 위에서 부르는 토스트만 막는다. 창이 사라진 뒤에 부르는
    // dispose 안은 가려질 것이 없으므로 그대로 둔다(5차 515).
    for (final at in _lineNumbersWith(source, 'showToast')) {
      expect(_enclosingMethod(source, at), 'void dispose()',
          reason: '시트 안에서 띄운 토스트는 시트 뒤에 깔려 보이지 않는다');
    }
    // 찾을 단어가 없다는 말도 시트 안 자리(word-fill-note)에 적는다.
    expect(source.contains('fillNote = wordSearchNeedsWordHint'), isTrue);
  });

  test('그룹·폴더 묶기 시트는 저장하면 닫고, 실패하면 시트 안에 적는다', () {
    final source = _read('lib/features/collection/library/presentation/'
        'widgets/group_collection_manager_modal.dart');
    // 두 탭 모두 저장 뒤 시트를 닫는다. 전에는 '폴더 기준' 탭만 닫지 않아
    // 알리는 말이 시트 뒤에 깔렸다.
    expect('Navigator.of(context).pop()'.allMatches(source).length, 2);
    expect(source.contains("ValueKey('group-collection-error')"), isTrue);
    expect(groupCollectionSaveFailed, '저장하지 못했어요. 잠시 뒤 다시 해 주세요.');
  });

  test('목소리 고르기 시트는 미리듣기 실패를 시트 안에 적는다', () {
    final source = _read('lib/features/content-studio/tts/presentation/'
        'widgets/tts_voice_selection_sheet.dart');
    expect(_codeLines(source).where((l) => l.contains('showToast')), isEmpty);
    expect(source.contains("ValueKey('voice-preview-error')"), isTrue);
    expect(voicePreviewFailed, '미리듣기를 재생하지 못했어요.');
  });
}
