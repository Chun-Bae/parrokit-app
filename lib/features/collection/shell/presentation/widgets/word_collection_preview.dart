import 'package:flutter/material.dart';
import 'package:parrokit/core/app/config/app_config.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/features/collection/shared/collection_tokens.dart';
import 'package:parrokit/core/shared/widgets/app_segmented_tabs.dart';

class WordCollectionPreview extends StatefulWidget {
  const WordCollectionPreview({super.key});

  @override
  State<WordCollectionPreview> createState() => _WordCollectionPreviewState();
}

class _WordCollectionPreviewState extends State<WordCollectionPreview> {
  bool explore = AppConfig.wordExplore;
  String language = '영어';
  String category = '전체';
  final savedWords = <int>{0, 2};

  static const categories = ['전체', '최근', '자주 쓰는 말', '여행', '감정'];
  static const words = [
    _WordItem(
      word: 'hesitate',
      meaning: '망설이다',
      sentence: 'Don’t hesitate to ask me.',
      translation: '망설이지 말고 물어봐.',
      count: 4,
    ),
    _WordItem(
      word: 'supposed to',
      meaning: '~하기로 되어 있다',
      sentence: 'I’m supposed to meet her at six.',
      translation: '나는 6시에 그녀를 만나기로 했어.',
      count: 2,
    ),
    _WordItem(
      word: 'figure out',
      meaning: '알아내다, 해결하다',
      sentence: 'We’ll figure it out together.',
      translation: '우리 같이 해결해 보자.',
      count: 7,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const PageStorageKey('word-collection-preview'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
      children: [
        // 단어 탭은 아직 예시 데이터로 그린 미리보기다. 내 단어로 오해하지
        // 않게 새 디자인에서는 맨 위에 한 줄로 알린다.
        if (AppConfig.newDesign) ...[
          Row(children: [
            Icon(Icons.info_outline_rounded,
                size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text('예시 화면이에요. 단어 모으기는 준비 중이에요.',
                  style: context.texts.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          ]),
          const SizedBox(height: 12),
        ],
        _ViewSwitch(
          explore: explore,
          onChanged: (value) {
            setState(() => explore = value);
            AppConfig.wordExplore = value;
            AppConfig.saveToPrefs();
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _LanguageButton(
                label: '🇺🇸  영어',
                selected: language == '영어',
                onTap: () => setState(() => language = '영어'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _LanguageButton(
                label: '🇯🇵  일본어',
                selected: language == '일본어',
                onTap: () => setState(() => language = '일본어'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (context, index) {
              final item = categories[index];
              return ChoiceChip(
                label: Text(item),
                selected: category == item,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => category = item),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        if (explore) ...[
          const _SectionTitle(
            title: '많이 저장한 표현',
            subtitle: '문장과 함께 보면 쓰임을 기억하기 쉬워요',
          ),
          const SizedBox(height: 10),
          ...List.generate(
            words.length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _WordCard(
                item: words[index],
                saved: savedWords.contains(index),
                onSave: () => setState(() {
                  savedWords.contains(index)
                      ? savedWords.remove(index)
                      : savedWords.add(index);
                }),
              ),
            ),
          ),
        ] else ...[
          const _ReviewSummary(),
          const SizedBox(height: 26),
          const _SectionTitle(
            title: '문장에서 건진 단어',
            subtitle: '단어를 눌러 원래 문장을 다시 확인해요',
          ),
          const SizedBox(height: 10),
          ...List.generate(
            words.length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _WordCard(
                item: words[index],
                saved: true,
                onSave: () {},
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({required this.explore, required this.onChanged});

  final bool explore;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => AppSegmentedTabs(
        selectedIndex: explore ? 1 : 0,
        onChanged: (index) => onChanged(index == 1),
        segments: const [
          AppSegment(label: '내 단어'),
          AppSegment(label: '둘러보기'),
        ],
      );
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? colors.primaryContainer : colors.surface,
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.collectionTokens.cream,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.82),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.bolt_rounded,
                color: context.collectionTokens.creamInk),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘 다시 볼 단어 6개',
                  style: context.texts.titleMedium,
                ),
                SizedBox(height: 4),
                Text('예문을 소리 내어 말하며 복습해요', style: context.texts.bodySmall),
              ],
            ),
          ),
          // 복습 흐름이 아직 없다. 빈 함수를 달면 누를 수 있는 모양인데
          // 아무 일도 없으므로 3차(bebc45d2)의 다른 버튼처럼 비활성으로 둔다.
          const FilledButton.tonal(onPressed: null, child: Text('시작')),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.texts.titleLarge),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: context.texts.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      );
}

class _WordCard extends StatelessWidget {
  const _WordCard({
    required this.item,
    required this.saved,
    required this.onSave,
  });

  final _WordItem item;
  final bool saved;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // 단어 상세가 아직 없다. onTap을 null로 두면 눌리는 느낌(물결)이
        // 사라져서, 누를 수 있는 것처럼 보이지 않는다.
        onTap: null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.word, style: context.texts.titleLarge),
                        const SizedBox(height: 3),
                        Text(item.meaning,
                            style: TextStyle(color: colors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '내 단어에 저장',
                    onPressed: onSave,
                    icon: Icon(saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.sentence,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(item.translation,
                        style: context.texts.bodySmall
                            .copyWith(color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Icon(Icons.link_rounded,
                      size: 15, color: colors.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Text(
                    '${item.count}개 문장에서 사용됨',
                    style: context.texts.labelSmall
                        .copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordItem {
  const _WordItem({
    required this.word,
    required this.meaning,
    required this.sentence,
    required this.translation,
    required this.count,
  });

  final String word;
  final String meaning;
  final String sentence;
  final String translation;
  final int count;
}
