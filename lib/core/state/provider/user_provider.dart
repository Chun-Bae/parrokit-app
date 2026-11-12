// lib/provider/user_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:parrokit/data/models/user.dart';
import 'package:parrokit/core/infrastructure/repositories/user_repository.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';

/// 앱 전역에서 사용하는 "현재 유저" 상태를 관리하는 Provider.
///
/// 역할:
/// - 앱 시작 시 로컬(UserPrefs)에서 유저를 복원하거나, 없으면 게스트 유저 생성
/// - 현재 유저(AppUser)와 코인 값을 UI에 노출
/// - 코인 증감, 로그아웃 등의 액션을 AuthService를 통해 위임
///
/// 현재는 외부 인증/서버 연동 없이 로컬 전용 동작만 하지만,
/// 나중에 Firebase/Auth 서버를 붙이더라도 이 클래스의 public API는
/// 최대한 그대로 유지하는 것을 목표로 합니다.
class UserProvider extends ChangeNotifier {
  final UserRepository _userRepository;

  AppUser? _currentUser;
  bool _isLoading = false;
  StreamSubscription<AppUser?>? _userSubscription;
  String? _watchedUserId;

  /// 라우터 새로고침 전용 Notifier (로그인 상태, 온보딩 상태 변경 시에만 호출)
  final ChangeNotifier routerRefreshNotifier = ChangeNotifier();
  
  // 라우팅 상태 캐싱용 변수
  bool _lastIsLoggedIn = false;
  bool _lastHasNickname = false;

  UserProvider(this._userRepository);

  /// 현재 로그인된 유저(없을 수도 있음)
  AppUser? get currentUser => _currentUser;

  /// 유저 정보를 로딩 중인지 여부
  bool get isLoading => _isLoading;

  /// "로그인된 상태"라고 볼 수 있는지 여부
  /// 게스트 유저(이메일이 없는 경우)는 false 로 처리합니다.
  bool get isLoggedIn => _currentUser?.email != null;

  /// 현재 코인 수 (유저가 없으면 0)
  int get coins => _currentUser?.coins ?? 0;

  /// 현재 차단한 유저 ID 목록
  List<String> get blockedUserIds => _currentUser?.blockedUserIds ?? const [];

  /// 읽지 않은 알림 수
  int get unreadNotificationCount => _currentUser?.unreadNotificationCount ?? 0;

  /// 앱 시작 시 혹은 필요한 시점에 호출해서
  /// - 저장된 유저를 불러오거나
  /// - 없으면 게스트 유저를 생성합니다.
  Future<void> init() async {
    _setLoading(true);

    try {
      _currentUser = await _userRepository.getCurrentUser();
      _startUserSubscription();
      _checkAndNotifyRouter();
    } finally {
      _setLoading(false);
    }
  }

  /// 내부적으로 라우팅에 영향을 주는 상태가 바뀌었는지 확인하고 알림
  void _checkAndNotifyRouter() {
    final currentIsLoggedIn = isLoggedIn;
    final currentHasNickname = _currentUser?.displayName != null && 
        _currentUser!.displayName!.isNotEmpty;
        
    if (_lastIsLoggedIn != currentIsLoggedIn || _lastHasNickname != currentHasNickname) {
      _lastIsLoggedIn = currentIsLoggedIn;
      _lastHasNickname = currentHasNickname;
      // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
      routerRefreshNotifier.notifyListeners();
    }
  }

  /// 코인을 delta 만큼 증감시키고, 변경 사항을 UI에 반영합니다.
  /// - delta는 음수도 허용됩니다.
  Future<void> addCoins(int delta) async {
    if (_currentUser == null) return;

    final updated = await _userRepository.addCoins(delta);
    if (updated != null) {
      _currentUser = updated;
      notifyListeners();
      _checkAndNotifyRouter();
    }
  }

  /// 유저 정보를 외부(서버, 프로필 편집 화면 등)에서 갱신했을 때 호출합니다.
  Future<void> updateUser(AppUser user) async {
    await _userRepository.saveUser(user);
    _currentUser = user;
    _startUserSubscription();
    notifyListeners();
    _checkAndNotifyRouter();
  }

