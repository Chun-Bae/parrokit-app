/* eslint-disable require-jsdoc, max-len, indent */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import {onSchedule} from "firebase-functions/v2/scheduler";

const db = admin.firestore();

const boardTypeLabelMap: Record<string, string> = {
  board: "일반",
  question: "질문",
  vote: "투표",
};

type NotificationPayload = {
  recipientUserId: string;
  notificationType: "post_comment" | "comment_reply" | "vote_end";
  boardType: string;
  postId: string;
  commentId?: string;
  parentCommentId?: string;
  actorId: string;
  actorDisplayName?: string;
  title: string;
  body: string;
  routePath: string;
};

export const onCommunityCommentCreated = functions
  .region("asia-northeast3")
  .firestore.document("posts/{postId}/comments/{commentId}")
  .onCreate(async (snapshot: functions.firestore.QueryDocumentSnapshot, context: functions.EventContext) => {
    const commentData = snapshot.data() as Record<string, unknown>;
    const postId = context.params.postId;
    const commentId = context.params.commentId;
    const authorId = asString(commentData.authorId);
    if (!authorId) return;

    const postSnap = await db.collection("posts").doc(postId).get();
    if (!postSnap.exists) return;

    const postData = postSnap.data() as Record<string, unknown>;
    const boardType = asString(postData.postType) || "board";
    const postAuthorId = asString(postData.authorId);
    const actorDisplayName = asString(commentData.authorNickname);
    const parentId = asString(commentData.parentId);

    const recipientMap = new Map<string, NotificationPayload>();

    if (postAuthorId && postAuthorId !== authorId) {
      recipientMap.set(
        postAuthorId,
        buildCommentNotification({
          recipientUserId: postAuthorId,
          notificationType: "post_comment",
          boardType,
          postId,
          commentId,
          parentCommentId: parentId ?? undefined,
          actorId: authorId,
          actorDisplayName: actorDisplayName ?? undefined,
          routePath: buildRoutePath(boardType, postId),
          title: buildCommentTitle(boardType),
          body: buildCommentBody(boardType, actorDisplayName ?? undefined),
        })
      );
    }

    if (parentId) {
      const parentSnap = await db
        .collection("posts")
        .doc(postId)
        .collection("comments")
        .doc(parentId)
        .get();

      if (parentSnap.exists) {
        const parentData = parentSnap.data() as Record<string, unknown>;
        const parentAuthorId = asString(parentData.authorId);
        const parentAuthorNickname = asString(parentData.authorNickname);

        if (parentAuthorId && parentAuthorId !== authorId) {
          recipientMap.set(
            parentAuthorId,
            buildCommentNotification({
              recipientUserId: parentAuthorId,
              notificationType: "comment_reply",
              boardType,
              postId,
              commentId,
              parentCommentId: parentId ?? undefined,
              actorId: authorId,
              actorDisplayName: actorDisplayName ?? undefined,
              routePath: buildRoutePath(boardType, postId),
              title: buildReplyTitle(boardType),
              body: buildReplyBody(
                boardType,
                actorDisplayName ?? undefined,
                parentAuthorNickname ?? undefined,
              ),
            })
          );
        }
      }
    }

    await Promise.all(
      Array.from(recipientMap.values()).map(async (payload) => {
        await saveNotification(payload);
        await safeSendPushNotification(payload);
      }),
    );
  });

