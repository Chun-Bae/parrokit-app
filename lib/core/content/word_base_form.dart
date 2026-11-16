// 문장에서 고른 낱말의 원형을 짐작한다(5차, 사용자 질문).
//
// 예문에 'projections'가 있는데 단어장에는 'projection'이 있으면, 그대로
// 저장하면 같은 단어가 둘이 된다. 자동으로 바꾸지는 않는다. 짐작한 원형이
// 단어장에 이미 있을 때만 사용자에게 묻는다.
//
// 영어만 본다. 다른 언어는 어형이 달라 섣불리 자르면 더 틀린다.

/// 이 언어에서 원형을 짐작할 수 있는지.
bool canGuessBaseForm(String language) => language.trim() == '영어';

/// [word]의 원형 후보들(가장 그럴듯한 것부터). 규칙에 걸리지 않으면 빈 목록.
///
/// 짐작일 뿐이라 여러 개를 돌려주고, 쓰는 쪽에서 단어장에 있는 것만 고른다.
List<String> guessBaseForms(String word) {
  final w = word.trim().toLowerCase();
  if (w.length < 4 || w.contains(' ')) return const [];

  final out = <String>[];
  void add(String candidate) {
    if (candidate.length >= 2 && candidate != w && !out.contains(candidate)) {
      out.add(candidate);
    }
  }

  // 복수·3인칭 -ies → -y (studies → study)
  if (w.endsWith('ies')) add('${w.substring(0, w.length - 3)}y');
  // -es (boxes → box, watches → watch)
  if (w.endsWith('es')) {
    final stem = w.substring(0, w.length - 2);
    if (stem.endsWith('s') ||
        stem.endsWith('x') ||
        stem.endsWith('z') ||
        stem.endsWith('ch') ||
        stem.endsWith('sh')) {
      add(stem);
    }
  }
  // 그냥 -s (projections → projection). -ss는 아니다(class).
  if (w.endsWith('s') && !w.endsWith('ss') && !w.endsWith('us')) {
    add(w.substring(0, w.length - 1));
  }
  // 과거 -ied → -y (tried → try)
  if (w.endsWith('ied')) add('${w.substring(0, w.length - 3)}y');
  // 과거 -ed (worked → work, liked → like)
  if (w.endsWith('ed')) {
    final stem = w.substring(0, w.length - 2);
    add(stem);
    add('${stem}e');
    add(_undouble(stem));
  }
  // 진행형 -ing (working → work, making → make, running → run)
  if (w.endsWith('ing')) {
    final stem = w.substring(0, w.length - 3);
    add(stem);
    add('${stem}e');
    add(_undouble(stem));
  }
  return out;
}

/// 끝 자음이 겹치면 하나로(running → run). 아니면 그대로.
String _undouble(String stem) {
  if (stem.length < 3) return stem;
  final last = stem[stem.length - 1];
  if (last == stem[stem.length - 2] && !'aeiou'.contains(last)) {
    return stem.substring(0, stem.length - 1);
  }
  return stem;
}
