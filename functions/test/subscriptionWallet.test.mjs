// 구독 패롯이 실제 지갑에서 어떻게 들어오고 깎이고 사라지는지.
// Firestore 에뮬레이터 위에서 돈다. 실행: functions에서 `npm run test:subwallet`
import {test, beforeEach} from "node:test";
import assert from "node:assert/strict";
import {createRequire} from "node:module";

const require = createRequire(import.meta.url);
const admin = require("firebase-admin");
admin.initializeApp({projectId: "demo-parrokit"});
const db = admin.firestore();
const {applyLedger, exchangeCurrency} = require("../lib/wallet.js");
const {
  grantSubscriptionParrots,
  expireSubscriptionParrots,
} = require("../lib/subscriptionGrant.js");

const user = (uid) => db.collection("users").doc(uid);
const balance = async (uid) => {
  const data = (await user(uid).get()).data() ?? {};
  return {
    parrots: data.parrots ?? 0,
    crackers: data.crackers ?? 0,
    subParrots: data.subParrots ?? 0,
  };
};
const ledger = async (uid) =>
  (await user(uid).collection("wallet_ledger").get()).docs.map((d) => d.id);

const state = (over = {}) => ({
  uid: "uid-1",
  tier: "light",
  status: "active",
  periodEnd: 1764000000000,
  store: "APP_STORE",
  eventId: "evt-1",
  eventAtMs: 1763000000000,
  ...over,
});

const call = (fn, uid, data) =>
  fn.run({auth: {uid, token: {}}, data, rawRequest: {}});

beforeEach(async () => {
  const response = await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/demo-parrokit/databases/(default)/documents`,
    {method: "DELETE"}
  );
  assert.ok(response.ok);
});

test("구독하면 그 단계 몫이 구독 패롯으로 들어온다", async () => {
  await user("uid-1").set({parrots: 5});

  assert.equal(await grantSubscriptionParrots(state()), 100);

  assert.deepEqual(await balance("uid-1"), {
    parrots: 5,
    crackers: 0,
    subParrots: 100,
  });
  assert.deepEqual(await ledger("uid-1"), ["sub_grant_light_1764000000000"]);
});

test("같은 기간에 이벤트가 또 와도 한 번만 준다", async () => {
  await grantSubscriptionParrots(state());
  assert.equal(await grantSubscriptionParrots(state({eventId: "evt-2"})), 0);

  assert.equal((await balance("uid-1")).subParrots, 100);
});

test("다음 기간에는 또 준다", async () => {
  await grantSubscriptionParrots(state());
  await grantSubscriptionParrots(state({periodEnd: 1766592000000}));

  assert.equal((await balance("uid-1")).subParrots, 200);
  assert.equal((await ledger("uid-1")).length, 2);
});

test("쓸 때는 구독 패롯부터 깎이고, 모자라면 보통 패롯에서 뺀다", async () => {
  await user("uid-1").set({parrots: 50});
  await grantSubscriptionParrots(state());

  await applyLedger("uid-1", {parrots: -30}, {key: "tts_1", reason: "tts"});
  assert.deepEqual(await balance("uid-1"), {
    parrots: 50,
    crackers: 0,
    subParrots: 70,
  });

  await applyLedger("uid-1", {parrots: -100}, {key: "tts_2", reason: "tts"});
  assert.deepEqual(await balance("uid-1"), {
    parrots: 20,
    crackers: 0,
    subParrots: 0,
  });
});

test("둘을 합쳐도 모자라면 아무것도 깎지 않는다", async () => {
  await user("uid-1").set({parrots: 5});
  await grantSubscriptionParrots(state());

  await assert.rejects(
    applyLedger("uid-1", {parrots: -200}, {key: "tts_3", reason: "tts"}),
    (error) => error.code === "failed-precondition"
  );
  assert.deepEqual(await balance("uid-1"), {
    parrots: 5,
    crackers: 0,
    subParrots: 100,
  });
});

test("기간이 끝나면 남은 구독 패롯은 사라지고 보통 패롯은 남는다", async () => {
  await user("uid-1").set({parrots: 7});
  await grantSubscriptionParrots(state());

  const removed = await expireSubscriptionParrots(
    state({status: "expired", tier: "free"})
  );

  assert.equal(removed, 100);
  assert.deepEqual(await balance("uid-1"), {
    parrots: 7,
    crackers: 0,
    subParrots: 0,
  });
});

test("구독으로 받은 패롯은 환전하지 못한다", async () => {
  await user("uid-1").set({parrots: 1});
  await grantSubscriptionParrots(state());

  await assert.rejects(
    call(exchangeCurrency, "uid-1", {
      direction: "parrotsToCrackers",
      amount: 10,
      requestId: "req_abcdefgh",
    }),
    (error) => error.code === "failed-precondition"
  );

  // 가진 패롯만큼은 그대로 바꿀 수 있고, 구독 패롯은 건드리지 않는다.
  await call(exchangeCurrency, "uid-1", {
    direction: "parrotsToCrackers",
    amount: 1,
    requestId: "req_ijklmnop",
  });
  assert.deepEqual(await balance("uid-1"), {
    parrots: 0,
    crackers: 1000,
    subParrots: 100,
  });
});
