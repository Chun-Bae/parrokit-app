/* eslint-disable require-jsdoc */

import {onCall, HttpsError} from "firebase-functions/v2/https";
import {ENFORCE_APP_CHECK} from "./appCheck";
import {captionCost} from "./pricing";
import {applyLedger, requestIdOf} from "./wallet";
import {defineSecret} from "firebase-functions/params";
import {getStorage} from "firebase-admin/storage";
import {r2Delete, r2DownloadToFile, r2Head, r2Secrets} from "./r2Client";
import {promises as fs} from "fs";
import {tmpdir} from "os";
import {basename, extname, join} from "path";

const openaiApiKey = defineSecret("OPENAI_API_KEY");

const MAX_CAPTION_DURATION_MS = 5 * 60 * 1000;
const MAX_CAPTION_FILE_BYTES = 30 * 1024 * 1024;
const CAPTION_BATCH_SIZE = 5;
const OPENAI_ASR_ENDPOINT = "https://api.openai.com/v1/audio/transcriptions";
const OPENAI_CHAT_ENDPOINT = "https://api.openai.com/v1/chat/completions";
const OPENAI_CHAT_MODEL = "gpt-4o-mini";
const CAPTION_PROMPT_PATH = join(
  process.cwd(),
  "prompts",
  "generations",
  "caption-generation.prompt"
);

let captionDraftSystemPromptCache: string | undefined;

type CaptionEngine = "whisper";

interface CaptionRequest {
  storagePath: string;
  engine: CaptionEngine;
  durationMs: number;
}

interface AsrSegment {
  startMs: number;
  endMs: number;
  text: string;
}

interface CaptionSegment {
  start: string;
  end: string;
  original: string;
  pron: string;
  ko: string;
}

interface OpenAiErrorBody {
  error?: {
    code?: string;
    message?: string;
    param?: string;
    type?: string;
  };
}

export const generateCaptions = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    secrets: [openaiApiKey, ...r2Secrets],
    timeoutSeconds: 540,
    memory: "1GiB",
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "로그인이 필요해요.");
    }

    const input = parseCaptionRequest(request.data);
    validateCaptionRequest(uid, input);

    // 새 앱(serverCharge: true)은 만들기 전에 값 전체를 깎는다. 패롯이
    // 모자라면 여기서 멈춘다. 전에는 다 만든 뒤 가진 만큼만 깎아서, 패롯이
    // 0이면 자막을 공짜로 받을 수 있었다. 만들지 못하면 돌려준다.
    const serverCharge = request.data?.serverCharge === true;
    const requestId = requestIdOf(request.data?.requestId);
    const cost = serverCharge ? captionCost(input.durationMs) : 0;
    if (cost > 0) {
      await applyLedger(uid, {parrots: -cost}, {
        key: `caption_${requestId}`,
        reason: "caption",
        meta: {durationMs: input.durationMs},
      });
    }
    let produced = false;

    // 원본은 R2(caption-inputs/{uid}/...)에 있다. 옛 앱은 Firebase Storage에
    // 올리고 부르므로, R2에 없으면 그쪽을 본다.
    const legacyFile = getStorage().bucket().file(input.storagePath);
    const r2Info = await r2Head(input.storagePath);
    const useR2 = r2Info !== null;
    const tempPath = join(
      tmpdir(),
      `caption_${uid}_${Date.now()}${extname(input.storagePath) || ".bin"}`
    );

    try {
      let fileSize = 0;
      let sourceContentType: string | undefined;
      if (useR2) {
        fileSize = r2Info.size;
        sourceContentType = r2Info.contentType;
      } else {
        const [metadata] = await legacyFile.getMetadata();
        fileSize = Number(metadata.size ?? 0);
        sourceContentType = metadata.contentType;
      }
      if (!Number.isFinite(fileSize) || fileSize <= 0) {
        throw new HttpsError(
          "invalid-argument",
          "영상 크기를 읽지 못했어요. 다른 영상으로 해 보세요."
        );
      }
      if (fileSize > MAX_CAPTION_FILE_BYTES) {
        throw new HttpsError(
          "invalid-argument",
          "30MB 이하 영상만 자동 자막을 만들 수 있어요."
        );
      }

      if (useR2) {
        await r2DownloadToFile(input.storagePath, tempPath);
      } else {
        await legacyFile.download({destination: tempPath});
      }

      const apiKey = openaiApiKey.value();
      const asrSegments = await transcribeWithOpenAi({
        apiKey,
        filePath: tempPath,
        filename: basename(input.storagePath),
        contentType: sourceContentType || contentTypeFor(input.storagePath),
      });

      console.log(
        "[Captioning][DEBUG] raw ASR segments",
        JSON.stringify(asrSegments)
      );

      if (asrSegments.length === 0) {
        await refundCaption(uid, requestId, cost);
        return {segments: [], chargedParrots: 0};
      }

      const segments = await buildCaptionSegments(apiKey, asrSegments);
      console.log(
        "[Captioning][DEBUG] final segments",
        JSON.stringify(segments)
      );
      produced = true;
      return {segments, chargedParrots: cost};
    } catch (error) {
      if (!produced) {
        await refundCaption(uid, requestId, cost);
      }
      if (error instanceof HttpsError) {
        throw error;
      }

      console.error("[Captioning] generateCaptions failed", error);
      throw new HttpsError(
        "internal",
        "자동 자막을 만들지 못했어요. 잠시 뒤 다시 해 주세요."
      );
    } finally {
      await fs.unlink(tempPath).catch(() => undefined);
      if (useR2) {
        await r2Delete(input.storagePath).catch(() => undefined);
      } else {
        await legacyFile.delete({ignoreNotFound: true}).catch(() => undefined);
      }
    }
  }
);

