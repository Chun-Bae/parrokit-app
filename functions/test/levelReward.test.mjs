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
