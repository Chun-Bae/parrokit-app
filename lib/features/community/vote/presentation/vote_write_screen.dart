// ============================================================================
// lib/features/community/presentation/vote_write_screen.dart
// ============================================================================
//
// [역할]
// 테두리가 없는(borderless) 깔끔하고 심플한 피드/트위터 스타일의 투표 작성 화면.
// 제목, 설명, 그리고 추가/삭제 가능한 투표 대상 옵션 항목 입력창 제공.
// 커뮤니티 대표 색상인 Colors.blue[600]을 일관되게 활용하여 제작.
//
// [레이어]
// Presentation Layer > Screens
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/data/models/vote_option.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';

class VoteWriteScreen extends StatefulWidget {
  const VoteWriteScreen({super.key});

  @override
  State<VoteWriteScreen> createState() => _VoteWriteScreenState();
}

class _VoteWriteScreenState extends State<VoteWriteScreen> {
  // ─────────────────────────────────────────────────────────────────
  // 상태 & 컨트롤러
  // ─────────────────────────────────────────────────────────────────
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  // 투표 대상 옵션 필드 리스트 (기본 2개 생성)
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  // 만료일 선택 (기본 3일)
  int _selectedExpirationDays = 3;

  bool get _isValid {
    if (_titleController.text.trim().isEmpty) return false;
    if (_contentController.text.trim().isEmpty) return false;

    // 모든 옵션이 입력되었는지 검사 (최소 2개 이상)
    if (_optionControllers.length < 2) return false;
    for (final controller in _optionControllers) {
      if (controller.text.trim().isEmpty) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_updateState);
    _contentController.addListener(_updateState);
    for (final controller in _optionControllers) {
      controller.addListener(_updateState);
    }
  }

  void _updateState() {
    setState(() {});
  }

  void _addOption() {
    if (_optionControllers.length >= 5) {
      showToast('투표 항목은 최대 5개까지만 추가할 수 있습니다.');
      return;
    }

    final newController = TextEditingController();
    newController.addListener(_updateState);
    setState(() {
      _optionControllers.add(newController);
    });
  }

