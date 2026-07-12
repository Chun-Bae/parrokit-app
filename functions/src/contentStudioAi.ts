import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import * as admin from "firebase-admin";
import {getStorage} from "firebase-admin/storage";
import {genkit} from "genkit";
import {vertexAI} from "@genkit-ai/google-genai";
import {enableFirebaseTelemetry} from "@genkit-ai/firebase";
import {ElevenLabsClient} from "@elevenlabs/elevenlabs-js";
import textToSpeech from "@google-cloud/text-to-speech";
import {GenerateVideosOperation, GoogleGenAI} from "@google/genai";
import {WaveFile} from "wavefile";
import * as Buffer from "buffer";

// 파이어베이스 시크릿 매니저에서 API 키를 안전하게 불러옵니다.
const elevenLabsApiKey = defineSecret("ELEVENLABS_API_KEY");
const geminiApiKey = defineSecret("GEMINI_API_KEY");
const VIDEO_COLLECTION = "content-studio-videos";
const VIDEO_STORAGE_TTL_MS = 24 * 60 * 60 * 1000;
const CHATBOT_DAILY_LIMIT = 30;
const CHATBOT_USAGE_COLLECTION = "chatbot-usage";
const OPERATOR_UIDS = new Set([
  "dDsWhAQWQxfCWI4xHIayCkjLD662",
  "naver:iDj5CROn8PODq_1sTN1Yjt2tvaaKiJUppIfKR5-IXmA",
]);

/**
 * 운영자 전용 UID인지 확인합니다.
 *
 * @param {string | null | undefined} uid 사용자 ID
 * @return {boolean} 운영자 여부
 */
function isOperatorUid(uid: string | null | undefined): boolean {
  return typeof uid === "string" && OPERATOR_UIDS.has(uid);
}

const VEO_MODEL_ALIASES: Record<string, string> = {
  "veo3.1-lite": "veo-3.1-lite-generate-preview",
  "veo3.1-fast": "veo-3.1-fast-generate-preview",
  "veo3.1-standard": "veo-3.1-generate-preview",
  "veo3.1-full": "veo-3.1-generate-preview",
  "veo-3.1-lite-generate-preview": "veo-3.1-lite-generate-preview",
  "veo-3.1-fast-generate-preview": "veo-3.1-fast-generate-preview",
  "veo-3.1-generate-preview": "veo-3.1-generate-preview",
};

/**
 * 사용자가 보낸 Veo 모델 ID를 실제 API 호출용 모델 ID로 정규화합니다.
 *
 * @param {string | undefined} modelId 사용자가 보낸 모델 ID
 * @return {string} 실제 호출에 사용할 Veo 모델 ID
 */
function normalizeVeoModelId(modelId?: string): string {
  if (!modelId) {
    return "veo-3.1-lite-generate-preview";
  }

  return VEO_MODEL_ALIASES[modelId] || "veo-3.1-lite-generate-preview";
}

/**
 * 서버/SDK 에러 객체에서 사람이 읽을 수 있는 메시지를 추출합니다.
 *
 * @param {unknown} error 에러 객체
 * @return {string} 추출된 에러 메시지
 */
function extractErrorMessage(error: unknown): string {
  if (error instanceof Error && error.message) {
    return error.message;
  }

  if (typeof error === "string") {
    return error;
  }

  if (typeof error === "object" && error !== null) {
    const typedError = error as {
      message?: unknown;
      error?: {message?: unknown};
      response?: {data?: {error?: {message?: unknown}}};
    };

    if (
      typeof typedError.message === "string" &&
      typedError.message.length > 0
    ) {
      return typedError.message;
    }

    if (
      typeof typedError.error?.message === "string" &&
      typedError.error.message.length > 0
    ) {
      return typedError.error.message;
    }

    if (
      typeof typedError.response?.data?.error?.message === "string" &&
      typedError.response.data.error.message.length > 0
    ) {
      return typedError.response.data.error.message;
    }
  }

  return "Unknown video generation error";
}

/**
 * Veo 비디오 생성 길이를 허용 범위인 4~8초로 제한합니다.
 * 1080p는 8초 영상만 지원하므로 해당 해상도에서는 8초로 고정합니다.
 *
 * @param {number | undefined} durationSeconds 요청된 길이
 * @param {string} resolution 정규화된 해상도 ("720p" | "1080p")
 * @return {number} 보정된 길이
 */
function clampDurationSeconds(
  durationSeconds: number | undefined,
  resolution: string
): number {
  if (resolution === "1080p") {
    return 8;
  }

  if (typeof durationSeconds !== "number" || Number.isNaN(durationSeconds)) {
    return 5;
  }

  if (durationSeconds < 4) {
    return 4;
  }

  if (durationSeconds > 8) {
    return 8;
  }

  return Math.round(durationSeconds);
}

/**
 * Veo 해상도 값을 지원 범위("720p" | "1080p")로 정규화합니다.
 * 4K 등 지원하지 않는 값은 기본값(720p)으로 대체합니다.
 *
 * @param {string | undefined} resolution 요청된 해상도
 * @return {string} 정규화된 해상도
 */
function normalizeResolution(resolution?: string): string {
  return resolution === "1080p" ? "1080p" : "720p";
}

/**
 * Google GenAI 비디오 응답에서 접근 가능한 첫 번째 영상 주소를 찾습니다.
 *
 * @param {unknown} value 응답 객체 또는 그 하위 값
 * @return {string | null} 사용 가능한 영상 주소
 */
