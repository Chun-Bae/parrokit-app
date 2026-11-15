/* eslint-disable require-jsdoc, valid-jsdoc */
// 질문 글을 만들 때 앱이 보낸 값을 검사하고, 서버가 적을 문서를 만든다.
//
// 전에는 이 검사가 createQuestion 콜 안에 그대로 들어 있어, 규칙이 맞는지
// 보려면 함수를 실제로 불러 봐야 했다. 보상 크래커가 걸린 자리라 눈으로만
// 믿기 어렵다. 순수 함수로 떼어 내 테스트로 지킨다(5차). 동작은 그대로다.

import {HttpsError} from "firebase-functions/v2/https";

export const MIN_REWARD = 100;
export const MAX_REWARD = 5000;
export const REWARD_STEP = 100;
export const MAX_DEADLINE_MS = 15 * 24 * 60 * 60 * 1000;
export const MAX_TAGS = 20;
export const MAX_TAG_LENGTH = 10;
export const MAX_IMAGES = 10;

const POST_ID_PATTERN = /^[A-Za-z0-9]{10,40}$/;
const SNIPPET_LENGTH = 50;

export function text(
  value: unknown,
  field: string,
  max: number,
  required = true
) {
  if (value === undefined || value === null) {
    if (required) {
      throw new HttpsError("invalid-argument", `${field}이(가) 필요합니다.`);
    }
    return null;
  }
  if (typeof value !== "string" || value.length > max) {
    throw new HttpsError("invalid-argument", `${field}을(를) 확인해주세요.`);
  }
  if (required && value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${field}이(가) 필요합니다.`);
  }
  return value;
}

export function stringList(
  value: unknown,
  field: string,
  maxItems: number,
  maxLength: number
) {
  if (value === undefined || value === null) return [];
  if (
    !Array.isArray(value) ||
    value.length > maxItems ||
    value.some((item) => typeof item !== "string" || item.length > maxLength)
  ) {
    throw new HttpsError("invalid-argument", `${field}을(를) 확인해주세요.`);
  }
  return value as string[];
}

/** 앱이 보낸 글 id. 사진을 이 id 경로에 먼저 올리므로 앱이 만든다. */
export function questionPostId(value: unknown): string {
  if (typeof value !== "string" || !POST_ID_PATTERN.test(value)) {
    throw new HttpsError("invalid-argument", "질문 id를 확인해주세요.");
  }
  return value;
}

/** 보상 크래커는 100개 단위, 100~5000. */
export function questionReward(value: unknown): number {
  if (
    typeof value !== "number" ||
    !Number.isInteger(value) ||
    value < MIN_REWARD ||
    value > MAX_REWARD ||
    value % REWARD_STEP !== 0
  ) {
    throw new HttpsError("invalid-argument", "보상 크래커를 확인해주세요.");
  }
  return value;
}

/** 마감일은 지금보다 뒤, 15일 안. */
export function questionExpireAt(value: unknown, now: number): Date {
  const expireAt = new Date(text(value, "마감일", 40) as string);
  if (
    Number.isNaN(expireAt.getTime()) ||
    expireAt.getTime() <= now ||
    expireAt.getTime() > now + MAX_DEADLINE_MS
  ) {
    throw new HttpsError("invalid-argument", "마감일을 확인해주세요.");
  }
  return expireAt;
}

/**
 * 앱이 보낸 글에서 쓸 수 있는 필드만 골라 쓰고, 작성자·숫자·상태는
 * 서버가 정한다.
 */
export function buildQuestionDocument(params: {
  post: Record<string, unknown>;
  uid: string;
  now: number;
}): Record<string, unknown> {
  const {post, uid, now} = params;

  const postId = questionPostId(post.id);
  const reward = questionReward(post.rewardCrackers);
  const expireAt = questionExpireAt(post.expireAt, now);

  const imageUrls = stringList(post.imageUrls, "사진", MAX_IMAGES, 2000);
  if (imageUrls.some((url) => !url.startsWith("https://"))) {
    throw new HttpsError("invalid-argument", "사진을 확인해주세요.");
  }

  const nowIso = new Date(now).toISOString();
  const content = text(post.content, "내용", 20000) as string;

  return {
    id: postId,
    postType: "question",
    category: text(post.category, "분류", 30),
    targetLanguage: text(post.targetLanguage, "언어", 30, false),
    title: text(post.title, "제목", 200),
    content,
    tags: stringList(post.tags, "태그", MAX_TAGS, MAX_TAG_LENGTH),
    authorId: uid,
    authorNickname: text(post.authorNickname, "닉네임", 50, false) ?? "익명",
    authorAvatarUrl: text(post.authorAvatarUrl, "프로필 사진", 2000, false),
    snippet:
      content.length > SNIPPET_LENGTH ?
        `${content.substring(0, SNIPPET_LENGTH)}...` :
        content,
    hasImage: imageUrls.length > 0,
    imageUrls,
    viewCount: 0,
    likeCount: 0,
    commentCount: 0,
    scrapCount: 0,
    status: "active",
    reportCount: 0,
    createdAt: nowIso,
    updatedAt: nowIso,
    editHistory: [],
    questionStatus: "waiting",
    acceptedCommentId: null,
    rewardCrackers: reward,
    expireAt: expireAt.toISOString(),
  };
}
