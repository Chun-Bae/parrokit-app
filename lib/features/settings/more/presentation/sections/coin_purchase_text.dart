// 코인을 사는 흐름의 안내(5차 425).
//
// 같은 흐름이 두 곳에 있다. 더보기의 코인 상품 목록(coin_store_section)과
// RevenueCat 페이월(payment_section)이다. 네 가지 안내를 각자 적고 있어서
// 한쪽만 다듬으면 돈이 오가는 자리에서 말이 갈린다.

/// 상품을 불러오지 못했을 때.
const String productLoadFailedMessage = '상품 정보를 불러오지 못했어요. 잠시 뒤 다시 시도해 주세요.';

/// 결제가 끝나고 코인을 넣었을 때.
///
/// 앱이 직접 넣던 때의 말이다. 지금은 서버가 넣으므로 [coinsComingMessage]를
/// 쓴다. 광고 보상 쪽도 같은 꼴이다(5차 568).
String coinsAddedMessage(int coins) => '$coins코인이 충전됐어요!';

/// 결제가 끝났고, 지급은 서버가 할 때.
///
/// 앱이 스스로 패롯을 넣지 않는다. 영수증을 확인하는 곳이 없어서, 결제를
/// 거치지 않고 자기 문서의 parrots를 올려도 그대로 패롯이 됐다. 패롯은
/// Whisper·Gemini·R2를 쓰는 값이라 그만큼 서버 비용이 나간다(5차 568).
///
/// 이제 RevenueCat 웹훅을 받은 서버가 넣고, 잔액은 사용자 문서를 구독하는
/// 쪽에서 곧 바뀐다.
String coinsComingMessage(int coins) => '패롯 $coins개를 곧 받아요!';

/// 결제가 되지 않았을 때(사용자가 그만둔 경우는 알리지 않는다).
const String paymentFailedMessage = '결제에 실패했어요. 다시 시도해 주세요.';
