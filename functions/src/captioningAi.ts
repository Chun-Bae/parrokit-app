/* eslint-disable require-jsdoc */

import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {getStorage} from "firebase-admin/storage";
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
    secrets: [openaiApiKey],
    timeoutSeconds: 540,
    memory: "1GiB",
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const input = parseCaptionRequest(request.data);
    validateCaptionRequest(uid, input);

    const bucket = getStorage().bucket();
    const file = bucket.file(input.storagePath);
    const tempPath = join(
      tmpdir(),
      `caption_${uid}_${Date.now()}${extname(input.storagePath) || ".bin"}`
    );

    try {
      const [metadata] = await file.getMetadata();
      const fileSize = Number(metadata.size ?? 0);
      if (!Number.isFinite(fileSize) || fileSize <= 0) {
        throw new HttpsError("invalid-argument", "파일 크기를 확인할 수 없습니다.");
      }
      if (fileSize > MAX_CAPTION_FILE_BYTES) {
        throw new HttpsError(
          "invalid-argument",
          "자동 자막 파일은 30MB 이하만 처리할 수 있습니다."
        );
      }

      await file.download({destination: tempPath});

      const apiKey = openaiApiKey.value();
      const asrSegments = await transcribeWithOpenAi({
        apiKey,
        filePath: tempPath,
        filename: basename(input.storagePath),
        contentType: metadata.contentType || contentTypeFor(input.storagePath),
      });

      console.log(
        "[Captioning][DEBUG] raw ASR segments",
        JSON.stringify(asrSegments)
      );

      if (asrSegments.length === 0) {
        return {segments: []};
      }

      const segments = await buildCaptionSegments(apiKey, asrSegments);
      console.log(
        "[Captioning][DEBUG] final segments",
        JSON.stringify(segments)
      );
      return {segments};
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      console.error("[Captioning] generateCaptions failed", error);
      throw new HttpsError(
        "internal",
        "자동 자막 생성 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요."
      );
    } finally {
      await fs.unlink(tempPath).catch(() => undefined);
      await file.delete({ignoreNotFound: true}).catch(() => undefined);
    }
  }
);

function parseCaptionRequest(data: unknown): CaptionRequest {
  if (!data || typeof data !== "object") {
    throw new HttpsError("invalid-argument", "요청 데이터가 올바르지 않습니다.");
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
      "자동 자막은 5분 이하 파일만 처리할 수 있습니다."
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
      "OpenAI API 할당량이 부족합니다. 결제 상태를 확인해 주세요."
    );
  }

  if (response.status === 429 || code === "rate_limit_exceeded") {
    throw new HttpsError(
      "resource-exhausted",
      "OpenAI 요청 한도를 초과했습니다. 잠시 후 다시 시도해 주세요."
    );
  }

  if (response.status === 401 || code === "invalid_api_key") {
    throw new HttpsError(
      "failed-precondition",
      "OpenAI API 키 설정을 확인해 주세요."
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
