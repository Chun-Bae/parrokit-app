// firestore.rules 테스트.
//
// `npm test`로 돌린다. firebase 에뮬레이터가 먼저 떠 있어야 한다
// (package.json의 test 스크립트가 emulators:exec로 띄운다).
//
// 여기서 확인하는 것은 두 가지다.
// 1. 앱이 실제로 하는 쓰기는 통과한다. 규칙을 좁히다 앱을 막으면 안 된다.
// 2. 남의 것을 건드리는 쓰기는 막힌다.
import test from "node:test";
import assert from "node:assert/strict";
import {
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  increment,
  runTransaction,
  writeBatch,
} from "firebase/firestore";
import { makeTestEnv, seed, post, comment } from "./helpers.mjs";

const testEnv = await makeTestEnv();

test.afterEach(async () => {
  await testEnv.clearFirestore();
});

test.after(async () => {
  await testEnv.cleanup();
});

const alice = () => testEnv.authenticatedContext("alice").firestore();
const bob = () => testEnv.authenticatedContext("bob").firestore();
const stranger = () => testEnv.unauthenticatedContext().firestore();

// ---------------------------------------------------------------- posts

test("글은 작성자 본인만 만들 수 있다", async () => {
  await assertSucceeds(
    setDoc(doc(alice(), "posts/post1"), post({ authorId: "alice" }))
  );
  await assertFails(
    setDoc(doc(bob(), "posts/post2"), post({ id: "post2", authorId: "alice" }))
  );
});

test("로그인하지 않으면 글을 읽거나 쓸 수 없다", async () => {
  await seed(testEnv, (db) => setDoc(doc(db, "posts/post1"), post()));
  await assertFails(getDoc(doc(stranger(), "posts/post1")));
  await assertFails(setDoc(doc(stranger(), "posts/post9"), post({ id: "post9" })));
});

test("남의 글을 지울 수 없다", async () => {
  await seed(testEnv, (db) => setDoc(doc(db, "posts/post1"), post()));
  await assertFails(deleteDoc(doc(bob(), "posts/post1")));
  await assertSucceeds(deleteDoc(doc(alice(), "posts/post1")));
});

test("남의 글 내용을 고칠 수 없다", async () => {
  await seed(testEnv, (db) => setDoc(doc(db, "posts/post1"), post()));
  await assertFails(
    updateDoc(doc(bob(), "posts/post1"), { title: "바꿔치기" })
  );
  await assertSucceeds(
    updateDoc(doc(alice(), "posts/post1"), { title: "내가 고친다" })
  );
});

test("조회수·추천수·스크랩수는 남이 한 칸씩 움직일 수 있다", async () => {
  await seed(testEnv, (db) => setDoc(doc(db, "posts/post1"), post()));
  await assertSucceeds(
    updateDoc(doc(bob(), "posts/post1"), { viewCount: increment(1) })
  );
  await assertSucceeds(
    updateDoc(doc(bob(), "posts/post1"), { likeCount: increment(1) })
  );
  await assertSucceeds(
    updateDoc(doc(bob(), "posts/post1"), { likeCount: increment(-1) })
  );
  await assertSucceeds(
    updateDoc(doc(bob(), "posts/post1"), { scrapCount: increment(1) })
  );
});

test("수를 한 번에 여러 칸 올릴 수 없다", async () => {
  await seed(testEnv, (db) => setDoc(doc(db, "posts/post1"), post()));
  await assertFails(
    updateDoc(doc(bob(), "posts/post1"), { likeCount: increment(500) })
  );
  await assertFails(
    updateDoc(doc(bob(), "posts/post1"), { viewCount: increment(-1) })
  );
});

test("수를 올리는 척하며 다른 필드를 같이 바꿀 수 없다", async () => {
  await seed(testEnv, (db) => setDoc(doc(db, "posts/post1"), post()));
  await assertFails(
    updateDoc(doc(bob(), "posts/post1"), {
      likeCount: increment(1),
      title: "슬쩍",
    })
  );
});