export const onVoteEndNotification = onSchedule(
  "every 10 minutes",
  async () => {
    const now = new Date();
    console.log(
      `[CommunityNotification][VoteEnd] scan start now=${now.toISOString()}`
    );
    const voteSnapshot = await db
      .collection("posts")
      .where("postType", "==", "vote")
      .get();

    console.log(
      `[CommunityNotification][VoteEnd] vote candidates=${voteSnapshot.size}`
    );

    const duePosts = voteSnapshot.docs.filter((doc) => {
      const data = doc.data() as Record<string, unknown>;
      const voteEndTime = parseVoteEndTime(data.voteEndTime);
      const notifiedAt = data.voteEndNotificationSentAt;
      if (notifiedAt) return false;
      if (!voteEndTime) return false;

      return voteEndTime <= now;
    });

    console.log(
      `[CommunityNotification][VoteEnd] due posts=${duePosts.length}`
    );

    for (const postDoc of duePosts) {
      const postId = postDoc.id;
      const postData = postDoc.data() as Record<string, unknown>;
      const postTitle = asString(postData.title) || "투표";
      const routePath = buildRoutePath("vote", postId);
      const voteEndTime = parseVoteEndTime(postData.voteEndTime);

      const votersSnapshot = await db
        .collectionGroup("voted_posts")
        .where("postId", "==", postId)
        .get();

      console.log(
        `[CommunityNotification][VoteEnd] dispatch postId=${postId} title=${postTitle} endAt=${voteEndTime?.toISOString() ?? "unknown"} voters=${votersSnapshot.size}`
      );

      await Promise.all(
        votersSnapshot.docs.map(async (doc) => {
          const userId = doc.ref.parent.parent?.id;
          if (!userId) return;

          const payload = buildVoteEndNotification({
            recipientUserId: userId,
            boardType: "vote",
            postId,
            actorId: "system",
            title: "투표가 종료되었어요.",
            body: `${postTitle} 결과를 확인해 보세요.`,
            routePath,
          });

          await saveNotification(payload);
          await safeSendPushNotification(payload);
          console.log(
            `[CommunityNotification][VoteEnd] sent recipient=${userId} postId=${postId}`
          );
        }),
      );

      await postDoc.ref.set(
        {
          voteEndNotificationSentAt: admin.firestore.Timestamp.now(),
          updatedAt: admin.firestore.Timestamp.now(),
        },
        {merge: true},
      );
    }
  },
);

async function saveNotification(payload: NotificationPayload): Promise<void> {
  const notificationId = buildNotificationId(payload);
  const docRef = db
    .collection("users")
    .doc(payload.recipientUserId)
    .collection("notifications")
    .doc(notificationId);
  const userRef = db.collection("users").doc(payload.recipientUserId);

  const notificationData: Record<string, unknown> = {
    recipientUserId: payload.recipientUserId,
    notificationType: payload.notificationType,
    boardType: payload.boardType,
    postId: payload.postId,
    actorId: payload.actorId,
    title: payload.title,
    body: payload.body,
    routePath: payload.routePath,
    isRead: false,
    createdAt: admin.firestore.Timestamp.now(),
    readAt: null,
  };

  if (payload.commentId) {
    notificationData.commentId = payload.commentId;
  }
  if (payload.parentCommentId) {
    notificationData.parentCommentId = payload.parentCommentId;
  }
  if (payload.actorDisplayName) {
    notificationData.actorDisplayName = payload.actorDisplayName;
  }

  await db.runTransaction(async (transaction) => {
    const existingSnap = await transaction.get(docRef);
    if (!existingSnap.exists) {
      transaction.set(docRef, notificationData, {merge: true});
      transaction.set(userRef, {
        unreadNotificationCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.Timestamp.now(),
      }, {merge: true});
      return;
    }

    // 이미 있는 알림에 isRead:false, readAt:null, createdAt을 다시 쓰고
    // 있었다. Cloud Functions는 같은 이벤트를 두 번 보낼 수 있고, 투표
    // 종료는 보내는 중에 끊기면 다음 차례에 전부 다시 보낸다. 그러면
    // 사용자가 이미 읽은 알림이 안 읽음으로 되돌아가는데, 이 길에서는
    // unreadNotificationCount를 올리지 않으므로 뱃지 숫자와 실제 안 읽은
    // 개수가 어긋난다. 다시 보낼 때는 보이는 내용만 갱신한다.
    const redeliverable = {...notificationData};
    delete redeliverable.isRead;
    delete redeliverable.readAt;
    delete redeliverable.createdAt;
    transaction.set(docRef, redeliverable, {merge: true});
  });
}

async function safeSendPushNotification(payload: NotificationPayload): Promise<void> {
  try {
    const userSnap = await db.collection("users").doc(payload.recipientUserId).get();
    if (!userSnap.exists) return;

    const userData = userSnap.data() as Record<string, unknown>;
    const tokens = (userData.fcmTokens as unknown[] | undefined)
      ?.map((value) => String(value))
      .filter((token) => token.length > 0) ?? [];

    if (tokens.length === 0) return;

    const result = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: {
        notificationId: buildNotificationId(payload),
        notificationType: payload.notificationType,
        boardType: payload.boardType,
        postId: payload.postId,
        commentId: payload.commentId ?? "",
        parentCommentId: payload.parentCommentId ?? "",
        routePath: payload.routePath,
        actorId: payload.actorId,
        actorDisplayName: payload.actorDisplayName ?? "",
      },
    });

    await pruneDeadTokens(payload.recipientUserId, tokens, result);
  } catch (error) {
    console.error("[CommunityNotification][FCM] send failed", error);
  }
}

