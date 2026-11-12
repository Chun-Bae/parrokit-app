import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import {ENFORCE_APP_CHECK} from "./appCheck";

// HTTP 콜러블 함수: Flutter에서 넘겨준 Access Token을 검증하고 Custom Token을 반환합니다.
export const createNaverCustomToken = functions.https.onCall(
  {enforceAppCheck: ENFORCE_APP_CHECK},
  async (request) => {
    const {accessToken} = request.data;

    if (!accessToken) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "The function must be called with one argument 'accessToken'."
      );
    }

    try {
      // 1. 네이버 서버에 Access Token을 보내서 유저 정보 가져오기
      const response = await fetch("https://openapi.naver.com/v1/nid/me", {
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      });

      if (!response.ok) {
        throw new Error(
          `Naver API request failed with status: ${response.status}`
        );
      }

      const data = await response.json();

      if (data.resultcode !== "00") {
        throw new functions.https.HttpsError(
          "unauthenticated",
          `Failed to authenticate with Naver: ${data.message}`
        );
      }

      // 2. 네이버 유저 정보 파싱
      const naverUser = data.response;
      const uid = `naver:${naverUser.id}`;

      // 3. Firebase Auth에 유저가 있는지 확인하고, 없으면 새로 생성 (이메일, 이름 등 저장)
      try {
        await admin.auth().getUser(uid);
        // 이미 가입된 유저라면 정보 업데이트 (선택 사항)
      } catch (error: unknown) {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        if ((error as any).code === "auth/user-not-found") {
          try {
            // 첫 가입 유저 생성
            await admin.auth().createUser({
              uid: uid,
              email: naverUser.email,
              displayName: naverUser.name || naverUser.nickname,
              photoURL: naverUser.profile_image,
            });
          } catch (createError: unknown) {
            // 같은 계정으로 두 번 동시에 로그인하면 양쪽 다 user-not-found를
            // 보고 둘 다 createUser를 부른다. 늦은 쪽은 실패하는데, 그건
            // 원하던 결과(계정이 있다)가 이미 이루어진 것이므로 그대로
            // 넘어간다. 전에는 이게 "Failed to create custom token."이 되어
            // 로그인이 실패했다.
            //
            // auth/email-already-exists는 다른 상황이다. 같은 이메일이 이미
            // 다른 로그인 방식의 계정에 붙어 있다는 뜻이고, 그건 계정을
            // 합칠지 말지 정해야 하는 문제라 여기서 삼키지 않는다.
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            const code = (createError as any).code;
            if (code === "auth/email-already-exists") {
              // 계정을 합치지 않고 안내만 한다. 네이버 프로필 이메일이 본인
              // 확인된 것이라는 보장이 없어서, 이메일로 기존 계정에 붙이면 남의
              // 계정에 들어갈 수 있다. 전에는 이 오류가 internal로 덮여서 앱에는
              // 아무 안내도 뜨지 않았다.
              throw await emailInUseError(naverUser.email);
            }
            if (code !== "auth/uid-already-exists") {
              throw createError;
            }
            console.warn(
              `[NaverAuth] createUser raced, continuing uid=${uid} code=${code}`
            );
          }
        } else {
          throw error;
        }
      }

      // 4. 앱(Flutter)으로 돌려줄 커스텀 토큰 생성
      const customToken = await admin.auth().createCustomToken(uid);

      return {customToken};
    } catch (error) {
      // 안쪽에서 던진 HttpsError를 그대로 보낸다. 전에는 네이버 인증
      // 실패(unauthenticated)와 인자 누락(invalid-argument)까지 전부
      // internal로 덮여서, 앱은 "다시 시도"와 "로그인을 다시" 중 무엇을
      // 안내해야 하는지 구분할 수 없었다.
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      console.error("Error creating Naver custom token:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to create custom token."
      );
    }
  });

/**
 * 기존 계정의 로그인 방식을 사람이 읽는 이름으로 바꾼다.
 * @param {admin.auth.UserRecord} user 같은 이메일을 가진 기존 계정
 * @return {string | null} 로그인 방식 이름. 모르면 null
 */
function signInMethodLabel(user: admin.auth.UserRecord): string | null {
  const ids = user.providerData.map((info) => info.providerId);
  if (ids.includes("google.com")) return "구글";
  if (ids.includes("apple.com")) return "애플";
  if (ids.includes("oidc.kakao")) return "카카오";
  if (ids.includes("password")) return "이메일";
  return null;
}

/**
 * 네이버 이메일이 이미 다른 계정에 있을 때 앱에 돌려줄 오류.
 * 이 이메일의 주인(네이버 토큰을 가진 사람)에게만 가는 응답이라
 * 기존 로그인 방식을 알려줘도 된다.
 * @param {string} email 네이버 프로필 이메일
 * @return {Promise<functions.https.HttpsError>} already-exists 오류
 */
async function emailInUseError(
  email: string
): Promise<functions.https.HttpsError> {
  let method: string | null = null;
  try {
    method = signInMethodLabel(await admin.auth().getUserByEmail(email));
  } catch (lookupError) {
    console.warn("[NaverAuth] existing account lookup failed", lookupError);
  }
  const message = method ?
    `이미 ${method}(으)로 가입한 이메일이에요. ${method}(으)로 로그인해 주세요.` :
    "이미 다른 방법으로 가입한 이메일이에요. 처음 가입한 방법으로 로그인해 주세요.";
  return new functions.https.HttpsError("already-exists", message, {method});
}

