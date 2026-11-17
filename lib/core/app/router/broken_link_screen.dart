// 열 수 없는 링크로 들어왔을 때 보여 주는 화면(5차 440).
//
// 전에는 라우터가 'voteId가 필요합니다.'처럼 **개발자에게 하는 말**만 적힌
// 빈 화면을 띄웠다. 앱바도 단추도 없어서, 알림을 눌러 바로 들어온 경우처럼
// 뒤로 갈 곳이 없으면 거기서 멈춘다. 무엇이 잘못됐는지도 알 수 없다.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

class BrokenLinkScreen extends StatelessWidget {
  const BrokenLinkScreen({super.key});

  /// 로그로 남길 때 쓰는 말. 화면에는 보이지 않는다.
  static const String logTag = '[Router] broken-link';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_off_rounded,
                  size: 40, color: colors.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                brokenLinkMessage,
                textAlign: TextAlign.center,
                style: context.texts.bodyLarge,
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('broken-link-home'),
                onPressed: () => context.go('/'),
                child: const Text(brokenLinkHomeLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const String brokenLinkMessage = '열 수 없는 주소예요. 글이 지워졌거나 링크가 잘못됐을 수 있어요.';
const String brokenLinkHomeLabel = '홈으로 가기';
