import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:flutter/services.dart';

/// Kakao SSO(싱글 사인온) 연동을 전담하는 서비스.
/// - Kakao SDK를 이용해 인증을 진행하고 Firebase 연동에 필요한 Credential을 반환합니다.
/// - Firebase OIDC (OpenID Connect) 연동을 지원하기 위해 idToken이 필요합니다.
class KakaoSsoService {
  /// Kakao 로그인을 수행하고 Firebase용 OAuthCredential을 반환합니다.
  /// 사용자가 로그인을 취소하면 null을 반환합니다.
  Future<fb.OAuthCredential?> getCredential() async {
    try {
      OAuthToken token;

      // 카카오톡 설치 여부 확인
      if (await isKakaoTalkInstalled()) {
        try {
          // 카카오톡으로 로그인 시도
          token = await UserApi.instance.loginWithKakaoTalk();
        } catch (error) {
          // 사용자가 카카오톡 설치 후 디바이스 권한 요청 화면에서 로그인을 취소한 경우,
          // 의도적인 취소로 간주하고 카카오계정으로 로그인 시도 없이 로그인 취소로 처리
          if (error is PlatformException && error.code == 'CANCELED') {
            return null;
          }
          // 카카오톡에 연결된 카카오계정이 없는 경우, 카카오계정으로 로그인 시도
          token = await UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        // 카카오톡이 설치되어 있지 않은 경우, 카카오계정으로 로그인 시도
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      final idToken = token.idToken;
      if (idToken == null) {
        throw Exception(
            'Kakao OpenID Connect가 활성화되지 않았습니다. 카카오 디벨로퍼스에서 OIDC를 활성화해주세요.');
      }

      // Firebase OIDC Provider 사용 (Firebase Console에서 oidc.kakao로 등록해야 함)
      final provider = fb.OAuthProvider('oidc.kakao');
      
      // Kakao에서 발급받은 idToken과 accessToken을 사용해 Credential 생성
      return provider.credential(
        idToken: idToken,
        accessToken: token.accessToken,
      );
    } catch (e) {
      // 전에는 아무 기록 없이 null만 돌려줬다. 카카오 로그인이 막혀도
      // 배포 뒤에는 흔적이 하나도 안 남는다.
      // 사용자가 직접 취소한 건 오류가 아니므로 구분한다.
      if (e is PlatformException && e.code == 'CANCELED') {
        AppLogger.d('[SSO][Kakao] 사용자가 로그인을 취소했다');
        return null;
      }
      AppLogger.e('[SSO][Kakao] 로그인 실패', error: e);
      return null;
    }
  }

  /// Kakao 계정 로그아웃
  Future<void> signOut() async {
    try {
      await UserApi.instance.logout();
    } catch (error) {
      // 이미 로그아웃되어 있으면 여기로 온다. 막는 건 아니지만 남겨는 둔다.
      AppLogger.w('[SSO][Kakao] 로그아웃 실패: $error');
    }
  }
}
