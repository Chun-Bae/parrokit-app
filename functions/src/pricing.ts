/* eslint-disable require-jsdoc */
// 콘텐츠 제작 기능의 패롯 가격. 앱의 표와 같은 값이어야 한다.
//
// - TTS: lib/features/content-studio/tts/domain/models/tts_*_models.dart
// - 영상: lib/features/content-studio/video/domain/models/
//   video_generation_models.dart
// - 자막: captioning_provider.dart의 _calculateCoinCost
//
// 앱은 이 값으로 "예상 패롯"을 보여주고, 실제로 깎는 양은 여기서 정한다.
// 가격을 바꾸면 양쪽을 함께 바꾼다.

const GOOGLE_TTS_CHARS_PER_PARROT = 100;

const ELEVENLABS_CHARS_PER_PARROT: Record<string, number> = {
  "eleven_multilingual_v2": 20,
  "eleven_turbo_v2_5": 40,
};
const ELEVENLABS_DEFAULT_MODEL = "eleven_multilingual_v2";

const GEMINI_TTS_CHARS_PER_PARROT: Record<string, number> = {
  "gemini-2.5-flash-preview-tts": 120,
  "gemini-3.1-flash-tts-preview": 60,
  "gemini-2.5-pro-preview-tts": 60,
};
const GEMINI_TTS_DEFAULT_MODEL = "gemini-2.5-flash-preview-tts";

/**
 * 앱이 모르는 모델 id가 오면 그 엔진에서 가장 비싼 값으로 받는다.
 * 서버는 받은 모델을 그대로 부르므로, 싼 값으로 받으면 비싼 모델을
 * 싸게 쓰는 길이 된다.
 * @param {Record<string, number>} table 모델별 1패롯당 글자 수
 * @param {string} modelId 모델 id
 * @return {number} 1패롯당 글자 수
 */
function charsPerParrot(table: Record<string, number>, modelId: string) {
  return table[modelId] ?? Math.min(...Object.values(table));
}

export function ttsCost(input: {
  text?: unknown;
  provider?: unknown;
  modelId?: unknown;
}): number {
  const length = typeof input.text === "string" ? input.text.length : 0;
  if (length <= 0) return 0;
  const modelId = typeof input.modelId === "string" ? input.modelId : "";
  let rate: number;
  switch (input.provider) {
  case "elevenlabs":
    rate = charsPerParrot(
      ELEVENLABS_CHARS_PER_PARROT,
      modelId || ELEVENLABS_DEFAULT_MODEL
    );
    break;
  case "gemini":
    rate = charsPerParrot(
      GEMINI_TTS_CHARS_PER_PARROT,
      modelId || GEMINI_TTS_DEFAULT_MODEL
    );
    break;
  default:
    rate = GOOGLE_TTS_CHARS_PER_PARROT;
  }
  return Math.max(1, Math.ceil(length / rate));
}

const VEO_COST_PER_SECOND: Record<string, {p720: number; p1080: number}> = {
  "veo-3.1-lite-generate-preview": {p720: 11, p1080: 17},
  "veo-3.1-fast-generate-preview": {p720: 21, p1080: 26},
  "veo-3.1-generate-preview": {p720: 86, p1080: 86},
};

/**
 * 정규화된 모델 id·해상도·길이로 계산한다. 모르는 모델은 가장 비싼 값.
 * @param {string} modelId 정규화된 Veo 모델 id
 * @param {string} resolution 720p 또는 1080p
 * @param {number} durationSeconds 길이(초)
 * @return {number} 패롯
 */
export function videoCost(
  modelId: string,
  resolution: string,
  durationSeconds: number
): number {
  if (durationSeconds <= 0) return 0;
  const rates =
    VEO_COST_PER_SECOND[modelId] ??
    VEO_COST_PER_SECOND["veo-3.1-generate-preview"];
  const perSecond = resolution === "1080p" ? rates.p1080 : rates.p720;
  return perSecond * durationSeconds;
}

/**
 * 10초에 1패롯, 올림.
 * @param {number} durationMs 길이(밀리초)
 * @return {number} 패롯
 */
export function captionCost(durationMs: number): number {
  const seconds = Math.ceil(durationMs / 1000);
  if (seconds <= 0) return 0;
  return Math.floor((seconds + 9) / 10);
}