function parseCaptionRequest(data: unknown): CaptionRequest {
  if (!data || typeof data !== "object") {
    throw new HttpsError(
      "invalid-argument",
      "이 영상으로는 자동 자막을 만들 수 없어요. 다른 영상으로 해 보세요."
    );
  }

  const source = data as Record<string, unknown>;
  const storagePath = readRequiredString(source.storagePath, "storagePath");
  const engine = readRequiredString(source.engine, "engine") as CaptionEngine;
  const durationMs = Number(source.durationMs);

  return {storagePath, engine, durationMs};
}

function validateCaptionRequest(uid: string, input: CaptionRequest): void {
  if (input.engine !== "whisper") {
    throw new HttpsError("invalid-argument", "지원하지 않는 자막 엔진입니다.");
  }

  if (
    !Number.isFinite(input.durationMs) ||
    input.durationMs <= 0 ||
    input.durationMs > MAX_CAPTION_DURATION_MS
  ) {
    throw new HttpsError(
      "invalid-argument",
      "5분 이하 영상만 넣을 수 있어요."
    );
  }

  const expectedPrefix = `caption-inputs/${uid}/`;
  if (
    !input.storagePath.startsWith(expectedPrefix) ||
    input.storagePath.includes("..") ||
    input.storagePath.endsWith("/")
  ) {
    throw new HttpsError("permission-denied", "허용되지 않은 파일 경로입니다.");
  }
}

