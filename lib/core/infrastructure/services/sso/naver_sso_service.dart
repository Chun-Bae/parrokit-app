import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_naver_login/interface/types/naver_login_result.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';
import 'package:flutter_naver_login/interface/types/naver_token.dart';

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