function extractVideoUriFromValue(value: unknown): string | null {
  const seen = new Set<object>();
  const queue: unknown[] = [value];

  while (queue.length > 0) {
    const current = queue.shift();

    if (typeof current === "string") {
      if (
        current.startsWith("http://") ||
        current.startsWith("https://") ||
        current.startsWith("gs://") ||
        current.startsWith("data:")
      ) {
        return current;
      }
      continue;
    }

    if (
      typeof current !== "object" ||
      current === null ||
      seen.has(current as object)
    ) {
      continue;
    }

    seen.add(current as object);

    const typedCurrent = current as {
      uri?: unknown;
      videoBytes?: unknown;
      encodedVideo?: unknown;
      bytesBase64Encoded?: unknown;
      mimeType?: unknown;
      video?: unknown;
      videos?: unknown;
      generatedVideos?: unknown;
      generatedSamples?: unknown;
      generateVideoResponse?: unknown;
      response?: unknown;
      [key: string]: unknown;
    };

    if (typeof typedCurrent.uri === "string" && typedCurrent.uri.length > 0) {
      return typedCurrent.uri;
    }

    let base64Video: string | null = null;
    if (
      typeof typedCurrent.videoBytes === "string" &&
      typedCurrent.videoBytes.length > 0
    ) {
      base64Video = typedCurrent.videoBytes;
    } else if (
      typeof typedCurrent.encodedVideo === "string" &&
      typedCurrent.encodedVideo.length > 0
    ) {
      base64Video = typedCurrent.encodedVideo;
    } else if (
      typeof typedCurrent.bytesBase64Encoded === "string" &&
      typedCurrent.bytesBase64Encoded.length > 0
    ) {
      base64Video = typedCurrent.bytesBase64Encoded;
    }

    if (base64Video) {
      let mimeType = "video/mp4";
      if (
        typeof typedCurrent.mimeType === "string" &&
        typedCurrent.mimeType.length > 0
      ) {
        mimeType = typedCurrent.mimeType;
      }
      return `data:${mimeType};base64,${base64Video}`;
    }

    if (typedCurrent.video !== undefined) {
      queue.push(typedCurrent.video);
    }

    if (typedCurrent.videos !== undefined) {
      queue.push(typedCurrent.videos);
    }

    if (typedCurrent.generatedVideos !== undefined) {
      queue.push(typedCurrent.generatedVideos);
    }

    if (typedCurrent.generatedSamples !== undefined) {
      queue.push(typedCurrent.generatedSamples);
    }

    if (typedCurrent.generateVideoResponse !== undefined) {
      queue.push(typedCurrent.generateVideoResponse);
    }

    if (typedCurrent.response !== undefined) {
      queue.push(typedCurrent.response);
    }

    for (const key of Object.keys(typedCurrent)) {
      if (
        key !== "uri" &&
        key !== "videoBytes" &&
        key !== "encodedVideo" &&
        key !== "bytesBase64Encoded" &&
        key !== "mimeType" &&
        key !== "video" &&
        key !== "videos" &&
        key !== "generatedVideos" &&
        key !== "generatedSamples" &&
        key !== "generateVideoResponse" &&
        key !== "response"
      ) {
        queue.push(typedCurrent[key]);
      }
    }
  }

  return null;
}

/**
 * GCS 경로 또는 Storage URL을 플레이 가능한 HTTPS 주소로 변환합니다.
 *
 * @param {string} videoUri 원본 비디오 URI
 * @return {Promise<string>} 플레이 가능한 비디오 URL
 */
async function resolvePlayableVideoUrl(videoUri: string): Promise<string> {
  if (videoUri.startsWith("data:")) {
    return videoUri;
  }

  if (videoUri.startsWith("https://")) {
    return videoUri;
  }

  const gsMatch = videoUri.match(/^gs:\/\/([^/]+)\/(.+)$/);
  if (gsMatch) {
    const bucketName = gsMatch[1];
    const filePath = decodeURIComponent(gsMatch[2]);
    const [signedUrl] = await getStorage()
      .bucket(bucketName)
      .file(filePath)
      .getSignedUrl({
        action: "read",
        expires: Date.now() + 60 * 60 * 1000,
      });

    return signedUrl;
  }

  const storageMatch = videoUri.match(
    /^https:\/\/storage\.googleapis\.com\/([^/]+)\/(.+)$/
  );
  if (storageMatch) {
    const bucketName = storageMatch[1];
    const filePath = decodeURIComponent(storageMatch[2]);
    const [signedUrl] = await getStorage()
      .bucket(bucketName)
      .file(filePath)
      .getSignedUrl({
        action: "read",
        expires: Date.now() + 60 * 60 * 1000,
      });

    return signedUrl;
  }

  return videoUri;
}

/**
 * 비디오 생성 결과를 보관할 Storage 경로를 만듭니다.
 *
 * @param {string} uid 사용자 ID
 * @param {string} generationId 생성 ID
 * @return {string} Storage 경로
 */
function buildVideoStoragePath(uid: string, generationId: string): string {
  return `users/${uid}/content-studio/videos/${generationId}.mp4`;
}

/**
 * 비디오 생성 결과 메타데이터를 저장합니다.
 *
 * @param {object} params 저장할 데이터
 * @return {Promise<string>} 생성 ID
 */
