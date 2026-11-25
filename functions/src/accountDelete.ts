/**
 * 탈퇴를 서버가 끝까지 해 준다(5차).
 *
 * 전에는 앱이 ①users 문서 삭제 → ②Auth 계정 삭제 순으로 했다. ②는
 * 로그인한 지 오래되면 `requires-recent-login`으로 거절되는데, 그러면
 * **문서는 없고 계정은 살아 있는** 상태가 남는다. 다시 들어가면 온보딩으로
 * 가고, 학습 기록은 이미 사라진 뒤다. 그걸 막으려고 "최근에 로그인했나"를
 * 미리 재는 가드를 뒀지만, 그 가드는 오래 켜 둔 사람의 탈퇴를 아예
 * 막아 버린다.
 *
 * Admin SDK는 재로그인을 요구하지 않는다. 그래서 이 함수가 대신 지운다.
 *
 * **순서가 핵심이다. Auth 계정을 맨 마지막에 지운다.**
 * 그 앞 단계가 실패하면 계정이 아직 살아 있으므로 앱이 다시 부를 수 있고,
 * 이미 지워진 것은 그냥 넘어간다(모든 단계가 멱등이다). 반대로 Auth를
 * 먼저 지우면 남은 문서를 치울 주인이 사라진다.
 */

import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {ENFORCE_APP_CHECK} from "./appCheck";

/** 한 번에 지우는 하위 문서 수. recursiveDelete의 기본값을 그대로 쓴다. */
const DELETE_CONCURRENCY = 50;

/**
 * 닉네임 선점을 푼다. **내가 쓰던 것일 때만** 지운다.
 *
 * 이걸 안 하면 nicknames 문서가 영영 남는다. isNicknameAvailable은 문서가
 * 있는지만 보므로, 탈퇴한 계정의 닉네임은 아무도 다시 쓸 수 없다.
 * 본인이 다시 가입해도 못 쓴다.
 *
 * @param {admin.firestore.Firestore} db Firestore 인스턴스.
 * @param {string} uid 탈퇴하는 사람.
 * @param {string | undefined} nickname 그 사람이 쓰던 닉네임. 없으면 넘어간다.
 * @return {Promise<void>} 선점을 풀었거나, 풀 것이 없어 넘어갔을 때 끝난다.
 */
async function releaseNickname(
  db: admin.firestore.Firestore,
  uid: string,
  nickname: string | undefined
): Promise<void> {
  if (!nickname) return;
  const ref = db.collection("nicknames").doc(nickname);
  const snap = await ref.get();
  if (!snap.exists) return;
  // 남이 이미 가져간 닉네임이면 건드리지 않는다.
  const ownerUid = snap.get("uid");
  if (typeof ownerUid === "string" && ownerUid !== uid) return;
  await ref.delete();
}

export const deleteAccount = onCall(
  {memory: "512MiB", enforceAppCheck: ENFORCE_APP_CHECK},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "로그인하면 쓸 수 있어요.");
    }

    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);

    // 1. 닉네임. 문서를 지우기 전에 읽어야 어떤 닉네임이었는지 알 수 있다.
    //    여기서 실패하면 아무것도 안 지워진 채로 끝난다 - 다시 누르면 된다.
    const snap = await userRef.get();
    const nickname = snap.exists ? snap.get("displayName") : undefined;
    await releaseNickname(
      db,
      uid,
      typeof nickname === "string" ? nickname : undefined
    );

    // 2. 문서와 그 아래 전부. 문서만 지우면 하위 컬렉션(추천·스크랩·댓글
    //    좋아요·투표 기록, storage_objects)이 주인 없이 남는다. Firestore는
    //    부모를 지워도 하위를 지우지 않으므로 recursiveDelete를 쓴다.
    await db.recursiveDelete(
      userRef,
      db.bulkWriter({throttling: {maxOpsPerSecond: DELETE_CONCURRENCY}})
    );

    // 3. 계정. 반드시 맨 마지막이다.
    //    이미 지워져 있으면(앞 단계가 끊겨 다시 부른 경우) 끝난 것으로 본다.
    try {
      await admin.auth().deleteUser(uid);
    } catch (error) {
      const code = (error as {code?: string}).code;
      if (code !== "auth/user-not-found") throw error;
    }

    return {ok: true};
  }
);
