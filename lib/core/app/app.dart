import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/core/state/provider/theme_provider.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/core/shared/theme/app_theme.dart';
import 'package:parrokit/core/shared/widgets/storage_transfer_overlay.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';

class App extends StatefulWidget {
  const App({super.key, required this.router});

  final GoRouter router;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final userProvider = context.watch<UserProvider>();
    final clipProvider = context.read<ClipProvider>();

    final uid =
        userProvider.isLoggedIn ? userProvider.currentUser?.id : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      clipProvider.syncRemoteClipsOnLogin(uid);
    });

    return MaterialApp.router(
      title: 'Parrokit',
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: theme.themeMode,
      routerConfig: widget.router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned.fill(child: child ?? const SizedBox.shrink()),
            const StorageTransferOverlay(),
          ],
        );
      },
    );
  }
}