function readRequiredString(value: unknown, fieldName: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${fieldName} 값이 필요합니다.`);
  }
  return value.trim();
}

async function transcribeWithOpenAi({
  apiKey,
  filePath,
  filename,
  contentType,
}: {
  apiKey: string;
  filePath: string;
  filename: string;
  contentType: string;
}): Promise<AsrSegment[]> {
  const form = new FormData();
  const fileBytes = await fs.readFile(filePath);

  form.append("model", "whisper-1");
  form.append("temperature", "0");
  form.append("response_format", "verbose_json");
  form.append("timestamp_granularities[]", "segment");
  form.append(
    "file",
    new Blob([new Uint8Array(fileBytes)], {type: contentType}),
    filename
  );

  const response = await fetch(OPENAI_ASR_ENDPOINT, {
    method: "POST",
    headers: {Authorization: `Bearer ${apiKey}`},
    body: form,
  });

  if (!response.ok) {
    await throwOpenAiHttpsError(response, "음성 인식");
  }

  const body = await response.json() as Record<string, unknown>;
  return parseAsrSegments(body);
}

function parseAsrSegments(body: Record<string, unknown>): AsrSegment[] {
  const source = Array.isArray(body.segments) ? body.segments : [];
  const segments: AsrSegment[] = [];

  for (const item of source) {
    if (!item || typeof item !== "object") continue;

    const segment = item as Record<string, unknown>;
    const startSec = Number(segment.start);
    const endSec = Number(segment.end);
    const text = typeof segment.text === "string" ? segment.text.trim() : "";

    if (
      !text ||
      !Number.isFinite(startSec) ||
      !Number.isFinite(endSec) ||
      endSec <= startSec
    ) {
      continue;
    }

    segments.push({
      startMs: Math.round(startSec * 1000),
      endMs: Math.round(endSec * 1000),
      text,
    });
  }

  return segments;
}

async function buildCaptionSegments(
  apiKey: string,
  asrSegments: AsrSegment[]
): Promise<CaptionSegment[]> {
  const result: CaptionSegment[] = [];

  for (
    let offset = 0;
    offset < asrSegments.length;
    offset += CAPTION_BATCH_SIZE
  ) {
    const batch = asrSegments.slice(offset, offset + CAPTION_BATCH_SIZE);
    const draft = await completeCaptionBatch(apiKey, batch);

    for (let index = 0; index < batch.length; index++) {
      const asrSegment = batch[index];
      const item = draft[index] || {};
      result.push({
        start: msToTimecode(asrSegment.startMs),
        end: msToTimecode(asrSegment.endMs),
        original: stringValue(item.orig) || asrSegment.text,
        pron: stringValue(item.pron),
        ko: stringValue(item.ko),
      });
    }
  }

  return normalizeSegments(result);
}

async function completeCaptionBatch(
  apiKey: string,
  batch: AsrSegment[]
): Promise<Array<Record<string, unknown>>> {
  const asrArray = batch.map((segment) => ({
    start_ms: segment.startMs,
    end_ms: segment.endMs,
    text: segment.text,
  }));

  const response = await fetch(OPENAI_CHAT_ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: OPENAI_CHAT_MODEL,
      response_format: {type: "json_object"},
      temperature: 0.2,
      messages: [
        {role: "system", content: await loadCaptionDraftSystemPrompt()},
        {
          role: "user",
          content:
            "아래 asr_segments와 동일 개수·동일 순서의 segments 배열을 " +
            "생성하세요. 출력은 {\"segments\":[...]} 하나의 JSON만 " +
            `허용됩니다.\n\nasr_segments = ${JSON.stringify(asrArray)}`,
        },
      ],
    }),
  });

  if (!response.ok) {
    await throwOpenAiHttpsError(response, "번역");
  }

  const body = await response.json() as Record<string, unknown>;
  const choices = Array.isArray(body.choices) ? body.choices : [];
  const first = choices[0] as Record<string, unknown> | undefined;
  const message = first?.message as Record<string, unknown> | undefined;
  const content = typeof message?.content === "string" ? message.content : "";

  console.log(
    "[Captioning][DEBUG] gpt-4o-mini raw content",
    content
  );

  try {
    const parsed = JSON.parse(content) as Record<string, unknown>;
    return Array.isArray(parsed.segments) ?
      parsed.segments.filter(isRecord) :
      [];
  } catch (error) {
    console.error("[Captioning] invalid caption JSON", error);
    return [];
  }
}

async function loadCaptionDraftSystemPrompt(): Promise<string> {
  captionDraftSystemPromptCache ??=
    (await fs.readFile(CAPTION_PROMPT_PATH, "utf8")).trim();
  return captionDraftSystemPromptCache;
}

async function throwOpenAiHttpsError(
  response: Response,
  actionName: string
): Promise<never> {
  let errorBody: OpenAiErrorBody = {};
  try {
    errorBody = await response.json() as OpenAiErrorBody;
  } catch (_) {
    errorBody = {};
  }

  const code = errorBody.error?.code;
  const message = errorBody.error?.message;
  const param = errorBody.error?.param;
  const type = errorBody.error?.type;

  if (code === "insufficient_quota" || type === "insufficient_quota") {
    throw new HttpsError(
      "resource-exhausted",
      "지금은 자동 자막을 만들 수 없어요. 잠시 뒤 다시 해 주세요. 계속 안 되면 문의해 주세요."
    );
  }

  if (response.status === 429 || code === "rate_limit_exceeded") {
    throw new HttpsError(
      "resource-exhausted",
      "지금은 자동 자막을 만들 수 없어요. 잠시 뒤 다시 해 주세요. 계속 안 되면 문의해 주세요."
    );
  }

  if (response.status === 401 || code === "invalid_api_key") {
    throw new HttpsError(
      "failed-precondition",
      "지금은 자동 자막을 만들 수 없어요. 잠시 뒤 다시 해 주세요. 계속 안 되면 문의해 주세요."
    );
  }

  console.error("[Captioning] OpenAI API error", {
    actionName,
    status: response.status,
    code,
    message,
    param,
    type,
  });
  throw new HttpsError(
    "internal",
    `${actionName} 중 OpenAI API 오류가 발생했습니다.`
  );
}

function normalizeSegments(segments: CaptionSegment[]): CaptionSegment[] {
  const sorted = [...segments].sort(
    (a, b) => parseTimecode(a.start) - parseTimecode(b.start)
  );
  let lastEnd = 0;

  return sorted
    .map((segment) => {
      let startMs = parseTimecode(segment.start);
      const endMs = parseTimecode(segment.end);

      if (startMs < lastEnd) startMs = lastEnd;
      if (endMs <= startMs) return null;

      lastEnd = endMs;
      return {
        ...segment,
        start: msToTimecode(startMs),
        end: msToTimecode(endMs),
      };
    })
    .filter((segment): segment is CaptionSegment => segment !== null);
}

function msToTimecode(ms: number): string {
  const minutes = Math.floor(ms / 60000);
  const seconds = Math.floor((ms % 60000) / 1000);
  const millis = ms % 1000;
  return `${minutes.toString().padStart(2, "0")}:` +
    `${seconds.toString().padStart(2, "0")}.` +
    `${millis.toString().padStart(3, "0")}`;
}

function parseTimecode(value: string): number {
  const match = /^(\d+):(\d{2})\.(\d{3})$/.exec(value);
  if (!match) return 0;
  return Number(match[1]) * 60000 + Number(match[2]) * 1000 + Number(match[3]);
}

function contentTypeFor(path: string): string {
  const extension = extname(path).toLowerCase();
  switch (extension) {
  case ".mp3":
    return "audio/mpeg";
  case ".wav":
    return "audio/wav";
  case ".m4a":
  case ".aac":
    return "audio/mp4";
  case ".flac":
    return "audio/flac";
  case ".ogg":
  case ".opus":
    return "audio/ogg";
  case ".mp4":
    return "video/mp4";
  case ".webm":
    return "video/webm";
  default:
    return "application/octet-stream";
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object";
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/**
 * 깎아 둔 자막 값을 돌려준다. 실패해도 응답은 계속 보낸다.
 * @param {string} uid 사용자
 * @param {string} requestId 요청 id
 * @param {number} cost 깎은 패롯
 */
async function refundCaption(
  uid: string,
  requestId: string,
  cost: number
): Promise<void> {
  if (cost <= 0) return;
  try {
    await applyLedger(uid, {parrots: cost}, {
      key: `caption_${requestId}_refund`,
      reason: "caption_refund",
    });
  } catch (refundError) {
    console.error("[Captioning] 환불 실패", refundError);
  }
}