async function createVideoGenerationRecord(params: {
  uid: string;
  operationName: string;
  prompt: string;
  modelId: string;
  aspectRatio: string;
  durationSeconds: number;
}): Promise<string> {
  const generationId = admin.firestore().collection(VIDEO_COLLECTION).doc().id;
  const now = admin.firestore.Timestamp.now();
  const operatorAccount = isOperatorUid(params.uid);
  const expiresAt = operatorAccount ?
    null :
    admin.firestore.Timestamp.fromMillis(Date.now() + VIDEO_STORAGE_TTL_MS);

  await admin.firestore().collection(VIDEO_COLLECTION).doc(generationId).set({
    uid: params.uid,
    generationId,
    operationName: params.operationName,
    prompt: params.prompt,
    modelId: params.modelId,
    aspectRatio: params.aspectRatio,
    durationSeconds: params.durationSeconds,
    storagePath: null,
    downloadUrl: null,
    mimeType: null,
    createdAt: now,
    updatedAt: now,
    expiresAt,
    ttlHours: operatorAccount ? null : 24,
    status: "processing",
  });

  return generationId;
}

/**
 * 비디오 생성 문서를 uid와 operationName으로 찾습니다.
 *
 * @param {string} uid 사용자 ID
 * @param {string} operationName Gemini operation 이름
 * @return {Promise<admin.firestore.DocumentSnapshot | null>} 문서
 */
async function findVideoGenerationDocument(
  uid: string,
  operationName: string
): Promise<admin.firestore.DocumentSnapshot | null> {
  const snapshot = await admin
    .firestore()
    .collection(VIDEO_COLLECTION)
    .where("uid", "==", uid)
    .where("operationName", "==", operationName)
    .limit(1)
    .get();

  if (snapshot.empty) {
    return null;
  }

  return snapshot.docs[0];
}

/**
 * 외부 응답의 비디오를 Storage에 저장하고 signed URL을 반환합니다.
 *
 * @param {object} params 다운로드/저장 정보
 * @return {Promise<object>} 저장 결과
 */
async function downloadAndStoreVideo(params: {
  uid: string;
  generationId: string;
  videoUri: string;
}): Promise<{
  storagePath: string;
  downloadUrl: string;
  mimeType: string;
}> {
  const operatorAccount = isOperatorUid(params.uid);
  let bytes: Buffer.Buffer;
  let mimeType = "video/mp4";

  if (params.videoUri.startsWith("gs://")) {
    const match = params.videoUri.match(/^gs:\/\/([^/]+)\/(.+)$/);
    if (!match) {
      throw new Error("Invalid gs:// video URI.");
    }

    const bucketName = match[1];
    const filePath = decodeURIComponent(match[2]);
    const [fileBytes] = await getStorage()
      .bucket(bucketName)
      .file(filePath)
      .download();
    bytes = Buffer.Buffer.from(fileBytes);
  } else if (params.videoUri.startsWith("https://storage.googleapis.com/")) {
    const match = params.videoUri.match(
      /^https:\/\/storage\.googleapis\.com\/([^/]+)\/(.+)$/
    );
    if (!match) {
      throw new Error("Invalid storage.googleapis.com video URI.");
    }

    const bucketName = match[1];
    const filePath = decodeURIComponent(match[2]);
    const [fileBytes] = await getStorage()
      .bucket(bucketName)
      .file(filePath)
      .download();
    bytes = Buffer.Buffer.from(fileBytes);
  } else {
    const apiKey = geminiApiKey.value();
    const requestUrl = params.videoUri.includes("?") ?
      `${params.videoUri}&key=${apiKey}` :
      `${params.videoUri}?key=${apiKey}`;
    const response = await fetch(requestUrl);

    if (!response.ok) {
      throw new Error(
        `Failed to download generated video: ${response.status}` +
          ` ${response.statusText}`
      );
    }

    mimeType = response.headers.get("content-type") || "video/mp4";
    bytes = Buffer.Buffer.from(await response.arrayBuffer());
  }

  const storagePath = buildVideoStoragePath(params.uid, params.generationId);
  const file = getStorage().bucket().file(storagePath);

  await file.save(bytes, {
    contentType: mimeType,
    resumable: false,
    metadata: {
      metadata: {
        uid: params.uid,
        generationId: params.generationId,
        expiresAt: operatorAccount ?
          null :
          new Date(Date.now() + VIDEO_STORAGE_TTL_MS).toISOString(),
      },
    },
  });

  const [downloadUrl] = await file.getSignedUrl({
    action: "read",
    expires: Date.now() + 60 * 60 * 1000,
  });

  return {
    storagePath,
    downloadUrl,
    mimeType,
  };
}

/**
 * 영상 목록 문서에서 사용자가 접근 가능한 URL을 다시 생성합니다.
 *
 * @param {string} storagePath Storage 경로
 * @return {Promise<string>} signed URL
 */
async function signVideoStoragePath(storagePath: string): Promise<string> {
  const [downloadUrl] = await getStorage()
    .bucket()
    .file(storagePath)
    .getSignedUrl({
      action: "read",
      expires: Date.now() + 60 * 60 * 1000,
    });

  return downloadUrl;
}

/**
 * Firestore Timestamp가 만료되었는지 확인합니다.
 *
 * @param {unknown} value Timestamp 값
 * @return {boolean} 만료 여부
 */