// ---------------------------------------------------------- 추천 트랜잭션

test("추천은 내 likes 문서와 글의 수를 같이 바꾼다", async () => {
  await seed(testEnv, (db) => setDoc(doc(db, "posts/post1"), post()));
  const db = bob();
  await assertSucceeds(
    runTransaction(db, async (tx) => {
      tx.set(doc(db, "users/bob/likes/post1"), { createdAt: new Date() });
      tx.update(doc(db, "posts/post1"), { likeCount: increment(1) });
    })
  );
});

test("남의 추천 기록은 읽거나 지울 수 없다", async () => {
  await seed(testEnv, (db) =>
    setDoc(doc(db, "users/alice/likes/post1"), { createdAt: new Date() })
  );
  await assertFails(getDoc(doc(bob(), "users/alice/likes/post1")));
  await assertFails(deleteDoc(doc(bob(), "users/alice/likes/post1")));
  await assertFails(getDoc(doc(stranger(), "users/alice/likes/post1")));
  await assertSucceeds(getDoc(doc(alice(), "users/alice/likes/post1")));
});

// ------------------------------------------------------------------ 댓글

test("댓글을 달면 글의 댓글 수가 같이 오른다", async () => {
  await seed(testEnv, (db) => setDoc(doc(db, "posts/post1"), post()));
  const db = bob();
  const batch = writeBatch(db);
  batch.set(doc(db, "posts/post1/comments/comment1"), comment({ authorId: "bob" }));
  batch.update(doc(db, "posts/post1"), { commentCount: increment(1) });
  await assertSucceeds(batch.commit());
});

test("남의 이름으로 댓글을 달 수 없다", async () => {
  await seed(testEnv, (db) => setDoc(doc(db, "posts/post1"), post()));
  await assertFails(
    setDoc(
      doc(bob(), "posts/post1/comments/comment1"),
      comment({ authorId: "alice" })
    )
  );
});

test("댓글은 작성자만 삭제 표시할 수 있고, 통째로 지울 수는 없다", async () => {
  await seed(testEnv, async (db) => {
    await setDoc(doc(db, "posts/post1"), post());
    await setDoc(doc(db, "posts/post1/comments/comment1"), comment({ authorId: "bob" }));
  });
  const deleted = {
    status: "deleted",
    content: "이 댓글은 삭제된 댓글입니다.",
    updatedAt: new Date().toISOString(),
  };
  await assertFails(updateDoc(doc(alice(), "posts/post1/comments/comment1"), deleted));
  await assertSucceeds(updateDoc(doc(bob(), "posts/post1/comments/comment1"), deleted));
  await assertFails(deleteDoc(doc(bob(), "posts/post1/comments/comment1")));
});

test("답변 채택은 질문을 쓴 사람만 할 수 있다", async () => {
  await seed(testEnv, async (db) => {
    await setDoc(doc(db, "posts/post1"), post({ postType: "question", authorId: "alice" }));
    await setDoc(doc(db, "posts/post1/comments/comment1"), comment({ authorId: "bob" }));
  });
  const accept = { isAccepted: true, updatedAt: new Date().toISOString() };
  // 답변을 쓴 사람이 스스로 채택할 수는 없다.
  await assertFails(updateDoc(doc(bob(), "posts/post1/comments/comment1"), accept));
  await assertSucceeds(updateDoc(doc(alice(), "posts/post1/comments/comment1"), accept));
});

test("댓글 좋아요 수는 남이 한 칸씩 움직일 수 있다", async () => {
  await seed(testEnv, async (db) => {
    await setDoc(doc(db, "posts/post1"), post());
    await setDoc(doc(db, "posts/post1/comments/comment1"), comment({ authorId: "bob" }));
  });
  await assertSucceeds(
    updateDoc(doc(alice(), "posts/post1/comments/comment1"), {
      likeCount: increment(1),
    })
  );
  await assertFails(
    updateDoc(doc(alice(), "posts/post1/comments/comment1"), {
      likeCount: increment(99),
    })
  );
});

