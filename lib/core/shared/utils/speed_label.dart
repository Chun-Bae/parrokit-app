// 재생 속도·읽기 속도를 적는 말. 화면마다 '1.00x'처럼 영문 x를 쓰고 있었다.
// 앱의 다른 숫자(개·회·초)처럼 한국어로 적는다(5차).
//
// 쓸데없는 0은 떼고 적는다: 1 → '1배', 1.25 → '1.25배', 0.5 → '0.5배'.

String speedLabel(double speed) {
  final text = speed
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  return '$text배';
}