function isExpiredTimestamp(value: unknown): boolean {
  if (!value || typeof value !== "object") {
    return false;
  }

  const timestamp = value as {toMillis?: () => number};
  if (typeof timestamp.toMillis !== "function") {
    return false;
  }

  return timestamp.toMillis() <= Date.now();
}

/**
 * Firestore 저장 문서 데이터를 응답용으로 변환합니다.
 *
 * @param {FirebaseFirestore.DocumentData} data 문서 데이터
 * @return {Record<string, unknown>} 응답 payload
 */
async function serializeVideoGenerationDocument(
  data: admin.firestore.DocumentData
): Promise<Record<string, unknown>> {
  const storagePath =
    typeof data.storagePath === "string" ? data.storagePath : null;
  const downloadUrl =
    typeof data.downloadUrl === "string" ? data.downloadUrl : null;
  let refreshedDownloadUrl = downloadUrl;

  if (storagePath) {
    refreshedDownloadUrl = await signVideoStoragePath(storagePath);
  }

  return {
    uid: typeof data.uid === "string" ? data.uid : null,
    generationId:
      typeof data.generationId === "string" ? data.generationId : null,
    operationName:
      typeof data.operationName === "string" ? data.operationName : null,
    prompt: typeof data.prompt === "string" ? data.prompt : null,
    modelId: typeof data.modelId === "string" ? data.modelId : null,
    aspectRatio:
      typeof data.aspectRatio === "string" ? data.aspectRatio : null,
    durationSeconds:
      typeof data.durationSeconds === "number" ? data.durationSeconds : null,
    storagePath,
    videoUrl: refreshedDownloadUrl,
    mimeType: typeof data.mimeType === "string" ? data.mimeType : null,
    status: typeof data.status === "string" ? data.status : null,
    createdAt: data.createdAt?.toDate?.()?.toISOString?.() ?? null,
    updatedAt: data.updatedAt?.toDate?.()?.toISOString?.() ?? null,
    expiresAt: data.expiresAt?.toDate?.()?.toISOString?.() ?? null,
    ttlHours: typeof data.ttlHours === "number" ? data.ttlHours : null,
  };
}

// 1. 파이어베이스 콘솔(Genkit 탭)로 로그 전송 활성화 (콜드스타트 타임아웃 방지)
enableFirebaseTelemetry({
  metricExportTimeoutMillis: 180000,
  metricExportIntervalMillis: 180000,
});

// 2. 통합 AI 플러그인 초기화 (Vertex AI 백엔드 사용)
const ai = genkit({
  plugins: [vertexAI({location: "us-central1"})],
});

import {z} from "zod";

export const ChatbotOutputSchema = z.object({
  reply: z.string(),
  actionType: z.enum([
    "none",
    "ask_routing",
    "change_mode",
    "tts_trigger",
    "video_trigger",
    "script_recommendation",
    "video_prompt_recommendation",
  ]),
  actionData: z
    .object({
      text: z.string().nullable().optional(),
      language: z.string().nullable().optional(),
      provider: z.string().nullable().optional(),
      voiceId: z.string().nullable().optional(),
      prompt: z.string().nullable().optional(),
      ratio: z.string().nullable().optional(),
      duration: z.number().nullable().optional(),
      routingOptions: z.array(z.string()).nullable().optional(),
      targetMode: z.string().nullable().optional(),
      scripts: z.array(z.string()).nullable().optional(),
      prompts: z.array(z.string()).nullable().optional(),
    })
    .nullable()
    .optional(),
});

/**
 * Recursively removes nullish values from arrays and objects so flow output
 * matches the callable schema expected by the Flutter client.
 *
 * @param {T} value The value to clean.
 * @return {T} The cleaned value without nullish fields.
 */
function pruneNullishValues<T>(value: T): T {
  if (Array.isArray(value)) {
    return value
      .filter((item) => item !== null && item !== undefined)
      .map((item) => pruneNullishValues(item)) as T;
  }

  if (value && typeof value === "object") {
    const entries = Object.entries(value as Record<string, unknown>)
      .filter(([, item]) => item !== null && item !== undefined)
      .map(([key, item]) => [key, pruneNullishValues(item)] as const);
    return Object.fromEntries(entries) as T;
  }

  return value;
}

/**
 * 챗봇 일일 사용량 확인/증가 결과.
 */
interface ChatbotUsageResult {
  usedToday: number;
  remainingToday: number;
}

/**
 * 챗봇 일일 사용량을 증가 없이 조회합니다. 운영자 계정은 항상 한도 전체가
 * 남은 것으로 반환됩니다.
 *
 * @param {string} uid 사용자 ID
 * @return {Promise<ChatbotUsageResult>} 오늘 사용/잔여 횟수
 */
async function getChatbotUsageStatus(uid: string): Promise<ChatbotUsageResult> {
  if (isOperatorUid(uid)) {
    return {usedToday: 0, remainingToday: CHATBOT_DAILY_LIMIT};
  }

  const today = new Date().toISOString().slice(0, 10);
  const snapshot = await admin
    .firestore()
    .collection(CHATBOT_USAGE_COLLECTION)
    .doc(`${uid}_${today}`)
    .get();

  const usedToday = snapshot.exists ?
    (snapshot.data()?.count as number | undefined) || 0 :
    0;

  return {
    usedToday,
    remainingToday: Math.max(CHATBOT_DAILY_LIMIT - usedToday, 0),
  };
}

