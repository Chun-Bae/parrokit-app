// 레벨 보따리를 서버가 지급한다(5차 568).
//
// 표가 고정돼 있어 평생 받는 총량이 정해져 있다. 거짓 레벨을 보내도
// 표 바깥으로는 못 간다.
//
// 실행: functions에서 `npm run test:level`
import {test} from "node:test";
import assert from "node:assert/strict";
import {createRequire} from "node:module";
import {readFileSync} from "node:fs";

const require = createRequire(import.meta.url);
const {
  LEVEL_REWARDS,
  LEVEL_REWARD_TOTAL,
  rewardBetween,
  levelOf,
  levelRewardKey,
} = require("../lib/levelReward.js");

test("오른 구간의 것만 더한다", () => {
  assert.equal(rewardBetween(1, 4), 0);
  assert.equal(rewardBetween(4, 5), 300);
  assert.equal(rewardBetween(1, 10), 1600); // 5·7·10
  assert.equal(rewardBetween(10, 10), 0);
});

test("평생 총량이 표에 묶여 있다", () => {
  assert.equal(LEVEL_REWARD_TOTAL, 4900);
  assert.equal(rewardBetween(0, 99), LEVEL_REWARD_TOTAL);
});

// 거짓 레벨을 보내도 표 바깥으로는 못 간다.
test("레벨을 1~99로 끊는다", () => {
  assert.equal(levelOf(5), 5);
  assert.equal(levelOf(0), 1);
  assert.equal(levelOf(-7), 1);
  assert.equal(levelOf(99999), 99);
  assert.equal(levelOf("스물"), 1);
  assert.equal(levelOf(undefined), 1);
  assert.equal(levelOf(Infinity), 1);
  assert.equal(levelOf(7.9), 7);
});

test("앱의 보따리 표와 값이 같다", () => {
  const dart = readFileSync("../lib/core/content/parrot_level.dart", "utf8");
  const found = {};
  for (const m of dart.matchAll(/^\s*(\d+):\s*(\d+),/gm)) {
    found[Number(m[1])] = Number(m[2]);
  }
  const server = {};
  for (const [k, v] of Object.entries(LEVEL_REWARDS)) server[Number(k)] = v;
  assert.deepEqual(found, server);
});

// 장부 키가 구간으로 고정돼 있다(5차).
//
// 전에는 앱이 보낸 requestId로 키를 만들었다. 앱은 부를 때마다 새 id를
// 만드니 같은 구간을 두 번 불러도 키가 달라, 겹침을 막는 것이
// levelRewardClaimed 하나뿐이었다.
test("같은 구간은 같은 장부 키를 쓴다", () => {
  assert.equal(levelRewardKey(4, 7), "level_reward_4_7");
  assert.equal(levelRewardKey(4, 7), levelRewardKey(4, 7));
  assert.notEqual(levelRewardKey(4, 7), levelRewardKey(7, 10));
});

// 지급이 터졌는데 '받은 것'으로만 남으면 그 보따리는 영영 안 들어온다.
// 적어 두기와 지급이 다른 트랜잭션이라, 터지면 되돌려야 한다.
test("지급이 터지면 적어 둔 레벨을 되돌린다", () => {
  const src = readFileSync("src/levelReward.ts", "utf8");
  // 장부 키에 requestId를 쓰지 않는다.
  assert.ok(!/key: `level_reward_\$\{requestIdOf/.test(src));
  assert.match(src, /key: levelRewardKey\(decided\.from, decided\.claimed\)/);
  // applyLedger를 try로 감싸고, catch에서 from으로 되돌린다.
  assert.match(src, /} catch \(error\) {[\s\S]*levelRewardClaimed: decided\.from/);
  assert.match(src, /} catch \(error\) {[\s\S]*throw error;/);
});
