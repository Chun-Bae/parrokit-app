// 패롯을 쓰는 일을 시작하기 전에 붙이는 말.
//
// 값을 치르는 자리마다 따로 적다 보면 한쪽만 고쳐진다(5차에 여러 번 겪었다).
// 자동 자막·음성 만들기가 같은 말을 쓴다.

/// 가진 패롯으로 모자랄 때 알려 줄 한 줄. 넉넉하면 null.
String? parrotShortfallLine({required int cost, required int coins}) {
  if (cost <= 0 || coins >= cost) return null;
  return '지금 패롯이 $coins개예요. ${cost - coins}개가 더 있어야 해요.';
}