/**
 * 챗봇 일일 사용량을 확인하고 1 증가시킵니다. 한도를 초과하면 예외를 던집니다.
 * 운영자 계정은 한도에서 제외됩니다.
 *
 * @param {string} uid 사용자 ID
 * @return {Promise<ChatbotUsageResult>} 오늘 사용/잔여 횟수
 */
async function checkAndIncrementChatbotUsage(
  uid: string
): Promise<ChatbotUsageResult> {
  if (isOperatorUid(uid)) {
    return {usedToday: 0, remainingToday: CHATBOT_DAILY_LIMIT};
  }

  const today = new Date().toISOString().slice(0, 10);
  const ref = admin
    .firestore()
    .collection(CHATBOT_USAGE_COLLECTION)
    .doc(`${uid}_${today}`);

  return await admin.firestore().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const currentCount = snapshot.exists ?
      (snapshot.data()?.count as number | undefined) || 0 :
      0;

    if (currentCount >= CHATBOT_DAILY_LIMIT) {
      throw new HttpsError(
        "resource-exhausted",
        "오늘의 채팅 횟수를 모두 사용했어요. 내일 다시 시도해 주세요."
      );
    }

    const newCount = currentCount + 1;
    transaction.set(
      ref,
      {
        uid,
        date: today,
        count: newCount,
        updatedAt: admin.firestore.Timestamp.now(),
      },
      {merge: true}
    );

    return {
      usedToday: newCount,
      remainingToday: CHATBOT_DAILY_LIMIT - newCount,
    };
  });
}

// 3. 각각의 Dotprompt 파일을 불러와서 Flow 정의
export const chatbotFlow = ai.defineFlow(
  {
    name: "chatbotFlow",
    inputSchema: z.object({
      history: z.array(
        z.object({role: z.enum(["user", "model"]), text: z.string()})
      ),
      message: z.string(),
      model: z.string().optional(),
      chatbotMode: z.enum(["general", "tts", "video"]).optional(),
    }),
    outputSchema: ChatbotOutputSchema,
  },
  async (input) => {
    // 비용 폭탄 방지: 프론트엔드가 100개를 보내더라도, 무조건 최근 몇 개만 사용
    const MAX_HISTORY = 6;
    const recentHistory = (input.history || []).slice(-MAX_HISTORY);

    // Pro는 유료 플랜 전용으로 잠가둔 상태라, 결제 시스템이 붙기 전까지는
    // 클라이언트가 어떤 모델을 요청하든 무조건 Flash만 사용한다.
    const targetModel = "vertexai/gemini-2.5-flash";
    console.log(
      `[Chatbot][Flow] Mode parameter inputMode=${input.model} ` +
        `targetModel=${targetModel} chatbotMode=${input.chatbotMode}`
    );

    // chatbotMode에 따라 프롬프트 파일 분기
    let promptName = "chatbots/general-agent";
    if (input.chatbotMode === "tts") {
      promptName = "chatbots/tts-specialist-agent";
    } else if (input.chatbotMode === "video") {
      promptName = "chatbots/video-specialist-agent";
    }

    const p = await ai.prompt(promptName);
    const response = await p(
      {
        message: input.message,
        history: recentHistory,
      },
      {
        // 프론트엔드에서 모델 이름을 보냈다면 해당 모델로 덮어쓰기 (없으면 .prompt의 기본값 사용)
        model: targetModel,
      }
    );

    // 만약 response.output이 존재하지 않는 경우를 대비한 대체값 제공
    return pruneNullishValues(response.output || {
      reply: response.text || "",
      actionType: "none",
      actionData: null,
    });
  }
);

export interface ElevenLabsSettings {
  stability?: number;
  similarity_boost?: number;
  style?: number;
  use_speaker_boost?: boolean;
}

