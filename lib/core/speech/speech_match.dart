/// 비교를 위해 공백, 문장부호를 없애고 소문자로 맞춘다.
String normalizeForMatch(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'[\s\p{P}\p{S}]', unicode: true), '');

/// 두 글자열에서 순서를 지킨 채 겹치는 글자 수(LCS).
int _commonLength(List<int> a, List<int> b) {
  var previous = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0);
    for (var j = 1; j <= b.length; j++) {
      current[j] = a[i - 1] == b[j - 1]
          ? previous[j - 1] + 1
          : (previous[j] > current[j - 1] ? previous[j] : current[j - 1]);
    }
    previous = current;
  }
  return previous[b.length];
}

/// 들은 문장이 목표 문장을 얼마나 따라 했는지 0~1로 돌려준다.
/// 순서를 지킨 공통 글자 수(LCS)를 목표 길이로 나눈다.
double speechMatchScore(String target, String heard) {
  final a = normalizeForMatch(target).runes.toList();
  final b = normalizeForMatch(heard).runes.toList();
  if (a.isEmpty || b.isEmpty) return 0;
  return _commonLength(a, b) / a.length;
}

/// 두 문장이 얼마나 같은 문장인지 0~1로 돌려준다. 어느 쪽이 길어도 같은 값이다.
double sentenceSimilarity(String a, String b) {
  final x = normalizeForMatch(a).runes.toList();
  final y = normalizeForMatch(b).runes.toList();
  if (x.isEmpty || y.isEmpty) return 0;
  return _commonLength(x, y) / (x.length > y.length ? x.length : y.length);
}

/// 이 점수 이상이면 따라 말하기를 성공으로 본다.
const speechPassScore = 0.8;
