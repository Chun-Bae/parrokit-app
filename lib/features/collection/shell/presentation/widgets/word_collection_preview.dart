import 'package:flutter/material.dart';

class WordCollectionPreview extends StatefulWidget {
  const WordCollectionPreview({super.key});

  @override
  State<WordCollectionPreview> createState() => _WordCollectionPreviewState();
}

class _WordCollectionPreviewState extends State<WordCollectionPreview> {
  bool explore = false;
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
        _ViewSwitch(
          explore: explore,
          onChanged: (value) => setState(() => explore = value),
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SwitchButton(
              label: '내 단어',
              selected: !explore,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _SwitchButton(
              label: '둘러보기',
              selected: explore,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchButton extends StatelessWidget {
  const _SwitchButton({
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
    return Material(
      color: selected ? colors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? colors.onSurface : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
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
        color: const Color(0xFFFFE8C7),
        borderRadius: BorderRadius.circular(22),
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
            child: const Icon(Icons.bolt_rounded, color: Color(0xFFAA6B20)),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘 다시 볼 단어 6개',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 4),
                Text('예문을 소리 내어 말하며 복습해요', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          FilledButton.tonal(onPressed: _noop, child: Text('시작')),
        ],
      ),
    );
  }

  static void _noop() {}
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
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
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {},
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
                        Text(item.word,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w900)),
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
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.sentence,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(item.translation,
                        style: TextStyle(
                            color: colors.onSurfaceVariant, fontSize: 12)),
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
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
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