export const generateTtsFlow = ai.defineFlow(
  "generateTtsFlow",
  async (input: {
    text: string;
    language: string;
    provider?: "google" | "elevenlabs" | "gemini";
    voiceId?: string;
    modelId?: string;
    speakingRate?: number;
    pitch?: number;
    elevenLabsSettings?: ElevenLabsSettings;
  }) => {
    if (!input.text) {
      throw new Error("Text is required for TTS generation.");
    }
    if (!input.language) {
      throw new Error("Language is required for TTS generation.");
    }

    const provider = input.provider || "google";

    if (provider === "elevenlabs") {
      try {
        const client = new ElevenLabsClient({
          apiKey: elevenLabsApiKey.value(),
        });

        const targetVoice = input.voiceId || "21m00Tcm4TlvDq8ikWAM";
        const targetModel = input.modelId || "eleven_multilingual_v2";

        const audioStream = await client.textToSpeech.convert(targetVoice, {
          text: input.text,
          modelId: targetModel,
          outputFormat: "pcm_24000",
          voiceSettings: input.elevenLabsSettings ? {
            stability: input.elevenLabsSettings.stability,
            similarityBoost: input.elevenLabsSettings.similarity_boost,
            style: input.elevenLabsSettings.style,
            useSpeakerBoost: input.elevenLabsSettings.use_speaker_boost,
          } : undefined,
        });

        const chunks: Uint8Array[] = [];
        for await (const chunk of audioStream) {
          chunks.push(chunk);
        }
        const pcmBuffer = Buffer.Buffer.concat(chunks);

        const wav = new WaveFile();
        const int16Array = new Int16Array(pcmBuffer.length / 2);
        for (let i = 0; i < int16Array.length; i++) {
          int16Array[i] = pcmBuffer.readInt16LE(i * 2);
        }

        wav.fromScratch(1, 24000, "16", int16Array);
        const wavBuffer = wav.toBuffer();

        return {
          audioBase64: Buffer.Buffer.from(wavBuffer).toString("base64"),
        };
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
      } catch (error: any) {
        console.error("ElevenLabs TTS Error:", error);
        throw new Error(error.message || "Failed to generate ElevenLabs TTS");
      }
    } else if (provider === "gemini") {
      try {
        const client = new GoogleGenAI({
          apiKey: geminiApiKey.value(),
        });

        const targetModel = input.modelId || "gemini-2.5-flash-preview-tts";
        const targetVoice = input.voiceId || "Aoede";

        // 텍스트가 짧거나 인사말처럼 보이면 모델이 답변을 생성하려 시도하는
        // 경우가 있어, 그대로 읽으라는 지시문을 붙여서 보낸다.
        const ttsPrompt =
          "Read the following text aloud exactly as written. " +
          "Do not answer, respond to, or add anything else — " +
          "only speak it verbatim.\n\n" +
          `Text: ${input.text}`;

        const response = await client.models.generateContent({
          model: targetModel,
          contents: ttsPrompt,
          config: {
            responseModalities: ["AUDIO"],
            speechConfig: {
              voiceConfig: {
                prebuiltVoiceConfig: {
                  voiceName: targetVoice,
                },
              },
            },
          },
        });

        const part = response.candidates?.[0]?.content?.parts?.[0];
        if (!part || !part.inlineData || !part.inlineData.data) {
          throw new Error("No audio data returned from Gemini TTS.");
        }

        // Gemini returns raw PCM data (audio/L16;codec=pcm;rate=24000).
        // We need a WAV header so the Flutter audio player can play it.
        const pcmBuffer = Buffer.Buffer.from(part.inlineData.data, "base64");

        const wav = new WaveFile();

        // Convert the raw byte buffer to an array of 16-bit LE samples
        const int16Array = new Int16Array(pcmBuffer.length / 2);
        for (let i = 0; i < int16Array.length; i++) {
          int16Array[i] = pcmBuffer.readInt16LE(i * 2);
        }

        wav.fromScratch(1, 24000, "16", int16Array);
        const wavBuffer = wav.toBuffer();

        return {
          audioBase64: Buffer.Buffer.from(wavBuffer).toString("base64"),
        };
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      } catch (error: any) {
        console.error("Gemini TTS Error:", error);
        throw new Error(error.message || "Failed to generate Gemini TTS");
      }
    } else {
      // Default to Google TTS
      try {
        const client = new textToSpeech.TextToSpeechClient();

        // language is guaranteed to exist
        const languageCode = input.language;

        // If voiceId is not provided, pick a default based on language.
        // Standard voices are used (not Journey/Neural2) because those
        // families reject the pitch parameter entirely.
        let defaultVoice = "en-US-Standard-A"; // Default English
        if (languageCode.startsWith("ko")) {
          defaultVoice = "ko-KR-Standard-A";
        } else if (languageCode.startsWith("ja")) {
          defaultVoice = "ja-JP-Standard-A";
        }

        const name = input.voiceId || defaultVoice;

        const audioConfig: {
          audioEncoding: "MP3";
          speakingRate?: number;
          pitch?: number;
        } = {
          audioEncoding: "MP3",
        };
        // 일부 보이스(Journey, Chirp3-HD, Studio 등)는 pitch/speakingRate
        // 파라미터 자체를 거부하므로, 기본값(변화 없음)일 때는 아예 보내지 않는다.
        if (input.speakingRate && input.speakingRate !== 1.0) {
          audioConfig.speakingRate = input.speakingRate;
        }
        if (input.pitch && input.pitch !== 0.0) {
          audioConfig.pitch = input.pitch;
        }

        const request = {
          input: {text: input.text},
          voice: {languageCode, name},
          audioConfig,
        };

        // 사용자 확인용 로그 추가: 구글로 어떤 모델이 넘어가는지 파이어베이스 콘솔에 출력합니다.
        console.log(
          `[Google TTS Request] Language: ${languageCode}, Voice: ${name}, ` +
          `Speed: ${input.speakingRate}, Pitch: ${input.pitch}`
        );

        const [response] = await client.synthesizeSpeech(request);

        if (!response.audioContent) {
          throw new Error("No audio content returned from Google Cloud TTS.");
        }

        const buffer = Buffer.Buffer.from(response.audioContent);

        return {
          audioBase64: buffer.toString("base64"),
        };
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
      } catch (error: any) {
        console.error("Google Cloud TTS Error:", error);
        throw new Error(error.message || "Failed to generate Google TTS");
      }
    }
  }
);


// 4. 앱(Flutter)에서 호출할 수 있도록 Firebase Functions로 내보내기
export const generateChatbotResponse = onCall(
  {
    timeoutSeconds: 180,
  },
  async (request) => {
    try {
      const uid = request.auth?.uid;
      if (!uid) {
        throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
      }

      const usage = await checkAndIncrementChatbotUsage(uid);
      const result = await chatbotFlow(request.data);

      return {
        ...result,
        dailyLimit: CHATBOT_DAILY_LIMIT,
        usedToday: usage.usedToday,
        remainingToday: usage.remainingToday,
      };
    } catch (error: any) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error("Chatbot Wrapper Error:", error);
      throw new HttpsError(
        "aborted",
        error.message || "Failed to generate response"
      );
    }
  }
);

