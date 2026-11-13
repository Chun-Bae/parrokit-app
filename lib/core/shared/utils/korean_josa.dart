/// 이름 뒤에 붙는 조사를 받침에 맞춰 고른다(5차). 예전엔 "'X'(으)로", "'X'를"처럼
/// 받침과 상관없이 한 가지로 붙여 '여행를'·'(으)로'가 그대로 보였다.
///
/// 한글 음절과 숫자는 받침을 보고 고른다. 그 밖의 글자(영어 등)로 끝나면 읽는
/// 소리를 알 수 없어 '을(를)'처럼 두 가지를 함께 쓴다.
library;

const _digitBatchim = {
  '0': true, '1': true, '2': false, '3': true, '4': false, //
  '5': false, '6': true, '7': true, '8': true, '9': false,
};
// 1(일)·7(칠)·8(팔)은 ㄹ 받침이라 '로'를 쓴다.
const _digitRieul = {'1', '7', '8'};

/// 받침이 있으면 true, 없으면 false, 알 수 없으면 null. ㄹ 받침이면 [rieul]이 true.
({bool? batchim, bool rieul}) _ending(String word) {
  // 따옴표·괄호로 감싼 이름('여행')은 안쪽 마지막 글자를 본다.
  final trimmed = word.replaceAll(RegExp(r'''[\s'"’”)\]]+$'''), '');
  if (trimmed.isEmpty) return (batchim: null, rieul: false);
  final last = trimmed.runes.last;
  if (last >= 0xAC00 && last <= 0xD7A3) {
    final jong = (last - 0xAC00) % 28;
    return (batchim: jong != 0, rieul: jong == 8);
  }
  final ch = String.fromCharCode(last);
  if (_digitBatchim.containsKey(ch)) {
    return (batchim: _digitBatchim[ch], rieul: _digitRieul.contains(ch));
  }
  return (batchim: null, rieul: false);
}

/// [word] + 을/를.
String eulReul(String word) => switch (_ending(word).batchim) {
      true => '$word을',
      false => '$word를',
      null => '$word을(를)',
    };

/// [word] + 이/가.
String iGa(String word) => switch (_ending(word).batchim) {
      true => '$word이',
      false => '$word가',
      null => '$word이(가)',
    };

/// [word] + 으로/로. ㄹ 받침은 '로'.
String euro(String word) {
  final e = _ending(word);
  if (e.batchim == null) return '$word(으)로';
  return e.batchim! && !e.rieul ? '$word으로' : '$word로';
}
