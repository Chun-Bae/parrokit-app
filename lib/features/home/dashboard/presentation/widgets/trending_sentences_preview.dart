import 'package:flutter/material.dart';

import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

class TrendingSentencesPreview extends StatefulWidget {
  const TrendingSentencesPreview({
    super.key,
    required this.language,
    required this.onViewAll,
  });

  final String language;
  final VoidCallback onViewAll;

  @override
  State<TrendingSentencesPreview> createState() =>
      _TrendingSentencesPreviewState();
}

class _TrendingSentencesPreviewState extends State<TrendingSentencesPreview> {
  final liked = <int>{0};
  final saved = <int>{};

  static const english = [
    _TrendingSentence(
      sentence: 'You’ve got this.',
      translation: '넌 할 수 있어.',
      author: 'dailybird',
      topic: '응원',
      likes: 284,
      age: '방금',
    ),
    _TrendingSentence(
      sentence: 'I’m just looking around.',
      translation: '그냥 둘러보는 중이에요.',
      author: 'Mina',
      topic: '쇼핑',
      likes: 193,
      age: '3분 전',
    ),
    _TrendingSentence(
      sentence: 'That works for me.',
      translation: '저는 그렇게 해도 좋아요.',
      author: 'Joon',
      topic: '일상',
      likes: 167,
      age: '8분 전',
    ),
  ];

  static const japanese = [
    _TrendingSentence(
      sentence: '無理しないでね。',
      translation: '무리하지 마.',
      author: 'haru',
      topic: '응원',
      likes: 241,
      age: '방금',
    ),
    _TrendingSentence(
      sentence: 'ちょっと考えさせて。',
      translation: '조금 생각하게 해줘.',
      author: 'sora',
      topic: '일상',
      likes: 188,
      age: '5분 전',
    ),
    _TrendingSentence(
      sentence: 'また連絡するね。',
      translation: '또 연락할게.',
      author: 'yuki',
      topic: '약속',
      likes: 152,
      age: '11분 전',
    ),
  ];

  static const chinese = [
    _TrendingSentence(
      sentence: '慢慢来，别着急。',
      translation: '천천히 해, 서두르지 마.',
      author: 'xiaoyu',
      topic: '응원',
      likes: 226,
      age: '방금',
    ),
    _TrendingSentence(
      sentence: '我再想一想。',
      translation: '조금 더 생각해 볼게.',
      author: 'lin',
      topic: '일상',
      likes: 174,
      age: '4분 전',
    ),
    _TrendingSentence(
      sentence: '下次再联系。',
      translation: '다음에 다시 연락하자.',
      author: 'momo',
      topic: '약속',
      likes: 149,
      age: '9분 전',
    ),
  ];

  List<_TrendingSentence> get items => switch (widget.language) {
        '일본어' => japanese,
        '중국어' => chinese,
        _ => english,
      };

  void showPracticeMessage(String sentence) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('“$sentence” 연습 연결은 다음 단계에서 붙일게요.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = HomeTokens.of(context);
    final ink = palette.ink;
    final muted = palette.muted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: palette.likeSoft,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 7, color: palette.like),
                  const SizedBox(width: 5),
                  Text(
                    'LIVE',
                    style: context.texts.labelSmall
                        .copyWith(color: palette.likeInk),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '지금 뜨는 문장',
              style: context.texts.headlineSmall
                  .copyWith(color: ink, letterSpacing: -0.4),
            ),
            const Spacer(),
            TextButton(
              onPressed: widget.onViewAll,
              // 바로 위 "내 문장 기록"의 '전체 보기'와 같은 말, 같은 색으로 맞춘다.
              // 전에는 이것만 앱 기본 파랑이라 홈의 하늘색 계열 사이에서 튀었다.
              child: Text('전체 보기', style: TextStyle(color: muted)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '사람들이 지금 저장하고 있는 표현이에요',
          style: context.texts.bodySmall.copyWith(color: muted),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 210,
          child: ListView.separated(
            clipBehavior: Clip.none,
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final isLiked = liked.contains(index);
              final isSaved = saved.contains(index);
              return _SentenceCard(
                item: item,
                liked: isLiked,
                saved: isSaved,
                onLike: () => setState(() {
                  isLiked ? liked.remove(index) : liked.add(index);
                }),
                onSave: () => setState(() {
                  isSaved ? saved.remove(index) : saved.add(index);
                }),
                onPractice: () => showPracticeMessage(item.sentence),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SentenceCard extends StatelessWidget {
  const _SentenceCard({
    required this.item,
    required this.liked,
    required this.saved,
    required this.onLike,
    required this.onSave,
    required this.onPractice,
  });

  final _TrendingSentence item;
  final bool liked;
  final bool saved;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onPractice;

  @override
  Widget build(BuildContext context) {
    final palette = HomeTokens.of(context);
    final ink = palette.ink;
    final muted = palette.muted;

    return Container(
      width: 284,
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 9),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Text(
                  item.topic,
                  style:
                      context.texts.labelSmall.copyWith(color: palette.inkSoft),
                ),
              ),
              const Spacer(),
              Text(item.age,
                  style: context.texts.labelSmall.copyWith(color: muted)),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            item.sentence,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.texts.titleLarge.copyWith(color: ink, height: 1.25),
          ),
          const SizedBox(height: 5),
          Text(
            item.translation,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.texts.bodySmall.copyWith(color: muted),
          ),
          const Spacer(),
          Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: palette.goodSoft,
                child:
                    Icon(Icons.person_rounded, size: 14, color: palette.good),
              ),
              const SizedBox(width: 6),
              Text('@${item.author}',
                  style: context.texts.labelSmall.copyWith(color: muted)),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '좋아요',
                onPressed: onLike,
                icon: Icon(
                  liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 20,
                  color: liked ? palette.like : muted,
                ),
              ),
              Text('${item.likes + (liked ? 1 : 0)}',
                  style: context.texts.labelSmall.copyWith(color: muted)),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '저장',
                onPressed: onSave,
                icon: Icon(
                  saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 20,
                  color: saved ? palette.primary : muted,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '연습에 추가',
                onPressed: onPractice,
                icon: Icon(Icons.record_voice_over_rounded,
                    size: 20, color: palette.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendingSentence {
  const _TrendingSentence({
    required this.sentence,
    required this.translation,
    required this.author,
    required this.topic,
    required this.likes,
    required this.age,
  });

  final String sentence;
  final String translation;
  final String author;
  final String topic;
  final int likes;
  final String age;
}
