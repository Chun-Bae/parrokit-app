// lib/services/auth_repository.dart (지금은 한 파일 안에 두고, 나중에 분리해도 됨)

import 'package:firebase_auth/firebase_auth.dart' as fb;

/// FirebaseAuth 를 얇게 감싼 서비스.
/// - 외부 SDK 호출(FirebaseAuth.instance.*)만 담당.
/// - AppUser, UserPrefs 같은 앱 도메인에는 관여하지 않음.
class FirebaseAuthService {
  final fb.FirebaseAuth _auth;

  FirebaseAuthService({fb.FirebaseAuth? auth})
      : _auth = auth ?? fb.FirebaseAuth.instance;

  Future<fb.UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<fb.UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// 제공된 OAuth 인증 정보를 사용하여 Firebase 에 로그인합니다. (Google, Apple 등)
  Future<fb.UserCredential> signInWithCredential(
      fb.OAuthCredential credential) {
    return _auth.signInWithCredential(credential);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  fb.User? get currentUser => _auth.currentUser;

  Future<void> reloadCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
    }
  }

  Future<void> updatePhotoUrl(String? photoUrl) async {
    await _auth.currentUser?.updatePhotoURL(photoUrl);
  }

  Future<void> updateDisplayName(String? displayName) async {
    await _auth.currentUser?.updateDisplayName(displayName);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> deleteAccount() async {
    await _auth.currentUser?.delete();
  }
}
