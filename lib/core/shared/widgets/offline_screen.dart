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
      home: Builder(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
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
          return const Scaffold();
        },
      ),
    );
  }
}
