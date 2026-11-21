// 구독 Webhook이 보낸 값을 어떤 상태로 저장할지.
//
// 실행: functions에서 `npm run test:subscription`
import {test} from "node:test";
import assert from "node:assert/strict";
import {createRequire} from "node:module";
import {readFileSync} from "node:fs";

const require = createRequire(import.meta.url);
const {
  subscriptionFromEvent,
  shouldSkipEvent,
  authorized,
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

// 비밀값 검사(5차 527).
//
// 전에는 `if (expected && ...)`라 비밀값이 없으면 검사를 통째로 건너뛰었다.
// 실제로 설정돼 있지 않아서, 함수 주소만 알면 누구나 가짜 결제 이벤트를
// 넣어 맥스 단계와 패롯 700개를 받을 수 있었다.
test("헤더가 없으면 받지 않는다", () => {
  assert.equal(authorized(undefined, "s3cr3t"), false);
  assert.equal(authorized("", "s3cr3t"), false);
});

test("값이 다르면 받지 않는다", () => {
  assert.equal(authorized("wrong!", "s3cr3t"), false);
});

test("길이가 달라도 던지지 않고 거절한다", () => {
  // timingSafeEqual은 길이가 다르면 예외를 던진다. 그대로 두면 401이
  // 아니라 500이 나고, 보내는 쪽은 다시 보내 온다.
  assert.equal(authorized("s3cr3t-and-more", "s3cr3t"), false);
  assert.equal(authorized("s3c", "s3cr3t"), false);
});

test("같으면 받는다", () => {
  assert.equal(authorized("s3cr3t", "s3cr3t"), true);
});

test("비밀값이 없으면 통째로 거절한다", () => {
  // 설정을 빠뜨린 쪽이 뚫린 쪽보다 낫다. 코드에서 그 분기를 지킨다.
  const source = readFileSync(
    new URL("../src/subscriptionEvent.ts", import.meta.url),
    "utf8"
  );
  assert.ok(source.includes("webhook secret not configured"));
  // 왜 그렇게 뒀는지는 주석이 설명하므로, 실제로 도는 줄만 본다.
  const code = source
    .split("\n")
    .filter((line) => {
      const t = line.trimStart();
      return !t.startsWith("//") && !t.startsWith("*") && !t.startsWith("/*");
    })
    .join("\n");
  assert.ok(
    !code.includes("if (expected && "),
    "비밀값이 없을 때 검사를 건너뛰면 안 된다"
  );
  assert.ok(code.includes("secrets: [webhookSecret]"));
});

// 대시보드 'Send test event'가 가짜 사용자 문서를 만들던 것(5차 528).
//
// 테스트 본문의 app_user_id는 임시 id 접두사가 없는 그냥 UUID라
// $RCAnonymousID 걸름을 지나갔다. 그대로 두면 누를 때마다
// users/<그 UUID>에 subscription이 적힌다.
test("대시보드 테스트 이벤트는 반영하지 않는다", () => {
  const out = subscriptionFromEvent({
    event: {
      ...base,
      id: "E384B1B2-18CF-4D24-9086-31FD1AE6DD84",
      app_user_id: "cc24ac1a-12be-4a95-9aac-7358aeead2f7",
      type: "TEST",
      entitlement_ids: null,
    },
  });
  assert.equal(out, null);
});

test("진짜 이벤트는 그대로 받는다", () => {
  const out = subscriptionFromEvent({event: {...base, type: "INITIAL_PURCHASE"}});
  assert.notEqual(out, null);
  assert.equal(out.tier, "light");
});

