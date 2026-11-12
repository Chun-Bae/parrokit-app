// storage.rules 테스트.
//
// 전에는 모든 경로에 `allow write: if request.auth != null` 하나뿐이었다.
// 로그인한 사람은 누구나 남의 파일을 덮어쓰고 지울 수 있었다.
import test from "node:test";
import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { ref, uploadBytes, deleteObject } from "firebase/storage";
import { makeTestEnv } from "./helpers.mjs";

const testEnv = await makeTestEnv();

const bytes = new Uint8Array([1, 2, 3, 4]);

test.afterEach(async () => {
  await testEnv.clearStorage();
});

test.after(async () => {
  await testEnv.cleanup();
});

const alice = () => testEnv.authenticatedContext("alice").storage();
const bob = () => testEnv.authenticatedContext("bob").storage();
const stranger = () => testEnv.unauthenticatedContext().storage();

async function seedFile(path) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await uploadBytes(ref(context.storage(), path), bytes);
  });
}

test("자기 폴더에는 올릴 수 있다", async () => {
  await assertSucceeds(
    uploadBytes(ref(alice(), "users/alice/posts/post1/1.jpg"), bytes)
  );
  await assertSucceeds(
    uploadBytes(ref(alice(), "users/alice/profile_1.jpg"), bytes)
  );
  await assertSucceeds(
    uploadBytes(ref(alice(), "users/alice/clips/clip1/video.mp4"), bytes)
  );
  await assertSucceeds(
    uploadBytes(ref(alice(), "caption-inputs/alice/req1/source.wav"), bytes)
  );
});

test("남의 폴더에는 올릴 수 없다", async () => {
  await assertFails(
    uploadBytes(ref(bob(), "users/alice/profile_2.jpg"), bytes)
  );
  await assertFails(
    uploadBytes(ref(bob(), "users/alice/posts/post1/2.jpg"), bytes)
  );
  await assertFails(
    uploadBytes(ref(bob(), "caption-inputs/alice/req1/source.wav"), bytes)
  );
});

test("남의 파일을 덮어쓰거나 지울 수 없다", async () => {
  await seedFile("users/alice/profile_1.jpg");
  await assertFails(
    uploadBytes(ref(bob(), "users/alice/profile_1.jpg"), bytes)
  );
  await assertFails(deleteObject(ref(bob(), "users/alice/profile_1.jpg")));
  await assertSucceeds(deleteObject(ref(alice(), "users/alice/profile_1.jpg")));
});

test("로그인하지 않으면 아무 데도 올릴 수 없다", async () => {
  await assertFails(
    uploadBytes(ref(stranger(), "users/alice/profile_3.jpg"), bytes)
  );
  await assertFails(uploadBytes(ref(stranger(), "아무데나/1.jpg"), bytes));
});

test("정해진 두 갈래 밖에는 올릴 수 없다", async () => {
  // 전에는 로그인만 하면 어디에나 올릴 수 있었다.
  await assertFails(uploadBytes(ref(alice(), "junk/1.jpg"), bytes));
  await assertFails(uploadBytes(ref(alice(), "users/1.jpg"), bytes));
});

test("자동 자막 원본은 올린 사람만 읽는다", async () => {
  await seedFile("caption-inputs/alice/req1/source.wav");
  const { getBytes } = await import("firebase/storage");
  await assertFails(getBytes(ref(bob(), "caption-inputs/alice/req1/source.wav")));
  await assertSucceeds(
    getBytes(ref(alice(), "caption-inputs/alice/req1/source.wav"))
  );
});