// 앱을 지우거나 토큰이 바뀌면 옛 토큰은 영영 쓸 수 없게 된다. 앱은 자기
// 토큰만 arrayRemove할 수 있으므로, 못 쓰게 된 토큰은 아무도 치우지
// 않고 fcmTokens에 계속 쌓인다. 쌓인 만큼 매번 발송 대상에 들어가고
// 전부 실패한다. 발송 결과에서 등록이 끊긴 토큰만 골라 지운다.
async function pruneDeadTokens(
  recipientUserId: string,
  tokens: string[],
  result: admin.messaging.BatchResponse,
): Promise<void> {
  const deadTokens = result.responses
    .map((response, index) => {
      if (response.success) return null;
      const code = response.error?.code;
      // invalid-argument는 토큰이 아니라 보낸 내용이 잘못됐을 때도 나온다.
      // 그걸로 지우면 멀쩡한 토큰을 날린다. 토큰 자체가 끊긴 두 코드만 본다.
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        return tokens[index];
      }
      return null;
    })
    .filter((token): token is string => token !== null);

  if (deadTokens.length === 0) return;

  console.log(
    `[CommunityNotification][FCM] pruning dead tokens recipient=${recipientUserId} count=${deadTokens.length}`
  );

  try {
    await db.collection("users").doc(recipientUserId).update({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(...deadTokens),
    });
  } catch (error) {
    console.error("[CommunityNotification][FCM] prune failed", error);
  }
}

function buildNotificationId(payload: NotificationPayload): string {
  const commentPart = payload.commentId ?? "post";
  return [
    payload.notificationType,
    payload.postId,
    commentPart,
    payload.recipientUserId,
  ].join("_");
}

function buildCommentNotification(payload: NotificationPayload): NotificationPayload {
  return payload;
}

function buildVoteEndNotification(payload: Omit<NotificationPayload, "notificationType" | "commentId" | "parentCommentId" | "actorDisplayName">): NotificationPayload {
  return {
    ...payload,
    notificationType: "vote_end",
  };
}

function buildRoutePath(boardType: string, postId: string): string {
  switch (boardType) {
    case "question":
      return `/community/question/${postId}`;
    case "vote":
      return `/community/vote/${postId}`;
    default:
      return `/community/board/${postId}`;
  }
}

function buildCommentTitle(boardType: string): string {
  return `${boardTypeLabelMap[boardType] ?? "게시글"}에 새 댓글이 달렸어요.`;
}

function buildReplyTitle(boardType: string): string {
  return `${boardTypeLabelMap[boardType] ?? "게시글"} 댓글에 답글이 달렸어요.`;
}

function buildCommentBody(boardType: string, actorDisplayName?: string): string {
  const label = boardTypeLabelMap[boardType] ?? "게시글";
  const actor = actorDisplayName && actorDisplayName.length > 0 ? actorDisplayName : "누군가";
  return `${actor}님이 ${label}에 댓글을 남겼어요.`;
}

function buildReplyBody(
  boardType: string,
  actorDisplayName?: string,
  parentDisplayName?: string,
): string {
  const label = boardTypeLabelMap[boardType] ?? "게시글";
  const actor = actorDisplayName && actorDisplayName.length > 0 ? actorDisplayName : "누군가";
  const parent = parentDisplayName && parentDisplayName.length > 0 ? parentDisplayName : "내 댓글";
  return `${actor}님이 ${label}의 ${parent}에 답글을 남겼어요.`;
}

function asString(value: unknown): string | null {
  if (typeof value === "string" && value.length > 0) {
    return value;
  }
  return null;
}

function parseVoteEndTime(value: unknown): Date | null {
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate();
  }

  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value;
  }

  if (typeof value === "number") {
    const parsedDate = new Date(value);
    return Number.isNaN(parsedDate.getTime()) ? null : parsedDate;
  }

  if (typeof value === "string" && value.length > 0) {
    const hasTimezone = /([zZ]|[+-]\d{2}:\d{2})$/.test(value);
    const normalizedValue = hasTimezone ? value : `${value}+09:00`;
    const parsedDate = new Date(normalizedValue);

    if (!Number.isNaN(parsedDate.getTime())) {
      if (!hasTimezone) {
        console.log(
          `[CommunityNotification][VoteEnd] normalized naive voteEndTime value=${value} normalized=${normalizedValue}`
        );
      }
      return parsedDate;
    }
  }

  return null;
}