// ------------------------------------------------------------------ 투표

test("투표는 내 voters 문서를 새로 만들 때만 집계를 바꿀 수 있다", async () => {
  await seed(testEnv, (db) =>
    setDoc(
      doc(db, "posts/post1"),
      post({
        postType: "vote",
        voteOptions: [
          { text: "가", count: 0 },
          { text: "나", count: 0 },
        ],
      })
    )
  );

  const db = bob();
  await assertSucceeds(
    runTransaction(db, async (tx) => {
      tx.update(doc(db, "posts/post1"), {
        voteOptions: [
          { text: "가", count: 1 },
          { text: "나", count: 0 },
        ],
      });
      tx.set(doc(db, "posts/post1/voters/bob"), {
        userId: "bob",
        selectedOption: 0,
        votedAt: new Date(),
      });
      tx.set(doc(db, "users/bob/voted_posts/post1"), {
        postId: "post1",
        selectedOption: 0,
        votedAt: new Date(),
      });
    })
  );
});

test("voters 문서 없이 집계만 바꿀 수 없다", async () => {
  await seed(testEnv, (db) =>
    setDoc(
      doc(db, "posts/post1"),
      post({
        postType: "vote",
        voteOptions: [{ text: "가", count: 0 }],
      })
    )
  );
  await assertFails(
    updateDoc(doc(bob(), "posts/post1"), {
      voteOptions: [{ text: "가", count: 9999 }],
    })
  );
});

test("두 번 투표할 수 없다", async () => {
  await seed(testEnv, async (db) => {
    await setDoc(
      doc(db, "posts/post1"),
      post({ postType: "vote", voteOptions: [{ text: "가", count: 1 }] })
    );
    await setDoc(doc(db, "posts/post1/voters/bob"), {
      userId: "bob",
      selectedOption: 0,
      votedAt: new Date(),
    });
  });

  const db = bob();
  await assertFails(
    runTransaction(db, async (tx) => {
      tx.update(doc(db, "posts/post1"), {
        voteOptions: [{ text: "가", count: 2 }],
      });
      tx.set(doc(db, "posts/post1/voters/bob"), {
        userId: "bob",
        selectedOption: 0,
        votedAt: new Date(),
      });
    })
  );
});

test("남의 이름으로 투표 기록을 만들 수 없다", async () => {
  await seed(testEnv, (db) => setDoc(doc(db, "posts/post1"), post()));
  await assertFails(
    setDoc(doc(bob(), "posts/post1/voters/alice"), {
      userId: "alice",
      selectedOption: 0,
      votedAt: new Date(),
    })
  );
});

// ---------------------------------------------------------------- 닉네임

test("닉네임 중복 확인은 로그인 전에도 할 수 있다", async () => {
  await seed(testEnv, (db) =>
    setDoc(doc(db, "nicknames/이미있음"), { uid: "alice", createdAt: new Date() })
  );
  // 이메일 회원가입 화면은 계정을 만들기 전에 이걸 읽는다.
  await assertSucceeds(getDoc(doc(stranger(), "nicknames/이미있음")));
});

test("남이 쓰는 닉네임을 가져갈 수 없다", async () => {
  await seed(testEnv, (db) =>
    setDoc(doc(db, "nicknames/앨리스"), { uid: "alice", createdAt: new Date() })
  );
  await assertFails(
    setDoc(doc(bob(), "nicknames/앨리스"), { uid: "bob", createdAt: new Date() })
  );
  await assertFails(deleteDoc(doc(bob(), "nicknames/앨리스")));
});