// 챗봇을 실제로 호출하지 않고, 오늘 사용량만 조회하기 위한 엔드포인트.
// 시트를 열 때 이걸 먼저 호출해서 "오늘 X/30"을 정확히 표시한다.
export const getChatbotUsage = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }

  const usage = await getChatbotUsageStatus(uid);

  return {
    dailyLimit: CHATBOT_DAILY_LIMIT,
    usedToday: usage.usedToday,
    remainingToday: usage.remainingToday,
  };
});

export const generateTts = onCall(
  {secrets: [elevenLabsApiKey, geminiApiKey]},
  async (request) => {
    try {
      return await generateTtsFlow(request.data);
    } catch (error: any) {
      console.error("TTS Wrapper Error:", error);
      throw new HttpsError(
        "aborted",
        error.message || "Failed to generate TTS"
      );
    }
  }
);

// 5. 구글 Cloud TTS 보이스 목록 불러오기 (프론트엔드 동적 렌더링용)
export const listTtsVoices = onCall(async (request) => {
  try {
    const client = new textToSpeech.TextToSpeechClient();
    const languageCode = request.data?.languageCode; // 선택적 파라미터

    const [result] = await client.listVoices({languageCode});
    return {voices: result.voices};
  } catch (error: any) {
    console.error("Google Cloud TTS listVoices Error:", error);
    throw new Error(error.message || "Failed to list Google TTS voices");
  }
});

export const listElevenLabsVoices = onCall(
  {secrets: [elevenLabsApiKey]},
  async () => {
    try {
      const client = new ElevenLabsClient({apiKey: elevenLabsApiKey.value()});
      const response = await client.voices.getAll();
      return {voices: response.voices};
    } catch (error: any) {
      console.error("ElevenLabs listVoices Error:", error);
      throw new HttpsError(
        "internal",
        error.message || "Failed to list ElevenLabs voices"
      );
    }
  }
);

// 6. 비디오 생성 (Veo 3.1)
export const generateVideo = onCall(
  {secrets: [geminiApiKey]},
  async (request) => {
    let generationId: string | null = null;

    try {
      const uid = request.auth?.uid;
      if (!uid) {
        throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
      }

      const {prompt, aspectRatio, duration, modelId, resolution, debug} =
        request.data;

      if (!prompt || typeof prompt !== "string" || prompt.trim().length === 0) {
        throw new HttpsError("invalid-argument", "prompt is required");
      }

      // 디버그 모드인 경우: 실제 과금 발생 없이 더미 Operation 반환
      if (debug === true || modelId === "debug") {
        console.log("[Video] Debug mode activated. Returning dummy operation.");
        return {operationName: "operations/dummy-debug-video-operation"};
      }

      // Vertex AI가 아닌 일반 제미나이 API 클라이언트
      const client = new GoogleGenAI({
        apiKey: geminiApiKey.value(),
      });

      const targetModel = normalizeVeoModelId(modelId);
      const targetResolution = normalizeResolution(resolution);
      const targetDurationSeconds = clampDurationSeconds(
        duration,
        targetResolution
      );
      generationId = await createVideoGenerationRecord({
        uid,
        operationName: "pending",
        prompt,
        modelId: targetModel,
        aspectRatio: aspectRatio || "16:9",
        durationSeconds: targetDurationSeconds,
      });
      console.log(
        "[Video] Requesting video generation. " +
        `modelId=${modelId || "default"} targetModel=${targetModel} ` +
        `aspectRatio=${aspectRatio || "16:9"} ` +
        `duration=${targetDurationSeconds} resolution=${targetResolution}`
      );
      console.log(`[Video] Prompt: ${prompt}`);

      const operation = await client.models.generateVideos({
        model: targetModel,
        source: {
          prompt,
        },
        config: {
          aspectRatio: aspectRatio || "16:9",
          durationSeconds: targetDurationSeconds,
          resolution: targetResolution,
        },
      });

      await admin
        .firestore()
        .collection(VIDEO_COLLECTION)
        .doc(generationId)
        .update({
          operationName: operation.name,
          updatedAt: admin.firestore.Timestamp.now(),
        });

      return {operationName: operation.name};
    } catch (error: any) {
      if (typeof generationId === "string" && generationId.length > 0) {
        await admin
          .firestore()
          .collection(VIDEO_COLLECTION)
          .doc(generationId)
          .set(
            {
              status: "failed",
              updatedAt: admin.firestore.Timestamp.now(),
            },
            {merge: true}
          )
          .catch(() => undefined);
      }
      const message = extractErrorMessage(error);
      console.error("Video Generation Error:", error);
      throw new HttpsError(
        "failed-precondition",
        message
      );
    }
  }
);

