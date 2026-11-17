// 머리줄에 적는 개수(5차 483).
//
// 단어 탭에서 고친 것과 같은 결함이 클립 탭에도 있었다. 갈래나 태그로
// 거르면 아래 목록은 줄어드는데 머리줄은 전체를 세고 있어, 어느 쪽이
// 맞는지 알 수 없었다. 거르는 중이면 '보이는 수 / 전체 수'로 적는다.

/// [filtered]가 참이면 '$shown / $all$suffix', 아니면 '$all$suffix'.
String filteredCountLabel({
  required int shown,
  required int all,
  required bool filtered,
  String suffix = '',
}) =>
    filtered ? '$shown / $all$suffix' : '$all$suffix';
