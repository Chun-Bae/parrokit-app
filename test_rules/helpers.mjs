import { readFileSync } from "node:fs";
import { initializeTestEnvironment } from "@firebase/rules-unit-testing";

export const PROJECT_ID = "parrokit-rules-test";

export async function makeTestEnv() {
  return initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(new URL("../firestore.rules", import.meta.url), "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
    storage: {
      rules: readFileSync(new URL("../storage.rules", import.meta.url), "utf8"),
      host: "127.0.0.1",
      port: 9199,
    },
  });
}

/** 규칙을 거치지 않고 미리 문서를 넣어 둔다. */
export async function seed(testEnv, writer) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await writer(context.firestore());
  });
}

export function post(fields = {}) {
  return {
    id: "post1",
    postType: "board",
    title: "제목",
    content: "내용",
    authorId: "alice",
    viewCount: 0,
    likeCount: 0,
    commentCount: 0,
    scrapCount: 0,
    status: "normal",
    reportCount: 0,
    ...fields,
  };
}

export function comment(fields = {}) {
  return {
    id: "comment1",
    authorId: "bob",
    content: "댓글",
    postId: "post1",
    postType: "board",
    likeCount: 0,
    status: "normal",
    isAccepted: false,
    ...fields,
  };
}
