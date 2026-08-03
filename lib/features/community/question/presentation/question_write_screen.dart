// ============================================================================
// lib/features/community/question/question_write_screen.dart
// ============================================================================
//
// [역할]
// 테두리가 없는(borderless) 깔끔하고 심플한 피드/트위터 스타일의 질문 작성 화면.
// 카테고리와 프로필 아바타를 제거하고 제목과 내용만을 직관적으로 작성할 수 있도록 간소화.
//
// [레이어]
// Presentation Layer > Screens
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';

class QuestionWriteScreen extends StatefulWidget {
  const QuestionWriteScreen({super.key});

  @override
  State<QuestionWriteScreen> createState() => _QuestionWriteScreenState();
}

class _QuestionWriteScreenState extends State<QuestionWriteScreen> {
  // ─────────────────────────────────────────────────────────────────
  // 상태 & 컨트롤러
  // ─────────────────────────────────────────────────────────────────
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  int _rewardCrackers = 100;
  int _deadlineDays = 3;
  bool _isSubmitting = false;

  bool get _isValid =>
      _titleController.text.trim().isNotEmpty &&
      _contentController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_updateState);
    _contentController.addListener(_updateState);
  }

  void _updateState() {
    setState(() {});
  }

  Future<void> _submitQuestion() async {
    if (!_isValid || _isSubmitting) return;

    final userProvider = context.read<UserProvider>();
    final user = userProvider.currentUser;
    if (user == null) {
      showToast('로그인이 필요합니다.');
      return;
    }

    if (user.crackers < _rewardCrackers) {
      showToast('크래커가 부족합니다. (보유: ${user.crackers} 🍪)');
      return;
    }

    setState(() => _isSubmitting = true);

    final commProvider = context.read<CommunityProvider>();
    final success = await commProvider.addQuestion(
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      category: 'Q&A', // 기본 카테고리
      authorId: user.id,
      authorNickname: user.displayName ?? '익명',
      authorAvatarUrl: user.photoUrl,
      rewardCrackers: _rewardCrackers,
      expireAt: DateTime.now().add(Duration(days: _deadlineDays)),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      // 내 로컬 유저 객체의 크래커도 깎아주기 (UI 갱신)
      userProvider.updateUser(user.addCrackers(-_rewardCrackers));
      Navigator.pop(context);
    } else {
      showToast(commProvider.errorMessage ?? '질문 등록에 실패했습니다.');
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_updateState);
    _contentController.removeListener(_updateState);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentBlue = AppColors.primary;
    const valueTextStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 16,
      color: Colors.black87,
    );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          '질문 작성',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(
            Icons.close_rounded,
            size: 28,
            color: isDark ? Colors.white : colorScheme.onSurface,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 10.0, bottom: 10.0),
            child: ElevatedButton(
              onPressed: (_isValid && !_isSubmitting) ? _submitQuestion : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentBlue,
                disabledBackgroundColor: accentBlue.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: _isSubmitting
                  ? SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(color: colorScheme.onPrimary, strokeWidth: 2),
                    )
                  : Text(
                      '질문하기',
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Thin top divider
            Container(color: AppColors.surfaceContainerHigh, height: 1),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Input Field (Borderless)
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: '제목을 입력하세요.',
                        filled: true,
                        fillColor: Colors.transparent,
                        hintStyle: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDisabled,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Content Input Field (Borderless)
                    TextField(
                      controller: _contentController,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        hintText: '무엇이 궁금하신가요? 단어 번역, 문맥 상 의미, 억양 차이 등 자유롭게 질문해보세요.',
                        filled: true,
                        fillColor: Colors.transparent,
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: AppColors.textDisabled,
                          height: 1.5,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onSurface,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // --- Q&A Settings Box ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF3A3F46) : const Color(0xFFE3E6EB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF5B616B) : const Color(0xFFCAD0D8)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('보상 크래커 🍪', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface)),
                              Text('$_rewardCrackers', style: valueTextStyle),
                            ],
                          ),
                          Slider(
                            value: _rewardCrackers.toDouble(),
                            min: 100,
                            max: 5000,
                            divisions: 49,
                            activeColor: accentBlue,
                            inactiveColor: accentBlue.withValues(alpha: 0.2),
                            onChanged: (val) => setState(() => _rewardCrackers = val.toInt()),
                          ),
                          const Divider(height: 32, color: AppColors.surfaceContainerHigh),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('마감 기한 ⏳', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface)),
                              Text('$_deadlineDays일 후', style: valueTextStyle),
                            ],
                          ),
                          Slider(
                            value: _deadlineDays.toDouble(),
                            min: 1,
                            max: 14,
                            divisions: 13,
                            activeColor: accentBlue,
                            inactiveColor: accentBlue.withValues(alpha: 0.2),
                            onChanged: (val) => setState(() => _deadlineDays = val.toInt()),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Bottom Attachment Toolbar
            Container(
              decoration: BoxDecoration(
                border: const Border(top: BorderSide(color: AppColors.surfaceContainerHigh)),
                color: isDark ? const Color(0xFF151922) : colorScheme.surface,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.image_outlined, color: isDark ? AppColors.primarySoft : AppColors.primary),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Icon(Icons.mic_none_rounded, color: isDark ? AppColors.primarySoft : AppColors.primary),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Icon(Icons.link_rounded, color: isDark ? AppColors.primarySoft : AppColors.primary),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Icon(Icons.tag_rounded, color: isDark ? AppColors.primarySoft : AppColors.primary),
                    onPressed: () {},
                  ),
                  const Spacer(),
                  // Character Counter Text
                  if (_contentController.text.isNotEmpty)
                    Text(
                      '${_contentController.text.length}자',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