// 7. 비디오 생성 상태 확인 (폴링용)
export const getVideoOperationStatus = onCall(
  {secrets: [geminiApiKey]},
  async (request) => {
    try {
      const uid = request.auth?.uid;
      if (!uid) {
        throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
      }

      const {operationName} = request.data;

      if (!operationName) {
        throw new HttpsError("invalid-argument", "operationName is required");
      }

      // 디버그 모드 더미 오퍼레이션 처리
      if (operationName === "operations/dummy-debug-video-operation") {
        console.log("[Video] Polling dummy operation. Returning success.");
        return {
          done: true,
          videoUri: "https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4",
          ttlHours: null,
        };
      }

      const docSnapshot = await findVideoGenerationDocument(uid, operationName);
      let done = false;
      let videoUri = null;
      let error = null;
      let generationData: admin.firestore.DocumentData | null = null;

      if (docSnapshot) {
        generationData = docSnapshot.data() || null;
        if (generationData) {
          const currentGenerationData = generationData;
          const operatorAccount = isOperatorUid(currentGenerationData.uid);
          if (
            !operatorAccount &&
            currentGenerationData.expiresAt &&
            isExpiredTimestamp(currentGenerationData.expiresAt)
          ) {
            const expiredStoragePath =
              typeof currentGenerationData.storagePath === "string" ?
                currentGenerationData.storagePath :
                null;
            if (expiredStoragePath) {
              await getStorage().bucket().file(expiredStoragePath).delete({
                ignoreNotFound: true,
              });
            }
            await docSnapshot.ref.delete();
            return {
              done: true,
              videoUri: null,
              error: "영상 보관 기간이 만료되었습니다.",
              ttlHours: null,
            };
          }
        }
      }

      const client = new GoogleGenAI({
        apiKey: geminiApiKey.value(),
      });

      const operation = new GenerateVideosOperation();
      operation.name = operationName;

      const updatedOperation = await client.operations.getVideosOperation({
        operation,
      });

      done = updatedOperation.done === true;

      if (done) {
        if (updatedOperation.error) {
          error = extractErrorMessage(updatedOperation.error);
        } else {
          videoUri = extractVideoUriFromValue(updatedOperation.response);
          if (!videoUri) {
            const apiKey = geminiApiKey.value();
            const response = await fetch(
              `https://generativelanguage.googleapis.com/v1beta/${operationName}` +
              `?key=${apiKey}`
            );

            if (!response.ok) {
              throw new Error(
                `Failed to fetch operation: ${response.statusText}`
              );
            }

            const rawOperation = await response.json();
            if (rawOperation.error) {
              error = extractErrorMessage(rawOperation.error);
            } else {
              videoUri = extractVideoUriFromValue(rawOperation);
            }
          }

          if (videoUri && generationData) {
            if (!generationData.storagePath) {
              const generationId =
                String(generationData.generationId || docSnapshot?.id || "");
              const stored = await downloadAndStoreVideo({
                uid,
                generationId,
                videoUri,
              });

              await docSnapshot?.ref.update({
                storagePath: stored.storagePath,
                downloadUrl: stored.downloadUrl,
                mimeType: stored.mimeType,
                status: "completed",
                updatedAt: admin.firestore.Timestamp.now(),
              });

              videoUri = stored.downloadUrl;
            } else {
              videoUri = await signVideoStoragePath(generationData.storagePath);
            }
          } else if (videoUri) {
            videoUri = await resolvePlayableVideoUrl(videoUri);
          } else {
            console.log(
              "[Video][Status] Done but no video URI found.",
              JSON.stringify({
                keys: Object.keys(updatedOperation.response || {}),
                response: updatedOperation.response || null,
              })
            );
          }
        }
      }

      return {
        done,
        videoUri,
        error,
        ttlHours: null,
      };
    } catch (error: any) {
      console.error("Video Operation Status Error:", error);
      throw new HttpsError(
        "internal",
        error.message || "Failed to get video status"
      );
    }
  }
);

export const listVideoGenerations = onCall(
  {secrets: [geminiApiKey]},
  async (request) => {
    try {
      const uid = request.auth?.uid;
      if (!uid) {
        throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
      }

      const snapshot = await admin
        .firestore()
        .collection(VIDEO_COLLECTION)
        .where("uid", "==", uid)
        .get();
      const operatorAccount = isOperatorUid(uid);

      const items = await Promise.all(
        snapshot.docs.map(async (doc) => {
          const data = doc.data();
          const expired =
            !operatorAccount &&
            data.expiresAt &&
            isExpiredTimestamp(data.expiresAt);
          if (expired) {
            const storagePath =
              typeof data.storagePath === "string" ? data.storagePath : null;
            if (storagePath) {
              await getStorage().bucket().file(storagePath).delete({
                ignoreNotFound: true,
              });
            }
            await doc.ref.delete();
            return null;
          }

          return {
            createdAtMillis: data.createdAt?.toMillis?.() ?? 0,
            payload: await serializeVideoGenerationDocument({
              ...data,
              generationId: data.generationId || doc.id,
            }),
          };
        })
      );

      const filteredItems = items.filter(
        (
          item
        ): item is {
          createdAtMillis: number;
          payload: Record<string, unknown>;
        } => item !== null
      );

      filteredItems.sort((a, b) => b.createdAtMillis - a.createdAtMillis);

      return {
        items: filteredItems.slice(0, 20).map((item) => item.payload),
        ttlHours: operatorAccount ? null : 24,
      };
    } catch (error: any) {
      console.error("Video Generation List Error:", error);
      throw new HttpsError(
        "internal",
        error.message || "Failed to list video generations"
      );
    }
  }
);
