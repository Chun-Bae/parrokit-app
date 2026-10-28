import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:parrokit/core/app/router/app_routes.dart';

class LearningHubScreen extends StatefulWidget {
  const LearningHubScreen({super.key});

  @override
  State<LearningHubScreen> createState() => _LearningHubScreenState();
}

class _LearningHubScreenState extends State<LearningHubScreen> {
  int mode = 0;

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF3F8FD);
    const surface = Colors.white;
    const ink = Color(0xFF24364F);
    const muted = Color(0xFF61758D);
    const accent = Color(0xFFA8CBE8);

    Widget destination(
        IconData icon, String title, String subtitle, String? path) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          child: ListTile(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            leading: Icon(icon, color: path == null ? muted : ink),
            title: Text(title,
                style: TextStyle(color: ink, fontWeight: FontWeight.w700)),
            subtitle:
                Text(subtitle, style: TextStyle(color: muted, fontSize: 12)),
            trailing: path == null
                ? Text('준비 중', style: TextStyle(color: muted, fontSize: 12))
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
              style: TextStyle(
                color: ink,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.3,
              )),
          const SizedBox(height: 10),
          Text('내게 맞는 방법으로, 한 문장씩 가볍게.', style: TextStyle(color: muted)),
          const SizedBox(height: 28),
          Text('학습 방법',
              style: TextStyle(
                  color: ink, fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final cards = List.generate(2, (index) {
              final selected = mode == index;
              return Semantics(
                selected: selected,
                button: true,
                child: Material(
                  color: selected ? accent : surface,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
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
                                  color:
                                      selected ? const Color(0xFF24364F) : ink,
                                  size: 30),
                              const Spacer(),
                              if (selected)
                                const Icon(Icons.check_circle_rounded,
                                    color: Color(0xFF24364F), size: 20),
                            ]),
                            const SizedBox(height: 20),
                            Text(index == 0 ? '따라 말하기' : '반복 듣기',
                                style: TextStyle(
                                  color:
                                      selected ? const Color(0xFF24364F) : ink,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                )),
                            const SizedBox(height: 6),
                            Text(
                                index == 0
                                    ? '듣고 내 목소리로\n소리 내어 연습해요'
                                    : '좋아하는 구간을\n여러 번 들어요',
                                style: TextStyle(
                                  color: selected
                                      ? const Color(0xFF415C7A)
                                      : muted,
                                  fontSize: 12,
                                  height: 1.6,
                                )),
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
          const SizedBox(height: 16),
          Text(
              mode == 0
                  ? '영상을 고른 뒤, 자막을 보며 직접 따라 말해보세요. 음성 인식과 자동 경험치 지급은 준비 중이에요.'
                  : '영상을 고른 뒤, 플레이어의 반복 버튼으로 원하는 자막 구간을 반복해서 들어보세요.',
              style: TextStyle(color: muted, fontSize: 12, height: 1.7)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push(AppRoutes.collectionPath),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: const Color(0xFF24364F),
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(mode == 0 ? '따라 말할 영상 고르기' : '반복해서 들을 영상 고르기',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 30),
          Text('공부할 영상 찾기',
              style: TextStyle(
                  color: ink, fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('먼저 영상을 둘러봐도 좋아요.',
              style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 14),
          destination(Icons.swipe_up_rounded, '쇼츠로 발견하기',
              '짧은 영상을 넘기며 마음에 드는 표현 찾기', AppRoutes.explorePath),
          destination(Icons.video_library_outlined, '동영상별로 보기',
              '콜렉션에서 영상과 학습 클립 찾아보기', AppRoutes.collectionPath),
          destination(Icons.people_outline_rounded, '함께 나눈 영상 보기',
              '내가 공유하거나 다른 사람이 공유한 영상', null),
        ],
      ),
    );
  }
}
