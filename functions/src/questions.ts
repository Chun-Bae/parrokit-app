/* eslint-disable require-jsdoc */
// 질문 등록(크래커 차감)과 답변 채택(크래커 지급)을 서버에서 한다.
//
// 전에는 앱이 트랜잭션으로 자기 크래커를 깎고 글을 썼고, 채택할 때는
// 답변자의 크래커를 직접 올렸다. 규칙은 "남의 크래커를 올리는 것"을
// 허용해야 했고, 그래서 아무나 남의 크래커를 얼마든지 올릴 수 있었다.
// 이제 보상 액수는 질문 글의 rewardCrackers에서 서버가 읽는다.

import * as admin from "firebase-admin";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {appCheckOptions} from "./appCheck";
import {ledgerExists, readWallet, writeWallet} from "./wallet";
import {questionNeedsRefund} from "./questionExpiry";

const MIN_REWARD = 100;
const MAX_REWARD = 5000;
const REWARD_STEP = 100;
const MAX_DEADLINE_MS = 15 * 24 * 60 * 60 * 1000;
const MAX_TAGS = 20;
const MAX_TAG_LENGTH = 10;
const MAX_IMAGES = 10;

function text(value: unknown, field: string, max: number, required = true) {
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

function stringList(
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

/**
 * 질문 글을 만들고 보상 크래커를 맡긴다(작성자 잔액에서 뺀다).
 * 글 id는 앱이 만든다. 사진을 그 id 경로에 먼저 올리기 때문이다.
 * 앱이 보낸 글에서 쓸 수 있는 필드만 골라 쓰고, 작성자·숫자·상태는
 * 서버가 정한다.
 */
export const createQuestion = onCall(appCheckOptions, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }
  const post = request.data?.post;
  if (!post || typeof post !== "object") {
    throw new HttpsError("invalid-argument", "질문 내용이 필요합니다.");
  }

  const postId = post.id;
  if (typeof postId !== "string" || !/^[A-Za-z0-9]{10,40}$/.test(postId)) {
    throw new HttpsError("invalid-argument", "질문 id를 확인해주세요.");
  }
  const reward = post.rewardCrackers;
  if (
    typeof reward !== "number" ||
    !Number.isInteger(reward) ||
    reward < MIN_REWARD ||
    reward > MAX_REWARD ||
    reward % REWARD_STEP !== 0
  ) {
    throw new HttpsError("invalid-argument", "보상 크래커를 확인해주세요.");
  }
  const expireAt = new Date(text(post.expireAt, "마감일", 40) as string);
  const now = Date.now();
  if (
    Number.isNaN(expireAt.getTime()) ||
    expireAt.getTime() <= now ||
    expireAt.getTime() > now + MAX_DEADLINE_MS
  ) {
    throw new HttpsError("invalid-argument", "마감일을 확인해주세요.");
  }
  const imageUrls = stringList(post.imageUrls, "사진", MAX_IMAGES, 2000);
  if (imageUrls.some((url) => !url.startsWith("https://"))) {
    throw new HttpsError("invalid-argument", "사진을 확인해주세요.");
  }

  const nowIso = new Date(now).toISOString();
  const content = text(post.content, "내용", 20000) as string;
  const document = {
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
    snippet: content.length > 50 ? `${content.substring(0, 50)}...` : content,
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

  const db = admin.firestore();
  const postRef = db.collection("posts").doc(postId);
  const balance = await db.runTransaction(async (tx) => {
    const existing = await tx.get(postRef);
    const wallet = await readWallet(tx, uid);
    if (existing.exists) {
      throw new HttpsError("already-exists", "이미 등록된 질문입니다.");
    }
    if (!wallet.exists) {
      throw new HttpsError(
        "failed-precondition",
        "유저 정보를 찾을 수 없습니다."
      );
    }
    if (wallet.crackers < reward) {
      throw new HttpsError(
        "failed-precondition",
        "보유한 크래커가 부족합니다."
      );
    }
    const after = writeWallet(tx, wallet, {crackers: -reward}, {
      key: `question_${postId}`,
      reason: "question",
      meta: {postId},
    });
    tx.set(postRef, document);
    return after;
  });
  return {post: document, parrots: balance.parrots, crackers: balance.crackers};
});

/**
 * 질문 작성자가 답변을 채택하고, 질문에 걸린 크래커를 답변자에게 준다.
 * 보상 액수는 질문 글에서 읽는다. 내 답변은 채택할 수 없다.
 */
export const acceptAnswer = onCall(appCheckOptions, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }
  const {postId, commentId} = request.data ?? {};
  if (
    typeof postId !== "string" ||
    postId.length === 0 ||
    postId.includes("/")
  ) {
    throw new HttpsError("invalid-argument", "질문 id를 확인해주세요.");
  }
  if (
    typeof commentId !== "string" ||
    commentId.length === 0 ||
    commentId.includes("/")
  ) {
    throw new HttpsError("invalid-argument", "답변 id를 확인해주세요.");
  }

  const db = admin.firestore();
  const postRef = db.collection("posts").doc(postId);
  const commentRef = postRef.collection("comments").doc(commentId);

  await db.runTransaction(async (tx) => {
    const [postSnap, commentSnap] = await Promise.all([
      tx.get(postRef),
      tx.get(commentRef),
    ]);
    const post = postSnap.data();
    const comment = commentSnap.data();
    if (!post) {
      throw new HttpsError("not-found", "게시글을 찾을 수 없습니다.");
    }
    if (post.postType !== "question" || post.authorId !== uid) {
      throw new HttpsError(
        "permission-denied",
        "질문을 쓴 사람만 채택할 수 있습니다."
      );
    }
    if (post.questionStatus === "resolved") {
      throw new HttpsError(
        "failed-precondition",
        "이미 채택이 완료된 질문입니다."
      );
    }
    if (post.questionStatus === "expired") {
      throw new HttpsError(
        "failed-precondition",
        "마감 기한이 지난 질문입니다."
      );
    }
    if (!comment || comment.status === "deleted") {
      throw new HttpsError("not-found", "답변을 찾을 수 없습니다.");
    }
    const answererId = comment.authorId;
    if (typeof answererId !== "string" || answererId.length === 0) {
      throw new HttpsError(
        "failed-precondition",
        "답변 작성자를 알 수 없습니다."
      );
    }
    if (answererId === uid) {
      throw new HttpsError(
        "failed-precondition",
        "내 답변은 채택할 수 없습니다."
      );
    }
    const reward = typeof post.rewardCrackers === "number" ?
      Math.max(0, Math.trunc(post.rewardCrackers)) :
      0;
    const wallet = await readWallet(tx, answererId);
    const key = `accept_${postId}`;
    const alreadyPaid = await ledgerExists(tx, wallet, key);

    const nowIso = new Date().toISOString();
    tx.update(postRef, {
      questionStatus: "resolved",
      acceptedCommentId: commentId,
      updatedAt: nowIso,
    });
    tx.update(commentRef, {isAccepted: true, updatedAt: nowIso});
    // 답변자 문서가 없으면(탈퇴 등) 보상은 건너뛴다. 전에도 그랬다.
    if (wallet.exists && reward > 0 && !alreadyPaid) {
      writeWallet(tx, wallet, {crackers: reward}, {
        key,
        reason: "accept_answer",
        meta: {postId, commentId, questionAuthorId: uid},
      });
    }
  });
  return {ok: true};
});

