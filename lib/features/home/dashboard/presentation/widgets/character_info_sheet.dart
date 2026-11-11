import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

Future<void> showCharacterInfoSheet(
  BuildContext context, {
  required String language,
  required int experience,
  required int completedQuests,
  required int totalQuests,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => CharacterInfoSheet(
      language: language,
      experience: experience,
      completedQuests: completedQuests,
      totalQuests: totalQuests,
    ),
  );
}

class CharacterInfoSheet extends StatelessWidget {
  const CharacterInfoSheet({
    super.key,
    required this.language,
    required this.experience,
    required this.completedQuests,
    required this.totalQuests,
  });

  final String language;
  final int experience;
  final int completedQuests;
  final int totalQuests;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFF1F4EC) : const Color(0xFF24372B);
    final muted = dark ? const Color(0xFFAAB7A8) : const Color(0xFF72806E);
    final tile = dark ? const Color(0xFF30392D) : const Color(0xFFF1F5E9);
    const green = Color(0xFF719C39);

    Widget detail(IconData icon, String title, String value) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: tile, borderRadius: BorderRadius.circular(18)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 18, color: muted),
              const SizedBox(width: 8),
              Flexible(
                  child: Text(title,
                      style: context.texts.bodySmall.copyWith(color: muted)))
            ]),
            const SizedBox(height: 10),
            Text(value, style: context.texts.titleMedium.copyWith(color: ink)),
          ]),
        );

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                      child: Text('캐릭터 정보',
                          style: context.texts.headlineSmall
                              .copyWith(color: ink))),
                  IconButton(
                      tooltip: '닫기',
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: muted)),
                ]),
                Center(
                    child: Column(children: [
                  const ExcludeSemantics(
                      child: Text('🦜', style: TextStyle(fontSize: 84))),
                  Text('피코',
                      style: context.texts.headlineMedium.copyWith(color: ink)),
                  const SizedBox(height: 6),
                  Text('Lv. 5 · 작은 모험가', style: TextStyle(color: muted)),
                  const SizedBox(height: 8),
                  Text('한 문장씩 배우며 함께 자라는 친구',
                      style: context.texts.bodySmall.copyWith(color: muted)),
                ])),
                const SizedBox(height: 24),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('다음 레벨까지 ${100 - experience} XP',
                          style: TextStyle(
                              color: ink, fontWeight: FontWeight.w700)),
                      Text('$experience / 100',
                          style:
                              context.texts.bodySmall.copyWith(color: muted)),
                    ]),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                    value: experience / 100,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(10),
                    color: green,
                    backgroundColor: tile),
                const SizedBox(height: 20),
                LayoutBuilder(builder: (context, constraints) {
                  final items = [
                    detail(Icons.language_rounded, '선택한 학습 언어', language),
                    detail(Icons.task_alt_rounded, '오늘의 퀘스트',
                        '$completedQuests / $totalQuests 완료'),
                  ];
                  if (constraints.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          items[0],
                          const SizedBox(height: 12),
                          items[1]
                        ]);
                  }
                  return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: items[0]),
                        const SizedBox(width: 12),
                        Expanded(child: items[1])
                      ]);
                }),
                const SizedBox(height: 20),
                Text('앞으로의 성장',
                    style: context.texts.titleMedium.copyWith(color: ink)),
                const SizedBox(height: 8),
                Text('학습으로 경험치를 모으고, 새로운 모습과 장비를 만나게 될 예정이에요.',
                    style: context.texts.labelMedium
                        .copyWith(color: muted, height: 1.6)),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: tile, borderRadius: BorderRadius.circular(14)),
                  child: Text(
                      '미리보기 정보예요. 레벨·경험치는 예시이며 실제 학습 기록이나 자동 전투 능력치와 연결되지 않아요.',
                      style: context.texts.labelSmall
                          .copyWith(color: muted, height: 1.6)),
                ),
              ]),
        ),
      ),
    );
  }
}
