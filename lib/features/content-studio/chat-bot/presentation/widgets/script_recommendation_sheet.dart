import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';

Future<void> showScriptRecommendationSheet(
  BuildContext context,
  List<String> scripts,
  void Function(int tabIndex, Map<String, dynamic>? actionData)?
      onTriggerAction,
) async {
  if (scripts.isEmpty) return;

  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  int selectedIndex = 0; // 기본으로 첫 번째 항목 선택

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.tokens.surfaceContainerHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext sheetContext) {
      return StatefulBuilder(builder: (context, setState) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.post_add_rounded,
                  size: 48,
                  color: context.tokens.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  '어떤 스크립트를 추가하시겠습니까?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '선택한 스크립트를 TTS 입력창으로 복사합니다.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // 스크립트 선택 리스트
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: scripts.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final script = scripts[index];
                        final isSelected = selectedIndex == index;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              selectedIndex = index;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? context.tokens.primary
                                    : (context.tokens.dividerSubtle),
                                width: isSelected ? 2 : 1,
                              ),
                              color: isSelected
                                  ? context.tokens.primary
                                      .withValues(alpha: 0.1)
                                  : (isDark
                                      ? context.tokens.surfaceContainer
                                      : context.tokens.surface),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  color: isSelected
                                      ? context.tokens.primary
                                      : (context.tokens.textTertiary),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    script,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: context.tokens.textPrimary,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // 1. 바텀시트 닫기
                          Navigator.of(sheetContext).pop();

                          // 2. 챗봇 패널 닫기 (이전 라우트 팝)
                          Navigator.of(context).pop();

                          // 3. TTS 탭(인덱스 1)으로 이동 및 텍스트 전달
                          if (onTriggerAction != null) {
                            onTriggerAction(
                                1, {'text': scripts[selectedIndex]});
                          }
                        },
                        child: const Text('추가하기'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      });
    },
  );
}
