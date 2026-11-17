// 코인을 사는 흐름의 안내(5차 425).
//
// 같은 흐름이 두 곳에 있다. 더보기의 코인 상품 목록(coin_store_section)과
// RevenueCat 페이월(payment_section)이다. 네 가지 안내를 각자 적고 있어서
// 한쪽만 다듬으면 돈이 오가는 자리에서 말이 갈린다.

/// 상품을 불러오지 못했을 때.
const String productLoadFailedMessage = '상품 정보를 불러오지 못했어요. 잠시 뒤 다시 시도해 주세요.';

/// 결제가 끝나고 코인을 넣었을 때.
String coinsAddedMessage(int coins) => '$coins코인이 충전됐어요!';

/// 결제가 되지 않았을 때(사용자가 그만둔 경우는 알리지 않는다).
const String paymentFailedMessage = '결제에 실패했어요. 다시 시도해 주세요.';

/// 돈은 나갔는데 코인을 넣지 못했을 때. 조용히 넘어가면 사용자는 돈을 내고
/// 아무것도 못 받은 채 까닭도 모른다.
const String coinsNotGivenMessage =
    '결제는 됐지만 코인 지급에 실패했어요. 앱을 다시 켜 보고, 그래도 안 되면 문의해 주세요.';