test("빈 닉네임을 내 것으로 선점할 수 있고, 내 것은 놓을 수 있다", async () => {
  await assertSucceeds(
    setDoc(doc(bob(), "nicknames/새이름"), { uid: "bob", createdAt: new Date() })
  );
  await assertSucceeds(deleteDoc(doc(bob(), "nicknames/새이름")));
});

test("남의 uid로 닉네임을 선점할 수 없다", async () => {
  await assertFails(
    setDoc(doc(bob(), "nicknames/사칭"), { uid: "alice", createdAt: new Date() })
  );
});

// ----------------------------------------------------------------- 크래커

test("남의 크래커를 깎을 수 없다", async () => {
  await seed(testEnv, (db) =>
    setDoc(doc(db, "users/alice"), { id: "alice", crackers: 1000, coins: 20 })
  );
  // 답변 채택은 남의 크래커를 올려 준다. 이건 통과해야 한다.
  await assertSucceeds(
    updateDoc(doc(bob(), "users/alice"), { crackers: increment(50) })
  );
  await assertFails(
    updateDoc(doc(bob(), "users/alice"), { crackers: increment(-900) })
  );
  await assertFails(updateDoc(doc(bob(), "users/alice"), { crackers: 0 }));
});

test("크래커를 올리는 척하며 남의 다른 필드를 바꿀 수 없다", async () => {
  await seed(testEnv, (db) =>
    setDoc(doc(db, "users/alice"), { id: "alice", crackers: 1000, coins: 20 })
  );
  await assertFails(
    updateDoc(doc(bob(), "users/alice"), {
      crackers: increment(1),
      coins: 99999,
    })
  );
});

// ---------------------------------------------------------------- devices

test("남의 디바이스 문서를 덮어쓸 수 없다", async () => {
  await seed(testEnv, (db) =>
    setDoc(doc(db, "devices/device1"), { userId: "alice", date: "2026-01-01" })
  );
  // 전에는 date가 다르면 통과하는 길이 있었다.
  await assertFails(
    setDoc(doc(bob(), "devices/device1"), { userId: "bob", date: "2026-01-02" })
  );
});

assert.ok(true);

// ---------------------------------------------------------------- words (5차 내 단어)

const word = (fields = {}) => ({
  ownerId: "alice",
  language: "영어",
  word: "figure out",
  meaning: "알아내다",
  example: "We'll figure it out together.",
  exampleTranslation: "같이 해결해 보자.",
  sourceSentenceId: "",
  topic: "내 단어",
  createdAt: new Date(),
  ...fields,
});

test("내 단어는 본인 것만 만들고 읽고 지울 수 있다", async () => {
  await assertSucceeds(setDoc(doc(alice(), "words/w1"), word()));
  await assertSucceeds(getDoc(doc(alice(), "words/w1")));
  await assertFails(getDoc(doc(bob(), "words/w1")));
  await assertFails(deleteDoc(doc(bob(), "words/w1")));
  await assertSucceeds(deleteDoc(doc(alice(), "words/w1")));
});

test("남의 이름으로 단어를 만들거나 로그인 없이 쓸 수 없다", async () => {
  await assertFails(setDoc(doc(bob(), "words/w2"), word({ ownerId: "alice" })));
  await assertFails(setDoc(doc(stranger(), "words/w3"), word()));
});

test("빈 단어나 너무 긴 단어는 저장할 수 없다", async () => {
  await assertFails(setDoc(doc(alice(), "words/w4"), word({ word: "" })));
  await assertFails(setDoc(doc(alice(), "words/w5"), word({ word: "a".repeat(81) })));
});

test("단어 주인을 다른 사람으로 바꿀 수 없다", async () => {
  await seed(testEnv, (db) => setDoc(doc(db, "words/w6"), word()));
  await assertSucceeds(updateDoc(doc(alice(), "words/w6"), { meaning: "해결하다" }));
  await assertFails(updateDoc(doc(alice(), "words/w6"), { ownerId: "bob" }));
});
