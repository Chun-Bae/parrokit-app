// 문장 탭의 언어·주제 고르는 줄(5차 333, 사용자 요청).
//
// 전에는 문장 목록 맨 위 항목이라 스크롤하면 함께 사라졌다. 보관함 머리줄의
// 한 단으로 올리려고 따로 뺐다. 혼자 쓰는 화면(둘러보기)에서는 예전처럼
// 목록 안에 둔다.

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/widgets/learning_language_picker.dart';

/// 문장 주제 칩. 목록과 머리줄이 같은 값을 쓴다.
const List<String> sentenceCategories = [
  '전체',
  '일상',
  '여행',
  '카페',
  '감정',
  '회사',
  '학교',
];

class SentenceFilterRow extends StatelessWidget {
  const SentenceFilterRow({
    super.key,
    required this.language,
    required this.category,
    required this.onLanguageChanged,
    required this.onCategoryChanged,
    this.padding = EdgeInsets.zero,
  });

  final String language;
  final String category;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<String> onCategoryChanged;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: sentenceCategories.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 7),
          itemBuilder: (context, index) {
            // 학습 언어는 따로 한 줄을 쓰지 않고 주제 칩 맨 앞에 둔다.
            if (index == 0) {
              return Center(
                child: LearningLanguagePicker(
                  compact: true,
                  value: language,
                  onChanged: onLanguageChanged,
                ),
              );
            }
            final item = sentenceCategories[index - 1];
            return Center(
              child: ChoiceChip(
                label: Text(item),
                selected: category == item,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => onCategoryChanged(item),
              ),
            );
          },
        ),
      ),
    );
  }
}
