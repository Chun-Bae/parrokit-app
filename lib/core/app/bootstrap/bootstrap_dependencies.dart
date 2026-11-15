import 'package:parrokit/core/state/provider/iap_provider.dart';
import 'package:parrokit/core/state/provider/theme_provider.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/core/infrastructure/repositories/user_repository.dart';
import 'package:parrokit/core/infrastructure/services/firebase/firebase_auth_service.dart';
import 'package:parrokit/core/infrastructure/services/firebase/firebase_user_service.dart';
import 'package:parrokit/data/local/prefs/user_prefs.dart';
import 'package:parrokit/features/collection/clip/shorts/data/shorts_ad_repository.dart';
import 'package:parrokit/features/collection/clip/shorts/presentation/providers/ad_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 테마 provider를 생성하고 저장된 테마를 로드한다.
Future<ThemeProvider> createThemeProvider() async {
  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();
  return themeProvider;
}

// 사용자 provider를 생성하고 초기 인증 상태를 복원한다.
Future<UserProvider> createUserProvider() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userProvider = UserProvider(
      UserRepository(
        UserPrefs(prefs),
        FirebaseAuthService(),
        FirebaseUserService(),
      ),
    );
    await userProvider.init();
    return userProvider;
  } catch (_) {
    return UserProvider(
      UserRepository(
        UserPrefs(null as dynamic),
        FirebaseAuthService(),
        FirebaseUserService(),
      ),
    );
  }
}

// IAP provider를 생성하고 결제 상태를 초기화한다.
Future<IapProvider> createIapProvider() async {
  final iapProvider = IapProvider();
  await iapProvider.init();
  return iapProvider;
}

// IAP 상태를 반영한 광고 provider를 생성한다.
AdProvider createAdProvider({required IapProvider iapProvider}) {
  final adRepository = ShortsAdRepository();
  return AdProvider(
    repository: adRepository,
    initialPremium: iapProvider.isPremium,
  );
}
