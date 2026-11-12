// lib/services/auth_repository.dart (지금은 한 파일 안에 두고, 나중에 분리해도 됨)

// firebase_auth accessed via FirebaseAuthService
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/data/local/prefs/user_prefs.dart';
import 'package:parrokit/data/models/user.dart';
import 'package:parrokit/core/infrastructure/services/firebase/firebase_auth_service.dart';
import 'package:parrokit/core/infrastructure/services/firebase/firebase_user_service.dart';
import 'package:parrokit/core/infrastructure/services/sso/apple_sso_service.dart';
import 'package:parrokit/core/infrastructure/services/sso/google_sso_service.dart';
import 'package:parrokit/core/infrastructure/services/sso/kakao_sso_service.dart';
import 'package:parrokit/core/infrastructure/services/sso/naver_sso_service.dart';

/// 앱 도메인 기준의 인증/유저 레포지토리.
///
/// 책임:
/// - FirebaseAuthService 를 이용해 이메일 회원가입/로그인 수행
/// - UserPrefs 를 통해 로컬에 AppUser 저장/로드
/// - 코인/게스트 유저/이메일 인증 상태 등 **앱에서 쓰는 유저 상태 관리**
class UserRepository {
  final UserPrefs _userPrefs;
  final FirebaseAuthService _authService;
  final FirebaseUserService _firebaseUserService;
  final GoogleSsoService _googleSsoService;
  final KakaoSsoService _kakaoSsoService;
  final NaverSsoService _naverSsoService;
  final AppleSsoService _appleSsoService;
  
  UserRepository(
    this._userPrefs,
    this._authService,
    this._firebaseUserService, {
    GoogleSsoService? googleSsoService,
    KakaoSsoService? kakaoSsoService,
    NaverSsoService? naverSsoService,
    AppleSsoService? appleSsoService,
  })  : _googleSsoService = googleSsoService ?? GoogleSsoService(),
        _kakaoSsoService = kakaoSsoService ?? KakaoSsoService(),
        _naverSsoService = naverSsoService ?? NaverSsoService(),
        _appleSsoService = appleSsoService ?? AppleSsoService();

  /// 현재 로컬에 저장된 유저를 반환합니다.
  /// 저장된 유저가 없으면 null을 반환합니다.
  /// 현재 로그인된 Firebase 유저 + Firestore 유저 문서를 기준으로
  /// 최신 AppUser 를 만들어서 반환합니다.
  /// - 로그인 안 되어 있으면 null
  /// - Firestore 문서가 없으면 최소한 Auth 정보 + 로컬 캐시로 구성
  Future<AppUser?> getCurrentUser() async {
    // 1. Firebase Auth 에 현재 로그인된 유저가 있는지 확인
    final fbUser = _authService.currentUser;
    if (fbUser == null) {
      // 로그인 자체가 안 되어 있으면 null
      return null;
    }

    // 2. Firestore 기준 유저 문서 조회 (timeout 시 로컬 캐시로 폴백)
    AppUser? serverUser;
    try {
      serverUser = await _firebaseUserService.loadUserDocument(uid: fbUser.uid);
    } catch (_) {
      serverUser = null;
    }

    // 3. 로컬 캐시(SharedPreferences)에 저장된 유저 (폴백용)
    final localUser = _userPrefs.loadUser();

    final unreadCount = serverUser?.unreadNotificationCount ??
        localUser?.unreadNotificationCount ??
        0;

    // 4. 최종적으로 앱에서 쓸 AppUser 조합
    final user = AppUser(
      id: fbUser.uid,
      displayName: fbUser.displayName ??
          serverUser?.displayName ??
          localUser?.displayName,
      email: fbUser.email ?? serverUser?.email ?? localUser?.email,
      photoUrl: fbUser.photoURL ?? serverUser?.photoUrl ?? localUser?.photoUrl,
      parrots: serverUser?.parrots ?? localUser?.parrots ?? 0,
      crackers: serverUser?.crackers ?? localUser?.crackers ?? 0,
      unreadNotificationCount: unreadCount,
      blockedUserIds:
          serverUser?.blockedUserIds ?? localUser?.blockedUserIds ?? const [],
      createdAt: serverUser?.createdAt ?? localUser?.createdAt,
      updatedAt: DateTime.now(),
      lastNicknameChangedAt: serverUser?.lastNicknameChangedAt ?? localUser?.lastNicknameChangedAt,
    );

    // 5. 최신 상태를 로컬에도 다시 캐싱
    await _userPrefs.saveUser(user);

    return user;
  }

