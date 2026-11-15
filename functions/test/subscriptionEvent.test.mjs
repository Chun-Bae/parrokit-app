// 구독 Webhook이 보낸 값을 어떤 상태로 저장할지.
//
// 실행: functions에서 `npm run test:subscription`
import {test} from "node:test";
import assert from "node:assert/strict";
import {createRequire} from "node:module";

const require = createRequire(import.meta.url);
const {
  subscriptionFromEvent,
  shouldSkipEvent,
  LIGHT_ENTITLEMENT,
  PRO_ENTITLEMENT,
} = require("../lib/subscriptionEvent.js");

const base = {
  id: "evt-1",
  app_user_id: "uid-1",
  type: "INITIAL_PURCHASE",
  entitlement_ids: [LIGHT_ENTITLEMENT],
  expiration_at_ms: 1764000000000,
  event_timestamp_ms: 1763000000000,
  store: "APP_STORE",
};

const event = (over = {}) => ({event: {...base, ...over}});

test("산 사람은 그 단계로 둔다", () => {
  const state = subscriptionFromEvent(event());
  assert.equal(state.uid, "uid-1");
  assert.equal(state.tier, "light");
  assert.equal(state.status, "active");
  assert.equal(state.periodEnd, 1764000000000);
  assert.equal(state.store, "APP_STORE");
});

test("프로가 라이트보다 앞선다", () => {
  const state = subscriptionFromEvent(
    event({entitlement_ids: [LIGHT_ENTITLEMENT, PRO_ENTITLEMENT]})
  );
  assert.equal(state.tier, "pro");
});

test("갱신도 그대로 쓸 수 있다", () => {
  const state = subscriptionFromEvent(event({type: "RENEWAL"}));
  assert.equal(state.status, "active");
  assert.equal(state.tier, "light");
});

test("결제가 밀리면 유예, 혜택은 남는다", () => {
  const state = subscriptionFromEvent(event({type: "BILLING_ISSUE"}));
  assert.equal(state.status, "grace");
  assert.equal(state.tier, "light");
});

test("해지를 예약하면 기간이 끝날 때까지 쓴다", () => {
  const state = subscriptionFromEvent(event({type: "CANCELLATION"}));
  assert.equal(state.status, "canceled");
  assert.equal(state.tier, "light");
});

test("끝나거나 환불되면 무료로 내린다", () => {
  for (const type of ["EXPIRATION", "REFUND", "SUBSCRIPTION_PAUSED"]) {
    const state = subscriptionFromEvent(event({type}));
    assert.equal(state.status, "expired", type);
    assert.equal(state.tier, "free", type);
  }
});

test("entitlement가 없으면 무료다", () => {
  const state = subscriptionFromEvent(event({entitlement_ids: []}));
  assert.equal(state.tier, "free");
  assert.equal(state.status, "expired");
});

test("우리 계정이 아닌 이벤트는 건너뛴다", () => {
  assert.equal(subscriptionFromEvent(event({app_user_id: ""})), null);
  assert.equal(
    subscriptionFromEvent(event({app_user_id: "$RCAnonymousID:abc"})),
    null
  );
  assert.equal(subscriptionFromEvent({}), null);
  assert.equal(subscriptionFromEvent(null), null);
  assert.equal(subscriptionFromEvent({event: {type: "RENEWAL"}}), null);
});

test("id가 없으면 계정·종류·시각으로 만든다", () => {
  const state = subscriptionFromEvent(event({id: undefined}));
  assert.equal(state.eventId, "uid-1_INITIAL_PURCHASE_1763000000000");
});

test("같은 이벤트가 또 오면 건너뛴다", () => {
  const next = subscriptionFromEvent(event());
  assert.equal(shouldSkipEvent({lastEventId: "evt-1"}, next), true);
  assert.equal(shouldSkipEvent({lastEventId: "evt-0"}, next), false);
  assert.equal(shouldSkipEvent(undefined, next), false);
});

test("늦게 도착한 옛 이벤트는 새 상태를 덮지 않는다", () => {
  const next = subscriptionFromEvent(event({id: "evt-2"}));
  const saved = {lastEventId: "evt-3", lastEventAtMs: next.eventAtMs + 1000};
  assert.equal(shouldSkipEvent(saved, next), true);

  const older = {lastEventId: "evt-0", lastEventAtMs: next.eventAtMs - 1000};
  assert.equal(shouldSkipEvent(older, next), false);
});

test("기간 끝 시각을 모르면 null로 둔다", () => {
  const state = subscriptionFromEvent(event({expiration_at_ms: null}));
  assert.equal(state.periodEnd, null);
});
