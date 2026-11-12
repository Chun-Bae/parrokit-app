import 'package:flutter/material.dart';

import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:go_router/go_router.dart';

import 'package:parrokit/core/app/config/app_config.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

class LearningHubScreen extends StatefulWidget {
  const LearningHubScreen({super.key});

  @override
  State<LearningHubScreen> createState() => _LearningHubScreenState();
}

class _LearningHubScreenState extends State<LearningHubScreen> {
  int mode = 0;

  @override
  Widget build(BuildContext context) {
    final palette = HomeTokens.of(context);
    final background = palette.background;
    final surface = palette.surface;
    final ink = palette.ink;
    final muted = palette.muted;
    final accent = palette.accent;

    Widget destination(
        IconData icon, String title, String subtitle, String? path) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: ListTile(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.xl)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            leading: Icon(icon, color: path == null ? muted : ink),
            title: Text(title,
                style: TextStyle(color: ink, fontWeight: FontWeight.w700)),
            subtitle: Text(subtitle,
                style: context.texts.bodySmall.copyWith(color: muted)),
            trailing: path == null
                ? Text('준비 중',
                    style: context.texts.bodySmall.copyWith(color: muted))
                : Icon(Icons.arrow_forward_rounded, color: muted),
            onTap: path == null ? null : () => context.push(path),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text('학습 시작하기', style: TextStyle(color: ink)),
        backgroundColor: background,
        foregroundColor: ink,
        surfaceTintColor: background,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            24, 16, 24, MediaQuery.paddingOf(context).bottom + 120),
        children: [
          Text('오늘은 어떻게\n공부해볼까요?',
              style: context.texts.headlineLarge
                  .copyWith(color: ink, height: 1.3)),
          const SizedBox(height: 28),
          Text('학습 방법', style: context.texts.titleLarge.copyWith(color: ink)),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final cards = List.generate(2, (index) {
              final selected = mode == index;
              return Semantics(
                selected: selected,
                button: true,
                child: Material(
                  color: selected ? accent : surface,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    onTap: () => setState(() => mode = index),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(
                                  index == 0
                                      ? Icons.record_voice_over_rounded
                                      : Icons.headphones_rounded,
                                  color: selected ? palette.onAccent : ink,
                                  size: 30),
                              const Spacer(),
                              if (selected)
                                Icon(Icons.check_circle_rounded,
                                    color: palette.onAccent, size: 20),
                            ]),
                            const SizedBox(height: 20),
                            Text(index == 0 ? '따라 말하기' : '반복 듣기',
                                style: context.texts.titleLarge.copyWith(
                                    color: selected ? palette.onAccent : ink)),
                            const SizedBox(height: 6),
                            Text(
                                index == 0
                                    ? '듣고 내 목소리로\n소리 내어 연습해요'
                                    : '좋아하는 구간을\n여러 번 들어요',
                                style: context.texts.bodySmall.copyWith(
                                    // inkSoft는 브랜드가 파랑으로 바뀐 뒤 선택된
                                    // 파란 카드 위에서 거의 안 보였다
                                    color: selected
                                        ? palette.onAccent.withValues(alpha: 0.85)
                                        : muted,
                                    height: 1.6)),
                          ]),
                    ),
                  ),
                ),
              );
            });
            if (constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    cards[0],
                    const SizedBox(height: 12),
                    cards[1],
                  ]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
            ]);
          }),
          // 카드 아래에 있던 설명 문단(카드 설명과 겹치고 '준비 중' 안내가
          // 섞여 있었다)은 지웠다. 할 일은 아래 버튼 문구가 말해준다.
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push(AppRoutes.collectionPath),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: palette.onAccent,
              iconColor: palette.onAccent,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg)),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(mode == 0 ? '따라 말할 영상 고르기' : '반복해서 들을 영상 고르기',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 30),
          Text('공부할 영상 찾기',
              style: context.texts.titleLarge.copyWith(color: ink)),
          const SizedBox(height: 14),
          destination(Icons.swipe_up_rounded, '쇼츠로 발견하기',
              '짧은 영상을 넘기며 마음에 드는 표현 찾기', AppRoutes.explorePath),
          destination(Icons.video_library_outlined, '동영상별로 보기',
              '보관함에서 영상과 학습 클립 찾아보기', AppRoutes.collectionPath),
          // 눌러도 아무 일 없는 '준비 중' 줄은 새 디자인에서 숨긴다.
          ValueListenableBuilder<bool>(
            valueListenable: AppConfig.newDesignListenable,
            builder: (context, newDesign, _) => newDesign
                ? const SizedBox.shrink()
                : destination(Icons.people_outline_rounded, '함께 나눈 영상 보기',
                    '내가 공유하거나 다른 사람이 공유한 영상', null),
          ),
        ],
      ),
    );
  }
}