  /// 특정 UID의 유저 정보를 단건으로 불러옵니다. (주로 다른 유저 프로필 조회용)
  Future<AppUser?> getUserById(String uid) async {
    try {
      return await _firebaseUserService.loadUserDocument(uid: uid);
    } catch (_) {
      return null;
    }
  }

  Stream<AppUser?> watchUserById(String uid) {
    return _firebaseUserService.watchUserDocument(uid: uid);
  }

  /// 이메일 + 비밀번호로 회원가입을 수행합니다.
  /// - Firebase Auth 에 사용자 생성
  /// - 생성된 사용자 정보를 기반으로 AppUser 생성
  /// - 로컬(UserPrefs)에 저장
  /// - 필요시 이메일 인증 메일 발송
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    bool sendEmailVerification = true,
  }) async {
    final cred = await _authService.signUpWithEmail(
      email: email,
      password: password,
    );

    final fbUser = cred.user;
    if (fbUser == null) {
      throw StateError('FirebaseAuth: user is null after signUp');
    }

    await _firebaseUserService.initUserDocument(
      uid: fbUser.uid,
      email: fbUser.email ?? email,
    );

    if (sendEmailVerification && !fbUser.emailVerified) {
      await fbUser.sendEmailVerification();
    }

    final now = DateTime.now();
    final user = AppUser(
      id: fbUser.uid,
      displayName: fbUser.displayName,
      email: fbUser.email,
      parrots: 0,
      crackers: 0,
      unreadNotificationCount: 0,
      createdAt: now,
      updatedAt: now,
    );

    await _userPrefs.saveUser(user);
    return user;
  }

  /// 이메일 + 비밀번호로 로그인합니다.
  /// - Firebase Auth 에 로그인 요청
  /// - 로그인된 Firebase User 로부터 AppUser 를 구성
  /// - 로컬(UserPrefs)에 저장
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _authService.signInWithEmail(
      email: email,
      password: password,
    );

    final fbUser = cred.user;
    if (fbUser == null) {
      throw StateError('FirebaseAuth: user is null after signIn');
    }

    // 1) 서버(Firestore) 기준으로 유저 문서를 먼저 조회
    // FirebaseUserService 쪽에 uid로 유저 문서를 로드하는 메서드가 있다고 가정합니다.
    // 예: Future<AppUser?> loadUserDocument({required String uid});
    var serverUser =
        await _firebaseUserService.loadUserDocument(uid: fbUser.uid);

    if (serverUser == null) {
      await _firebaseUserService.initUserDocument(
        uid: fbUser.uid,
        email: fbUser.email ?? email,
      );
      serverUser = await _firebaseUserService.loadUserDocument(uid: fbUser.uid);
    }

    // 2) 로컬에 저장된 유저는 캐시/폴백 용도로만 사용
    final existingLocal = _userPrefs.loadUser();
    final unreadCount = serverUser?.unreadNotificationCount ??
        existingLocal?.unreadNotificationCount ??
        0;

    final user = AppUser(
      id: fbUser.uid,
      displayName: fbUser.displayName ??
          serverUser?.displayName ??
          existingLocal?.displayName,
      email: fbUser.email ?? serverUser?.email ?? existingLocal?.email,
      photoUrl:
          fbUser.photoURL ?? serverUser?.photoUrl ?? existingLocal?.photoUrl,
      parrots: serverUser?.parrots ?? existingLocal?.parrots ?? 0,
      crackers: serverUser?.crackers ?? existingLocal?.crackers ?? 0,
      unreadNotificationCount: unreadCount,
      blockedUserIds:
          serverUser?.blockedUserIds ?? existingLocal?.blockedUserIds ?? const [],
      createdAt: serverUser?.createdAt ?? existingLocal?.createdAt,
      updatedAt: DateTime.now(),
    );

    await _userPrefs.saveUser(user);
    return user;
  }

  /// Google 계정으로 로그인 (또는 회원가입)을 수행합니다.
  Future<AppUser?> signInWithGoogle() async {
    // 1. Google OAuth 인증 얻기
    final googleCred = await _googleSsoService.getCredential();
    if (googleCred == null) {
      // 사용자가 취소함
      return null;
    }

    // 2. 파이어베이스에 해당 정보로 로그인
    final cred = await _authService.signInWithCredential(googleCred);

    final fbUser = cred.user;
    if (fbUser == null) {
      throw StateError('FirebaseAuth: user is null after signInWithGoogle');
    }

    // 3) 서버(Firestore) 기준으로 유저 문서를 먼저 조회
    AppUser? serverUser;
    try {
      serverUser = await _firebaseUserService.loadUserDocument(uid: fbUser.uid);
    } catch (_) {
      serverUser = null;
    }

    // 문서가 없으면 초기화 (회원가입의 경우)
    if (serverUser == null) {
      await _firebaseUserService.initUserDocument(
        uid: fbUser.uid,
        email: fbUser.email ?? '',
      );
    }

    // 4) 로컬 캐시 조회
    final existingLocal = _userPrefs.loadUser();
    final unreadCount = serverUser?.unreadNotificationCount ??
        existingLocal?.unreadNotificationCount ??
        0;

    final user = AppUser(
      id: fbUser.uid,
      displayName: fbUser.displayName ??
          serverUser?.displayName ??
          existingLocal?.displayName,
      email: fbUser.email ?? serverUser?.email ?? existingLocal?.email ?? '',
      photoUrl:
          fbUser.photoURL ?? serverUser?.photoUrl ?? existingLocal?.photoUrl,
      parrots: serverUser?.parrots ?? existingLocal?.parrots ?? 0,
      crackers: serverUser?.crackers ?? existingLocal?.crackers ?? 0,
      unreadNotificationCount: unreadCount,
      blockedUserIds:
          serverUser?.blockedUserIds ?? existingLocal?.blockedUserIds ?? const [],
      createdAt: serverUser?.createdAt ?? existingLocal?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _userPrefs.saveUser(user);
    return user;
  }

  /// Kakao 계정으로 로그인 (또는 회원가입)을 수행합니다.
  Future<AppUser?> signInWithKakao() async {
    // 1. Kakao OAuth 인증 얻기
    final kakaoCred = await _kakaoSsoService.getCredential();
    if (kakaoCred == null) {
      // 사용자가 취소함
      return null;
    }

    // 2. 파이어베이스에 해당 정보로 로그인
    final cred = await _authService.signInWithCredential(kakaoCred);

    final fbUser = cred.user;
    if (fbUser == null) {
      throw StateError('FirebaseAuth: user is null after signInWithKakao');
    }

    // 3) 서버(Firestore) 기준으로 유저 문서를 먼저 조회
    AppUser? serverUser;
    try {
      serverUser = await _firebaseUserService.loadUserDocument(uid: fbUser.uid);
    } catch (_) {
      serverUser = null;
    }

    // 문서가 없으면 초기화 (회원가입의 경우)
    if (serverUser == null) {
      await _firebaseUserService.initUserDocument(
        uid: fbUser.uid,
        email: fbUser.email ?? '',
      );
    }

    // 4) 로컬 캐시 조회
    final existingLocal = _userPrefs.loadUser();
    final unreadCount = serverUser?.unreadNotificationCount ??
        existingLocal?.unreadNotificationCount ??
        0;

    final user = AppUser(
      id: fbUser.uid,
      displayName: fbUser.displayName ??
          serverUser?.displayName ??
          existingLocal?.displayName,
      email: fbUser.email ?? serverUser?.email ?? existingLocal?.email ?? '',
      photoUrl:
          fbUser.photoURL ?? serverUser?.photoUrl ?? existingLocal?.photoUrl,
      parrots: serverUser?.parrots ?? existingLocal?.parrots ?? 0,
      crackers: serverUser?.crackers ?? existingLocal?.crackers ?? 0,
      unreadNotificationCount: unreadCount,
      blockedUserIds:
          serverUser?.blockedUserIds ?? existingLocal?.blockedUserIds ?? const [],
      createdAt: serverUser?.createdAt ?? existingLocal?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _userPrefs.saveUser(user);
    return user;
  }

  /// Naver 계정으로 로그인 (또는 회원가입)을 수행합니다.
  Future<AppUser?> signInWithNaver() async {
    // 1. Naver OAuth 인증 + Cloud Functions 호출하여 Firebase 로그인
    final cred = await _naverSsoService.getCredentialAndSignIn();
    if (cred == null) {
      // 사용자가 취소하거나 에러 발생
      return null;
    }

    final fbUser = cred.user;
    if (fbUser == null) {
      throw StateError('FirebaseAuth: user is null after signInWithNaver');
    }

    // 2) 서버(Firestore) 기준으로 유저 문서를 먼저 조회
    AppUser? serverUser;
    try {
      serverUser = await _firebaseUserService.loadUserDocument(uid: fbUser.uid);
    } catch (_) {
      serverUser = null;
    }

    // 문서가 없으면 초기화 (회원가입의 경우)
    if (serverUser == null) {
      await _firebaseUserService.initUserDocument(
        uid: fbUser.uid,
        email: fbUser.email ?? '',
      );
    }

    // 3) 로컬 캐시 조회
    final existingLocal = _userPrefs.loadUser();
    final unreadCount = serverUser?.unreadNotificationCount ??
        existingLocal?.unreadNotificationCount ??
        0;

    final user = AppUser(
      id: fbUser.uid,
      displayName: fbUser.displayName ??
          serverUser?.displayName ??
          existingLocal?.displayName,
      email: fbUser.email ?? serverUser?.email ?? existingLocal?.email ?? '',
      photoUrl:
          fbUser.photoURL ?? serverUser?.photoUrl ?? existingLocal?.photoUrl,
      parrots: serverUser?.parrots ?? existingLocal?.parrots ?? 0,
      crackers: serverUser?.crackers ?? existingLocal?.crackers ?? 0,
      unreadNotificationCount: unreadCount,
      blockedUserIds:
          serverUser?.blockedUserIds ?? existingLocal?.blockedUserIds ?? const [],
      createdAt: serverUser?.createdAt ?? existingLocal?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _userPrefs.saveUser(user);
    return user;
  }

  /// 비밀번호 재설정 이메일을 전송합니다.
  Future<void> sendPasswordResetEmail(String email) async {
    await _authService.sendPasswordResetEmail(email);
  }

  /// 현재 로그인된 Firebase 유저 기준으로 이메일 인증 여부를 반환합니다.
  Future<bool> isEmailVerified() async {
    final fbUser = _authService.currentUser;
    return fbUser?.emailVerified ?? false;
  }

  /// 현재 로그인된 Firebase 유저에게 이메일 인증 메일을 다시 보냅니다.
  Future<void> sendEmailVerification() async {
    await _authService.reloadCurrentUser();
    final fbUser = _authService.currentUser;

    if (fbUser != null && !fbUser.emailVerified) {
      await fbUser.sendEmailVerification();
    }
  }

  /// Firebase 에서 현재 유저 정보를 새로고침하고,
  /// 그 결과를 기반으로 AppUser 를 갱신합니다.
  /// (예: 이메일 인증을 완료하고 앱으로 돌아온 경우)
  Future<AppUser?> reloadFirebaseUser() async {
    final fbUser = _authService.currentUser;
    if (fbUser == null) {
      return null;
    }

    await _authService.reloadCurrentUser();
    final refreshed = _authService.currentUser;
    if (refreshed == null) {
      return null;
    }

    // 서버의 유저 문서를 먼저 조회해서 parrots 등을 동기화
    final serverUser =
        await _firebaseUserService.loadUserDocument(uid: refreshed.uid);

    final existingLocal = _userPrefs.loadUser();
    final unreadCount = serverUser?.unreadNotificationCount ??
        existingLocal?.unreadNotificationCount ??
        0;
    final user = AppUser(
      id: refreshed.uid,
      displayName: refreshed.displayName ??
          serverUser?.displayName ??
          existingLocal?.displayName,
      email: refreshed.email ?? serverUser?.email ?? existingLocal?.email,
      photoUrl:
          refreshed.photoURL ?? serverUser?.photoUrl ?? existingLocal?.photoUrl,
      parrots: serverUser?.parrots ?? existingLocal?.parrots ?? 0,
      crackers: serverUser?.crackers ?? existingLocal?.crackers ?? 0,
      unreadNotificationCount: unreadCount,
      blockedUserIds:
          serverUser?.blockedUserIds ?? existingLocal?.blockedUserIds ?? const [],
      createdAt: serverUser?.createdAt ?? existingLocal?.createdAt,
      updatedAt: DateTime.now(),
    );

    await _userPrefs.saveUser(user);
    return user;
  }


  /// 유저 정보를 저장(업데이트)합니다.
  /// 예: 서버에서 프로필/코인 값을 받아온 경우 등에 사용.
  Future<void> saveUser(AppUser user) async {
    final updated = user.copyWith(updatedAt: DateTime.now());
    await _userPrefs.saveUser(updated);
  }

  /// 코인을 delta 만큼 증감시키고, 갱신된 유저를 반환합니다.
  /// - delta는 음수도 허용됩니다.
  /// - 유저가 없으면 null을 반환합니다.
  Future<AppUser?> addCoins(int delta) async {
    final current = _userPrefs.loadUser();
    if (current == null) {
      return null;
    }

    // 서버 값 기준으로 바꾸고, 서버가 돌려준 값으로 캐시를 맞춘다. 전에는
    // 캐시 값을 먼저 바꿔 저장한 뒤 그 패롯·크래커를 서버에 통째로 썼다.
    // 그러면 캐시가 옛 값일 때 서버에서 생긴 크래커 변화가 지워졌고, 서버
    // 쓰기가 실패해도 캐시에는 바뀐 값이 남았다.
    final balances = await _firebaseUserService.addParrots(
      uid: current.id,
      delta: delta,
    );
    final updated = current.copyWith(
      parrots: balances.parrots,
      crackers: balances.crackers,
      updatedAt: DateTime.now(),
    );
    await _userPrefs.saveUser(updated);

    return updated;
  }

  /// 프로필 이미지를 업데이트합니다.
  /// - Firebase Auth 업데이트 (updatePhotoURL)
  /// - Firestore 업데이트 (photoUrl 필드)
  /// - 로컬 캐시 업데이트
  Future<void> updatePhotoUrl(String? photoUrl) async {
    // 1. Firebase Auth 업데이트
    await _authService.updatePhotoUrl(photoUrl);

    // 2. Firestore 업데이트
    final user = _authService.currentUser;
    if (user != null) {
      await _firebaseUserService.updateUserPhoto(
        uid: user.uid,
        photoUrl: photoUrl,
      );
    }

    // 3. 로컬 캐시 업데이트
    // getCurrentUser()는 Firebase 인증 유저만 반환하므로,
    // 게스트 유저(로컬 전용)인 경우 _userPrefs.loadUser()로 조회해야 함.
    final current = await getCurrentUser() ?? _userPrefs.loadUser();
    if (current != null) {
      final updated = current.copyWith(
        photoUrl: photoUrl,
        clearPhotoUrl: photoUrl == null,
        updatedAt: DateTime.now(),
      );
      await _userPrefs.saveUser(updated);
    }
  }

  /// 패롯과 크래커를 교환합니다.
  Future<void> exchangeCurrency({
    required int amountToDeduct,
    required int amountToAdd,
    required bool isParrotsToCrackers,
  }) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');

    // 받을 양은 서버가 환율로 정한다. amountToAdd는 화면 표시용이다.
    final balance = await _firebaseUserService.exchangeCurrency(
      amount: amountToDeduct,
      isParrotsToCrackers: isParrotsToCrackers,
    );
    final current = _userPrefs.loadUser();
    if (current != null) {
      await _userPrefs.saveUser(current.copyWith(
        parrots: balance.parrots,
        crackers: balance.crackers,
      ));
    }
  }

  /// 닉네임(DisplayName)을 업데이트합니다.
  Future<void> updateDisplayName(String? displayName) async {
    // 1. Firebase Auth 업데이트
    await _authService.updateDisplayName(displayName);

    final current = await getCurrentUser() ?? _userPrefs.loadUser();

    // 2. Firestore 업데이트 (닉네임 중복 레지스트리 반영)
    final user = _authService.currentUser;
    if (user != null) {
      await _firebaseUserService.updateUserDisplayName(
        uid: user.uid,
        newNickname: displayName,
        oldNickname: current?.displayName,
      );
    }

    // 3. 로컬 캐시 업데이트
    if (current != null) {
      final updated = current.copyWith(
        displayName: displayName,
        clearDisplayName: displayName == null,
        updatedAt: DateTime.now(),
        lastNicknameChangedAt: DateTime.now(),
      );
      await _userPrefs.saveUser(updated);
    }
  }

  /// 닉네임 중복 여부를 확인합니다.
  Future<bool> isNicknameAvailable(String nickname) async {
    return _firebaseUserService.isNicknameAvailable(nickname);
  }

  /// 로그아웃/유저 초기화.
  /// - Kakao SDK 에서 로그아웃
  /// - Google SDK 에서 로그아웃
  /// - Firebase 에서 로그아웃
  /// - 로컬에 저장된 유저 정보를 모두 삭제합니다.
  Future<void> signOut() async {
    // 네 곳 모두 하나가 실패해도 나머지를 계속 진행한다. 로그아웃은 사용자가
    // 나가겠다는 것이라, 어느 공급자 하나 때문에 막히면 안 된다. 다만 전에는
    // 전부 빈 catch여서 무엇이 실패했는지 흔적이 없었다.
    //
    // 특히 _authService(Firebase)가 실패하면 로컬은 비워지는데 Firebase 세션은
    // 남는다. 그래도 비우는 쪽이 맞지만, 그 일이 일어났다는 건 남겨야 한다.
    await _signOutQuietly('naver', _naverSsoService.signOut);
    await _signOutQuietly('kakao', _kakaoSsoService.signOut);
    await _signOutQuietly('google', _googleSsoService.signOut);
    await _signOutQuietly('firebase', _authService.signOut);

    await _userPrefs.clear();
  }

  Future<void> _signOutQuietly(
      String provider, Future<void> Function() signOut) async {
    try {
      await signOut();
    } catch (e) {
      AppLogger.w('[UserRepository] 로그아웃 실패 provider=$provider: $e');
    }
  }

  /// 회원탈퇴.
  /// - Firestore 유저 문서 삭제
  /// - Firebase Auth 계정 삭제
  /// - 로컬 캐시 삭제
  Future<void> deleteAccount() async {
    final uid = _authService.currentUser?.uid;
    final nickname = _userPrefs.loadUser()?.displayName;

    if (uid != null) {
      await _firebaseUserService.deleteUserDocument(uid: uid);
    }

    // Auth 계정 삭제가 먼저다. 여기서 던지면(흔한 건 requires-recent-login)
    // 아래로 내려가지 않으므로 닉네임 선점은 그대로 남는다. 계정이 살아 있는데
    // 닉네임만 빼앗기는 일은 생기지 않는다.
    await _authService.deleteAccount();

    if (uid != null) {
      try {
        await _firebaseUserService.releaseNickname(uid: uid, nickname: nickname);
      } catch (e) {
        // 여기서 실패해도 탈퇴 자체는 끝났다. 닉네임만 남는다.
        AppLogger.w('[UserRepository] 닉네임 선점 해제 실패 nickname=$nickname: $e');
      }
    }

    await _userPrefs.clear();
  }

  /// Apple SSO 로그인 연동
  Future<AppUser?> signInWithApple() async {
    final cred = await _appleSsoService.getCredentialAndSignIn();
    if (cred == null) {
      return null;
    }

    final fbUser = cred.user;
    if (fbUser == null) {
      throw StateError('FirebaseAuth: user is null after signInWithApple');
    }

    AppUser? serverUser;
    try {
      serverUser = await _firebaseUserService.loadUserDocument(uid: fbUser.uid);
    } catch (_) {
      serverUser = null;
    }

    if (serverUser == null) {
      await _firebaseUserService.initUserDocument(
        uid: fbUser.uid,
        email: fbUser.email ?? '',
      );
    }

    final existingLocal = _userPrefs.loadUser();
    final unreadCount = serverUser?.unreadNotificationCount ??
        existingLocal?.unreadNotificationCount ??
        0;

    final user = AppUser(
      id: fbUser.uid,
      displayName: fbUser.displayName ??
          serverUser?.displayName ??
          existingLocal?.displayName,
      email: fbUser.email ?? serverUser?.email ?? existingLocal?.email ?? '',
      photoUrl:
          fbUser.photoURL ?? serverUser?.photoUrl ?? existingLocal?.photoUrl,
      // 다른 로그인 경로와 같이 0에서 시작한다. 전에는 Apple만 20·1000이라,
      // 서버 문서는 0인데 첫 화면에 없는 패롯·크래커가 보였다.
      parrots: serverUser?.parrots ?? existingLocal?.parrots ?? 0,
      crackers: serverUser?.crackers ?? existingLocal?.crackers ?? 0,
      unreadNotificationCount: unreadCount,
      blockedUserIds:
          serverUser?.blockedUserIds ?? existingLocal?.blockedUserIds ?? const [],
      createdAt: serverUser?.createdAt ?? existingLocal?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _userPrefs.saveUser(user);
    return user;
  }
}
