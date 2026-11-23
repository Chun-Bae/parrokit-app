/**
 * 패롯 충전(1회성 구매)을 서버가 지급한다(5차 568).
 *
 * 전에는 앱이 결제 콜백에서 바로 Firestore에 패롯을 더했다
 * (payment_section.dart의 `addCoins`). 영수증을 확인하는 곳이 어디에도
 * 없어서, 결제를 거치지 않고도 자기 문서의 parrots를 올리면 그대로 패롯이
 * 됐다. 패롯은 자동 자막(Whisper)·예문 생성(Gemini)·R2 저장을 쓰는 값이라
 * 그만큼 **서버 비용**이 나간다.
 *
 * 이제 RevenueCat이 보내는 NON_RENEWING_PURCHASE 웹훅으로만 지급한다.
 * 영수증 확인은 RevenueCat이 하고, 우리는 그 이벤트 id로 한 번만 넣는다.
 */

import * as admin from "firebase-admin";
import {applyLedger} from "./wallet";

/**
 * 상품 id로 주는 패롯 수. 앱의 CoinPackage.packages와 같은 값이다.
 *
 * 값을 한쪽만 고치면 낸 돈과 받는 패롯이 어긋난다. 앱 쪽 표는
 * `lib/features/settings/more/data/coin_package.dart`에 있다.
 */
export const COIN_PACKAGES: Record<string, number> = {
  parrokit_coins_1: 88,
  parrokit_coins_3: 264,
  parrokit_coins_5: 440,
  parrokit_coins_10: 880,
};

/**
 * 이 상품으로 줄 패롯 수. 모르는 상품이면 null.
 *
 * 모르면 **주지 않는다**. 앱은 못 찾으면 첫 상품 기준으로 줬는데, 그러면
 * RevenueCat에만 상품을 추가했을 때 낸 돈과 받는 패롯이 조용히 어긋난다.
 * @param {string} productId 스토어 상품 id
 * @return {number | null} 줄 패롯 수
 */
export function coinsFor(productId: string): number | null {
  const coins = COIN_PACKAGES[productId];
  return typeof coins === "number" && coins > 0 ? coins : null;
}

/** 충전 웹훅에서 뽑아 낸 값. 읽을 수 없으면 null. */
export interface CoinPurchase {
  uid: string;
  productId: string;
  coins: number;
  eventId: string;
}

/**
 * 웹훅 본문에서 충전 정보를 뽑는다. 충전이 아니거나 읽을 수 없으면 null.
 * @param {unknown} body 요청 본문
 * @return {CoinPurchase | null} 지급할 내용
 */
export function coinPurchaseFromEvent(body: unknown): CoinPurchase | null {
  if (typeof body !== "object" || body === null) return null;
  const event = (body as {event?: unknown}).event;
  if (typeof event !== "object" || event === null) return null;
  const data = event as Record<string, unknown>;

  if (data.type !== "NON_RENEWING_PURCHASE") return null;

  const uid = typeof data.app_user_id === "string" ? data.app_user_id : "";
  if (!uid || uid.startsWith("$RCAnonymousID:")) return null;

  const productId =
    typeof data.product_id === "string" ? data.product_id : "";
  const coins = productId ? coinsFor(productId) : null;
  if (coins === null) return null;

  const eventId = typeof data.id === "string" && data.id.length > 0 ?
    data.id :
    `${uid}_${productId}_${
      typeof data.event_timestamp_ms === "number" ?
        Math.trunc(data.event_timestamp_ms) :
        0
    }`;

  return {uid, productId, coins, eventId};
}

/**
 * 충전한 패롯을 넣는다. 같은 이벤트로 두 번 들어오면 한 번만 넣는다.
 * @param {CoinPurchase} purchase 지급할 내용
 * @return {Promise<boolean>} 이번에 넣었으면 true
 */
export async function grantPurchasedParrots(
  purchase: CoinPurchase
): Promise<boolean> {
  const result = await applyLedger(
    purchase.uid,
    {parrots: purchase.coins},
    {
      key: `coin_purchase_${purchase.eventId}`,
      reason: "coin_purchase",
      meta: {productId: purchase.productId, coins: purchase.coins},
    }
  );
  return result.applied;
}

/**
 * 웹훅 본문에서 **충전 환불**을 뽑는다. 충전 환불이 아니면 null.
 *
 * RevenueCat은 1회성 구매를 물러 줄 때도 REFUND를 보낸다. 그 타입은
 * 구독 쪽 allowlist에도 들어 있어서, 가리지 않으면 구독 경로로 흘러가
 * entitlement가 없다는 이유로 **구독이 만료 처리되고 subParrots까지
 * 지워진다**(5차 568). 충전 상품에 대한 환불은 여기서 먼저 잡는다.
 * @param {unknown} body 요청 본문
 * @return {CoinPurchase | null} 회수할 내용
 */
export function coinRefundFromEvent(body: unknown): CoinPurchase | null {
  if (typeof body !== "object" || body === null) return null;
  const event = (body as {event?: unknown}).event;
  if (typeof event !== "object" || event === null) return null;
  const data = event as Record<string, unknown>;

  if (data.type !== "REFUND") return null;

  const uid = typeof data.app_user_id === "string" ? data.app_user_id : "";
  if (!uid || uid.startsWith("$RCAnonymousID:")) return null;

  const productId =
    typeof data.product_id === "string" ? data.product_id : "";
  // 충전 상품이 아니면 구독 환불이다. 구독 경로가 맡는다.
  const coins = productId ? coinsFor(productId) : null;
  if (coins === null) return null;

  const eventId = typeof data.id === "string" && data.id.length > 0 ?
    data.id :
    `${uid}_refund_${productId}_${
      typeof data.event_timestamp_ms === "number" ?
        Math.trunc(data.event_timestamp_ms) :
        0
    }`;

  return {uid, productId, coins, eventId};
}

/**
 * 환불한 충전분을 거둔다. 같은 이벤트로 두 번 와도 한 번만 거둔다.
 *
 * **있는 만큼만 거둔다.** 이미 써 버렸으면 지갑이 음수가 되는데,
 * writeWallet이 그때 던져서 회수 자체가 통째로 실패한다. 못 거둔 몫은
 * 로그로 남긴다 - 쓴 것을 되돌릴 수는 없다.
 *
 * 구독으로 받은 subParrots는 건드리지 않는다. 산 것은 보통 패롯이다.
 * @param {CoinPurchase} refund 회수할 내용
 * @return {Promise<number>} 이번에 거둔 수. 0이면 거둘 것이 없었다
 */
export async function revokeRefundedParrots(
  refund: CoinPurchase
): Promise<number> {
  const snapshot = await admin
    .firestore()
    .collection("users")
    .doc(refund.uid)
    .get();
  const raw = snapshot.data()?.parrots ?? snapshot.data()?.coins;
  const own = typeof raw === "number" ? Math.trunc(raw) : 0;
  const take = Math.min(refund.coins, Math.max(0, own));

  if (take < refund.coins) {
    console.warn(
      `[CoinRefund] partial revoke uid=${refund.uid} ` +
        `product=${refund.productId} refunded=${refund.coins} taken=${take}`
    );
  }
  if (take <= 0) return 0;

  const result = await applyLedger(
    refund.uid,
    // 구독 몫에서 깎지 않는다. 산 것은 보통 패롯이다.
    {parrots: -take, subFirst: false},
    {
      key: `coin_refund_${refund.eventId}`,
      reason: "coin_refund",
      meta: {
        productId: refund.productId,
        refunded: refund.coins,
        taken: take,
      },
    }
  );
  return result.applied ? take : 0;
}