  /// 이메일 + 비밀번호 회원가입 래핑
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? nickname,
    bool sendEmailVerification = true,
  }) async {
    _setLoading(true);
    try {
      final user = await _userRepository.signUpWithEmail(
        email: email,
        password: password,
        sendEmailVerification: sendEmailVerification,
      );
      
      // 회원가입 직후 닉네임 설정이 있다면 연달아 세팅
      if (nickname != null && nickname.isNotEmpty) {
        await _userRepository.updateDisplayName(nickname);
      }
      
      // 최신 상태 다시 불러오기
      final updatedUser = await _userRepository.getCurrentUser();
      if (updatedUser != null) {
        _currentUser = updatedUser;
      } else {
        _currentUser = user;
      }
      _startUserSubscription();

      unawaited(Purchases.logIn(_currentUser!.id));
      notifyListeners();
      _checkAndNotifyRouter();
    } finally {
      _setLoading(false);
    }
  }

  /// 이메일 + 비밀번호 로그인 래핑
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final user = await _userRepository.signInWithEmail(
        email: email,
        password: password,
      );
      _currentUser = user;
      _startUserSubscription();
      unawaited(Purchases.logIn(user.id));
      notifyListeners();
      _checkAndNotifyRouter();
    } finally {
      _setLoading(false);
    }
  }

  /// Google 로그인 래핑
  Future<void> signInWithGoogle() async {
    _setLoading(true);
    try {
      final user = await _userRepository.signInWithGoogle();
      if (user != null) {
        _currentUser = user;
        _startUserSubscription();
        unawaited(Purchases.logIn(user.id));
        notifyListeners();
        _checkAndNotifyRouter();
      }
    } finally {
      _setLoading(false);
    }
  }

  /// Kakao 로그인 래핑
  Future<void> signInWithKakao() async {
    _setLoading(true);
    try {
      final user = await _userRepository.signInWithKakao();
      if (user != null) {
        _currentUser = user;
        _startUserSubscription();
        unawaited(Purchases.logIn(user.id));
        notifyListeners();
      }
    } finally {
      _setLoading(false);
    }
  }

  /// Naver 계정으로 로그인 (또는 회원가입)을 수행합니다.
  Future<void> signInWithNaver() async {
    _setLoading(true);
    try {
      final user = await _userRepository.signInWithNaver();
      if (user != null) {
        _currentUser = user;
        _startUserSubscription();
        unawaited(Purchases.logIn(user.id));
        _checkAndNotifyRouter();
        notifyListeners();
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signInWithApple() async {
    _setLoading(true);
    try {
      final user = await _userRepository.signInWithApple();
      if (user != null) {
        _currentUser = user;
        _startUserSubscription();
        unawaited(Purchases.logIn(user.id));
        _checkAndNotifyRouter();
        notifyListeners();
      }
    } finally {
      _setLoading(false);
    }
  }

  /// 비밀번호 재설정 이메일 전송
  Future<void> sendPasswordResetEmail(String email) async {
    await _userRepository.sendPasswordResetEmail(email);
  }

  /// 이메일 인증 여부 반환
  Future<bool> isEmailVerified() async {
    return await _userRepository.isEmailVerified();
  }

  /// 이메일 인증 메일 재발송
  Future<void> sendEmailVerification() async {
    await _userRepository.sendEmailVerification();
  }

  /// Firebase 유저 정보 새로고침 (주로 이메일 인증 직후 사용)
  Future<void> reloadFirebaseUser() async {
    _setLoading(true);
    try {
      final refreshed = await _userRepository.reloadFirebaseUser();
      if (refreshed != null) {
        _currentUser = refreshed;
        _startUserSubscription();
        notifyListeners();
        _checkAndNotifyRouter();
      }
    } finally {
      _setLoading(false);
    }
  }

  /// 프로필 아바타(사진) URL 업데이트
  Future<void> updatePhotoUrl(String? photoUrl) async {
    AppLogger.d('[UserProvider] updatePhotoUrl requested: $photoUrl');

    // 1. Optimistic Update (즉시 UI 반영)
    if (_currentUser != null) {
      AppLogger.d('[UserProvider] Applying optimistic update');
      _currentUser = _currentUser!.copyWith(
        photoUrl: photoUrl,
        clearPhotoUrl: photoUrl == null,
      );
      notifyListeners();
      _checkAndNotifyRouter();
    }

    _setLoading(true);
    try {
      await _userRepository.updatePhotoUrl(photoUrl);
      AppLogger.d('[UserProvider] Repository update complete');

      // ⚠️ 주의: reloadFirebaseUser()를 바로 호출하면
      // Firestore의 Eventual Consistency로 인해 아직 갱신되지 않은 과거 데이터를
      // 받아와서 UI가 롤백되는 현상이 발생할 수 있음.
      // 이미 로컬 state와 repo/storage를 갱신했으므로 재조회 불필요.
      // await reloadFirebaseUser();
    } catch (e) {
      AppLogger.d('[UserProvider] Update failed, error: $e');
      // 에러 발생 시 롤백 로직이 필요할 수 있으나, 일단 로그만 출력
    } finally {
      _setLoading(false);
    }
  }

  /// 패롯과 크래커 상호 환전
  Future<void> exchangeCurrency({
    required int amountToDeduct,
    required int amountToAdd,
    required bool isParrotsToCrackers,
  }) async {
    if (_currentUser == null) return;
    
    // 1. Optimistic Update (화면에 남은 돈/받은 돈 즉시 반영)
    int newParrots = _currentUser!.parrots;
    int newCrackers = _currentUser!.crackers;
    
    if (isParrotsToCrackers) {
      newParrots -= amountToDeduct;
      newCrackers += amountToAdd;
    } else {
      newCrackers -= amountToDeduct;
      newParrots += amountToAdd;
    }
    
    _currentUser = _currentUser!.copyWith(
      parrots: newParrots,
      crackers: newCrackers,
    );
    notifyListeners();

    _setLoading(true);
    try {
      await _userRepository.exchangeCurrency(
        amountToDeduct: amountToDeduct,
        amountToAdd: amountToAdd,
        isParrotsToCrackers: isParrotsToCrackers,
      );
    } catch (e) {
      // 롤백 (실패 시 데이터베이스에서 유저 정보를 다시 가져와 복구)
      AppLogger.e('[UserProvider] 환전 실패', error: e);
      await reloadFirebaseUser();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// 닉네임(DisplayName) 업데이트
  Future<void> updateDisplayName(String? displayName) async {
    AppLogger.d('[UserProvider] updateDisplayName requested: $displayName');

    // 1. Optimistic Update
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        displayName: displayName,
        clearDisplayName: displayName == null,
      );
      notifyListeners();
      _checkAndNotifyRouter();
    }

    _setLoading(true);
    try {
      await _userRepository.updateDisplayName(displayName);
    } catch (e) {
      AppLogger.d('[UserProvider] Update failed, error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 닉네임 중복 여부를 확인합니다.
  Future<bool> isNicknameAvailable(String nickname) async {
    return await _userRepository.isNicknameAvailable(nickname);
  }

  /// 회원탈퇴.
  /// Firestore 문서, Firebase Auth 계정, 로컬 캐시를 모두 삭제합니다.
  Future<void> deleteAccount() async {
    _setLoading(true);
    try {
      await _userRepository.deleteAccount();
      _logOutPurchasesInBackground();
      _currentUser = null;
      _stopUserSubscription();
      _checkAndNotifyRouter();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// 로그아웃/초기화.
  /// 로컬 저장소를 비우고 메모리에 있는 유저도 제거합니다.
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _userRepository.signOut();
      _logOutPurchasesInBackground();
      _currentUser = null;
      _stopUserSubscription();
      _checkAndNotifyRouter();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// RevenueCat 로그아웃.
  ///
  /// 결제 쪽이 느리거나 막혀도 앱 로그아웃·탈퇴가 기다리게 하지 않으려고
  /// 일부러 await 하지 않는다. 다만 전에는 빈 catch로 삼켜서, 실패해서
  /// 결제 신원이 남아 있어도 알 수가 없었다.
  void _logOutPurchasesInBackground() {
    unawaited(() async {
      try {
        await Purchases.logOut();
      } catch (e) {
        AppLogger.w('[UserProvider] Purchases.logOut 실패: $e');
      }
    }());
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void _startUserSubscription() {
    final userId = _currentUser?.id;
    if (userId == null || userId.isEmpty) {
      _stopUserSubscription();
      return;
    }

    if (_watchedUserId == userId && _userSubscription != null) {
      return;
    }

    _stopUserSubscription();
    _watchedUserId = userId;

    _userSubscription = _userRepository.watchUserById(userId).listen(
      (user) {
        if (user == null) return;
        _currentUser = _currentUser == null ? user : _currentUser!.copyWith(
          displayName: user.displayName,
          email: user.email,
          photoUrl: user.photoUrl,
          parrots: user.parrots,
          crackers: user.crackers,
          unreadNotificationCount: user.unreadNotificationCount,
          blockedUserIds: user.blockedUserIds,
          createdAt: user.createdAt,
          updatedAt: user.updatedAt,
          lastNicknameChangedAt: user.lastNicknameChangedAt,
        );
        notifyListeners();
      },
      onError: (error) {
        AppLogger.e('[UserProvider] user watch failed userId=$userId', error: error);
      },
    );
  }

  void _stopUserSubscription() {
    unawaited(_userSubscription?.cancel());
    _userSubscription = null;
    _watchedUserId = null;
  }

  @override
  void dispose() {
    _stopUserSubscription();
    // 라우터가 refreshListenable로 붙잡고 있는 Notifier도 같이 닫는다.
    routerRefreshNotifier.dispose();
    super.dispose();
  }
}
