import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_naver_login/interface/types/naver_login_result.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';
import 'package:flutter_naver_login/interface/types/naver_token.dart';

/// 네이버 이메일이 이미 다른 로그인 방식의 계정에 있어서 로그인할 수 없을 때 던진다.
/// [message]는 서버가 만든 안내 문구로, 그대로 사용자에게 보여준다.
class NaverEmailInUseException implements Exception {
  const NaverEmailInUseException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Naver Login Service
/// 
/// 네이버 로그인은 OIDC를 기본 지원하지 않으므로, 
/// 1. flutter_naver_login 으로 Access Token 발급
/// 2. Firebase Cloud Functions (createNaverCustomToken) 에 토큰 전송하여 검증 및 Custom Token 발급
/// 3. 발급된 Custom Token 으로 FirebaseAuth 에 로그인
class NaverSsoService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserCredential?> getCredentialAndSignIn() async {
    try {
      // 1. 네이버 로그인 시도
      final NaverLoginResult result = await FlutterNaverLogin.logIn();
      if (result.status != NaverLoginStatus.loggedIn) {
        // 로그인이 취소되거나 에러가 발생한 경우
        return null;
      }

      // 2. Access Token 가져오기
      final NaverToken res = await FlutterNaverLogin.getCurrentAccessToken();
      final String accessToken = res.accessToken;

      if (accessToken.isEmpty) {
        throw Exception("Naver Access Token is empty");
      }

      // 3. Cloud Functions 호출하여 Custom Token 받아오기
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('createNaverCustomToken');
      final response = await callable.call(<String, dynamic>{
        'accessToken': accessToken,
      });

      final String? customToken = response.data['customToken'];
      if (customToken == null || customToken.isEmpty) {
        throw Exception("Failed to retrieve custom token from Cloud Functions");
      }

      // 4. Custom Token으로 Firebase Auth 로그인
      final UserCredential userCredential = await _auth.signInWithCustomToken(customToken);
      return userCredential;
      
    } on FirebaseFunctionsException catch (e) {
      // 같은 이메일로 다른 방법(구글·애플 등)으로 가입한 계정이 있다.
      // 다른 실패와 달리 다시 해도 같으니 안내 문구를 화면까지 올린다.
      if (e.code == 'already-exists') {
        AppLogger.w('[SSO][Naver] 이메일이 다른 계정에 있음');
        throw NaverEmailInUseException(
            e.message ?? '이미 다른 방법으로 가입한 이메일이에요. 처음 가입한 방법으로 로그인해 주세요.');
      }
      AppLogger.e('[SSO][Naver] 로그인 실패', error: e);
      return null;
    } catch (e) {
      AppLogger.e('[SSO][Naver] 로그인 실패', error: e);
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await FlutterNaverLogin.logOut();
    } catch (e) {
      AppLogger.w('[SSO][Naver] 로그아웃 실패: $e');
    }
  }
}
