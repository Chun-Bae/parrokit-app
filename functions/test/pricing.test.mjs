// Gemini TTS 모델 교체와 가격(5차). firebase-admin 없이 돈다.
import {test} from "node:test";
import assert from "node:assert/strict";
import {resolveGeminiTtsModel, ttsCost} from "../lib/pricing.js";

test("종료된 예전 TTS 모델 id는 대체 모델로 바꾼다", () => {
  assert.equal(resolveGeminiTtsModel("gemini-2.5-flash-preview-tts"), "gemini-3.8-flash-lite-tts");
  assert.equal(resolveGeminiTtsModel("gemini-3.1-flash-tts-preview"), "gemini-3.8-flash-tts");
  assert.equal(resolveGeminiTtsModel("gemini-2.5-pro-preview-tts"), "gemini-3.8-flash-tts");
});

test("새 모델은 그대로, 비었거나 모르는 값은 기본 모델", () => {
  assert.equal(resolveGeminiTtsModel("gemini-3.8-flash-lite-tts"), "gemini-3.8-flash-lite-tts");
  assert.equal(resolveGeminiTtsModel("gemini-3.8-flash-tts"), "gemini-3.8-flash-tts");
  assert.equal(resolveGeminiTtsModel(undefined), "gemini-3.8-flash-tts");
  assert.equal(resolveGeminiTtsModel("gemini-9-ultra"), "gemini-3.8-flash-tts");
});

test("가격은 실제로 부르는 모델 값으로 매긴다", () => {
  const text = "a".repeat(120);
  assert.equal(ttsCost({text, provider: "gemini", modelId: "gemini-3.8-flash-lite-tts"}), 1);
  assert.equal(ttsCost({text, provider: "gemini", modelId: "gemini-3.8-flash-tts"}), 2);
  // 예전 2.5 Flash는 Lite로 바뀌어 예전과 같은 값(120자당 1)
  assert.equal(ttsCost({text, provider: "gemini", modelId: "gemini-2.5-flash-preview-tts"}), 1);
});
