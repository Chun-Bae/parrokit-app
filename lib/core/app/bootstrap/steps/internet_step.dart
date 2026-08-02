import 'package:flutter/material.dart';
import 'package:parrokit/core/state/provider/theme_provider.dart';
import 'package:parrokit/core/shared/utils/has_internet.dart';
import 'package:parrokit/core/shared/widgets/offline_screen.dart';
import 'package:provider/provider.dart';

// 인터넷이 없으면 오프라인 화면을 먼저 표시한다.
Future<void> ensureInternetOrShowOffline(ThemeProvider themeProvider) async {
  if (!await hasInternet()) {
    runApp(
      ChangeNotifierProvider.value(
        value: themeProvider,
        child: const OfflineScreen(),
      ),
    );
  }
}
