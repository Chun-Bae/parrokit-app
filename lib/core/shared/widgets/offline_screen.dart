import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/state/provider/theme_provider.dart';
import 'package:parrokit/core/shared/theme/app_theme.dart';

class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: theme.themeMode,
      home: const _OfflineDialogHost(),
    );
  }
}

/// 안내 창을 한 번만 띄우기 위한 화면.
///
/// 전에는 [OfflineScreen.build] 안에서 addPostFrameCallback으로 바로 띄웠다.
/// 그런데 이 위젯은 ThemeProvider를 watch하고 있어서 테마가 바뀌면 build가
/// 다시 돌고, 그때마다 창이 하나씩 더 쌓였다. 화면 상태를 두고 initState에서
/// 한 번만 띄운다.
class _OfflineDialogHost extends StatefulWidget {
  const _OfflineDialogHost();

  @override
  State<_OfflineDialogHost> createState() => _OfflineDialogHostState();
}

class _OfflineDialogHostState extends State<_OfflineDialogHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('인터넷 연결 필요'),
          content: const Text('앱을 사용하려면 인터넷에 연결해 주세요.'),
          actions: [
            TextButton(
              onPressed: () => exit(0),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}