/**
 * 마감이 지난 질문의 크래커를 질문한 사람에게 돌려준다.
 *
 * 전에는 질문을 'expired'로 바꾸는 곳이 어디에도 없어서, 마감이 지나도
 * 질문은 '답변 대기'로 남고 걸어 둔 크래커는 아무에게도 가지 않았다
 * (사용자 결정 2026-11-14). 한 번 돌려준 질문은 ledger 키로 막는다.
 *
 * 투표 마감 알림과 같은 방식으로, 색인 없이 질문 글을 읽어 메모리에서 고른다.
 */
export const onExpiredQuestionRefund = onSchedule(
  "every 30 minutes",
  async () => {
    const now = new Date();
    const db = admin.firestore();
    const snapshot = await db
      .collection("posts")
      .where("postType", "==", "question")
      .get();
    const due = snapshot.docs.filter((doc) =>
      questionNeedsRefund(doc.data() as Record<string, unknown>, now)
    );
    console.log(
      `[Question][ExpireRefund] candidates=${snapshot.size} due=${due.length}`
    );

    for (const doc of due) {
      const postId = doc.id;
      try {
        await db.runTransaction(async (tx) => {
          const postRef = db.collection("posts").doc(postId);
          const fresh = await tx.get(postRef);
          const post = fresh.data();
          // 읽는 사이 채택됐을 수 있다. 다시 본다.
          if (!post || !questionNeedsRefund(post, now)) return;
          const authorId = typeof post.authorId === "string" ?
            post.authorId :
            "";
          const reward = Math.trunc(post.rewardCrackers as number);
          const wallet = authorId ? await readWallet(tx, authorId) : null;
          const key = `question_expired_${postId}`;
          const alreadyPaid = wallet ?
            await ledgerExists(tx, wallet, key) :
            true;

          tx.update(postRef, {
            questionStatus: "expired",
            updatedAt: now.toISOString(),
          });
          // 글쓴이 문서가 없으면(탈퇴 등) 상태만 바꾸고 넘어간다.
          if (wallet && wallet.exists && !alreadyPaid) {
            writeWallet(tx, wallet, {crackers: reward}, {
              key,
              reason: "question_expired",
              meta: {postId},
            });
          }
        });
        console.log(`[Question][ExpireRefund] done postId=${postId}`);
      } catch (error) {
        // 한 건이 실패해도 나머지는 계속 처리한다. 다음 차례에 다시 본다.
        console.error(
          `[Question][ExpireRefund] failed postId=${postId}`,
          error
        );
      }
    }
  }
);