  void _showExpirationPicker(BuildContext context) {
    int tempSelectedDays = _selectedExpirationDays; // 스크롤 중 임시 저장

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 250,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // 상단 완료/취소 툴바
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text('취소', style: TextStyle(color: CupertinoColors.destructiveRed)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  CupertinoButton(
                    child: const Text('완료', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      setState(() {
                        _selectedExpirationDays = tempSelectedDays;
                      });
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              // 숫자 휠 피커 (1일 ~ 30일)
              Expanded(
                child: CupertinoPicker(
                  magnification: 1.22,
                  squeeze: 1.2,
                  useMagnifier: true,
                  itemExtent: 32.0,
                  scrollController: FixedExtentScrollController(
                    initialItem: tempSelectedDays - 1, // 1~30일을 index 0~29로
                  ),
                  onSelectedItemChanged: (int selectedItem) {
                    tempSelectedDays = selectedItem + 1;
                  },
                  children: List<Widget>.generate(30, (int index) {
                    return Center(
                      child: Text(
                        '${index + 1}일',
                        style: const TextStyle(fontSize: 20),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;

    final controller = _optionControllers[index];
    controller.removeListener(_updateState);
    controller.dispose();
    setState(() {
      _optionControllers.removeAt(index);
    });
  }

  Future<void> _submitVote() async {
    if (!_isValid) return;

    final userProvider = context.read<UserProvider>();
    final communityProvider = context.read<CommunityProvider>();
    final user = userProvider.currentUser;

    if (user == null) {
      showToast('로그인이 필요합니다.');
      return;
    }

    // 포커스 해제 (키보드 내림)
    FocusScope.of(context).unfocus();

    // 입력된 옵션들을 VoteOption 객체 배열로 변환
    final List<VoteOption> voteOptions = [];
    for (int i = 0; i < _optionControllers.length; i++) {
      final text = _optionControllers[i].text.trim();
      voteOptions.add(VoteOption(
        id: i.toString(),
        text: text,
        count: 0,
      ));
    }

    // 만료일 계산
    final voteEndTime = DateTime.now()
        .toUtc()
        .add(Duration(days: _selectedExpirationDays));

    final success = await communityProvider.addPost(
      _titleController.text.trim(),
      _contentController.text.trim(),
      '투표', // category
      postType: 'vote',
      authorId: user.id,
      authorNickname: user.displayName ?? '익명',
      authorAvatarUrl: null, // 임시 프사 지원 시 수정 가능
      voteOptions: voteOptions,
      voteEndTime: voteEndTime,
    );

    if (success && mounted) {
      Navigator.pop(context);
    } else if (mounted) {
      showToast(communityProvider.errorMessage ?? '투표 업로드에 실패했습니다.');
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_updateState);
    _contentController.removeListener(_updateState);
    _titleController.dispose();
    _contentController.dispose();

    for (final controller in _optionControllers) {
      controller.removeListener(_updateState);
      controller.dispose();
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<CommunityProvider>().isLoading;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLight = !isDark;
    const blue600 = AppColors.primary;
    final dividerColor = colorScheme.outlineVariant.withValues(alpha: isDark ? 0.48 : 0.72);
    final optionCardColor = colorScheme.onSecondary;
    final addOptionBg = isDark ? AppColors.surfaceContainerDark : colorScheme.surfaceContainerLow;
    final periodChipBg = isDark ? AppColors.surfaceContainerDark : colorScheme.surfaceContainerHigh;
    final addOptionBorder = colorScheme.outlineVariant.withValues(alpha: isDark ? 0.60 : 0.72);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          '투표 작성',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.close_rounded, size: 28, color: colorScheme.onSurface),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 10.0, bottom: 10.0),
            child: ElevatedButton(
              onPressed: (_isValid && !isLoading) ? _submitVote : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: blue600,
                disabledBackgroundColor: blue600.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      '투표 올리기',
                      style: TextStyle(
                        color: Colors.white,
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
            Container(color: dividerColor, height: 1),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Input Field (Borderless)
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: '투표 제목을 입력하세요.',
                        hintStyle: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
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
                      decoration: InputDecoration(
                        hintText: '투표에 대한 자세한 설명을 적어보세요.',
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
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

                    Divider(color: dividerColor, height: 1, thickness: 1),
                    const SizedBox(height: 24),

                    // ── 투표 기간 설정 ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '투표 진행 기간',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showExpirationPicker(context),
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: periodChipBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '$_selectedExpirationDays일 동안',
                                  style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Vote Options Section
                    Text(
                      '투표 대상 항목',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dynamic Options Inputs
                    ...List.generate(_optionControllers.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: optionCardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                              width: 1,
                            ),
                            boxShadow: isLight
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: blue600,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextField(
                                  controller: _optionControllers[index],
                                  decoration: InputDecoration(
                                    hintText: '항목 ${index + 1} 입력',
                                    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 15),
                                    filled: true,
                                    fillColor: Colors.transparent,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    isDense: true,
                                  ),
                                  style: TextStyle(fontSize: 15, color: colorScheme.onSurface),
                                ),
                              ),
                              if (_optionControllers.length > 2)
                                IconButton(
                                icon: Icon(Icons.remove_circle_outline_rounded, color: Colors.red[400], size: 20),
                                  onPressed: () => _removeOption(index),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),

                    // Add Option Button
                    if (_optionControllers.length < 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: InkWell(
                          onTap: _addOption,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 48,
                            width: double.infinity,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: addOptionBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: addOptionBorder),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle_outline_rounded, size: 18, color: blue600),
                                const SizedBox(width: 8),
                                Text(
                                  '항목 추가하기',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: blue600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
