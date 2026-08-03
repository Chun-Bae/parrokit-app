import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:parrokit/features/community/shell/domain/validators/post_validator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parrokit/features/community/shell/domain/data/community_filters.dart';

import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';

class BoardWriteScreen extends StatefulWidget {
  final Post? editPost;
  
  const BoardWriteScreen({super.key, this.editPost});

  @override
  State<BoardWriteScreen> createState() => _BoardWriteScreenState();
}

class _BoardWriteScreenState extends State<BoardWriteScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final FocusNode _tagFocusNode = FocusNode();
  String? _selectedBoardTopic;

  List<String> _tags = [];
  bool _isTagInputActive = false;
  final bool _isImageUploading = false;
  final ImagePicker _picker = ImagePicker();
  
  // 수정 모드일 때 유지되는 기존 파이어베이스 이미지 URL들
  List<String> _existingImageUrls = [];
  // 갤러리에서 새로 추가한 로컬 파일들
  final List<XFile> _selectedImages = [];

  bool get _isEditMode => widget.editPost != null;

  bool get _hasTitle => _titleController.text.trim().isNotEmpty;
  bool get _hasContent => _contentController.text.trim().isNotEmpty;
  bool get _canComplete =>
      _hasTitle && _hasContent && _selectedBoardTopic != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final post = widget.editPost!;
      _titleController.text = post.title;
      _contentController.text = post.content;
      _selectedBoardTopic = post.category;
      _tags = List.from(post.tags);
      _existingImageUrls = List.from(post.imageUrls);
    }
  }

  void _showBoardTopicSheet() {
    const blue600 = AppColors.primary;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '게시판 주제 선택',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: CommunityFilters.board
                      .where((t) => t != '전체')
                      .map((topic) {
                    final selected = topic == _selectedBoardTopic;
                    return ChoiceChip(
                      label: Text(topic),
                      selected: selected,
                      showCheckmark: false,
                      onSelected: (_) {
                        setState(() => _selectedBoardTopic = topic);
                        Navigator.pop(context);
                      },
                      selectedColor: blue600,
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      labelStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                      ),
                      side: BorderSide(
                        width: 1,
                        color: selected
                            ? blue600
                            : colorScheme.surface,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitPost() async {
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;

    if (currentUser == null) {
      showToast('로그인이 필요합니다.');
      return;
    }

    // 다이얼로그 텍스트와 퍼센티지를 업데이트하기 위한 변수 및 함수
    String statusText = _selectedImages.isEmpty 
        ? (_isEditMode ? '게시글을 수정하는 중입니다...' : '게시글을 등록하는 중입니다...') 
        : '사진 업로드 준비 중...';
    double? currentProgress;
    StateSetter? dialogSetState;

    // 사진 업로드 대기 시간 동안 화면 멈춤(렉) 현상 방지를 위해 강제 로딩 다이얼로그 띄우기
    showDialog(
      context: context,
      barrierDismissible: false, // 바깥 영역 터치해도 안 닫히게 막기
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          dialogSetState = setState;
          return PopScope(
            canPop: false, // 안드로이드 뒤로가기 버튼으로도 안 닫히게 막기
            child: AlertDialog(
              content: Row(
                children: [
                  if (currentProgress == null)
                    const CircularProgressIndicator()
                  else
                    CircularProgressIndicator(value: currentProgress),
                  const SizedBox(width: 24),
                  Expanded(child: Text(statusText)),
                ],
              ),
            ),
          );
        },
      ),
    );

    final provider = context.read<CommunityProvider>();
    bool success;
    
    if (_isEditMode) {
      success = await provider.editPost(
        widget.editPost!.id,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        category: _selectedBoardTopic!,
        authorId: currentUser.id,
        tags: _tags,
        existingImageUrls: _existingImageUrls,
        newImageFiles: _selectedImages.map((x) => File(x.path)).toList(),
        onImageProgress: (current, total, progress) {
          if (dialogSetState != null) {
            dialogSetState!((){
              statusText = '새 사진 업로드 중... ($current/$total)\n${(progress * 100).toInt()}% 완료';
              currentProgress = progress;
            });
          }
        },
      );
    } else {
      success = await provider.addPost(
        _titleController.text.trim(),
        _contentController.text.trim(),
        _selectedBoardTopic!,
        authorId: currentUser.id,
        authorNickname: currentUser.displayName ?? '알 수 없음',
        authorAvatarUrl: currentUser.photoUrl,
        tags: _tags,
        imageFiles: _selectedImages.map((x) => File(x.path)).toList(),
        onImageProgress: (current, total, progress) {
          if (dialogSetState != null) {
            dialogSetState!((){
              statusText = '사진 업로드 중... ($current/$total)\n${(progress * 100).toInt()}% 완료';
              currentProgress = progress;
            });
          }
        },
      );
    }

    // 1. 등록 처리가 끝났으므로 로딩 다이얼로그 먼저 닫기
    if (mounted) {
      Navigator.pop(context);
    }

    // 2. 결과 처리
    if (success && mounted) {
      Navigator.maybePop(context); // 글쓰기 화면 닫고 메인으로 돌아가기
    } else if (mounted && provider.errorMessage != null) {
      showToast(provider.errorMessage!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const lineColor = AppColors.disabled;
    const mutedText = AppColors.textDisabled;
    const tipBlue = AppColors.primary;
    final panelBg = isDark ? const Color(0xFF3A4048) : AppColors.surfaceContainer;
    const contentBaseHeight = 230.0;
    const tipAreaHeight = 190.0;
    final contentFieldHeight =
        _hasContent ? contentBaseHeight + tipAreaHeight : contentBaseHeight;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: colorScheme.surface,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 18, 18, 10),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: Icon(Icons.close, size: 34, color: colorScheme.onSurface),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            _isEditMode ? '게시글 수정' : '게시글 작성',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _canComplete ? _submitPost : null,
                        child: context.watch<CommunityProvider>().isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _isEditMode ? '수정' : '완료',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: _canComplete
                                      ? AppColors.primary
                                      : AppColors.disabled,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: lineColor),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: _showBoardTopicSheet,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
                            child: Row(
                              children: [
                                Text(
                                  _selectedBoardTopic ?? '주제를 선택해주세요.',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.keyboard_arrow_down_rounded,
                                    size: 32, color: colorScheme.onSurface),
                              ],
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Divider(
                              height: 1, thickness: 1, color: lineColor),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 32, 0),
                          child: TextField(
                            controller: _titleController,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: '제목을 입력하세요.',
                              hintStyle: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: mutedText,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 18, 32, 0),
                          child: SizedBox(
                            height: contentFieldHeight,
                            child: TextField(
                              controller: _contentController,
                              onChanged: (_) => setState(() {}),
                              minLines: null,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              decoration: const InputDecoration(
                                hintText:
                                    '쉐도잉에 도움 된 표현, 자막 활용 팁, 학습 루틴을 자유롭게 나눠보세요.\n#자막 #쉐도잉 #발음 #미드추천',
                                hintStyle: TextStyle(
                                  fontSize: 16,
                                  height: 1.6,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textDisabled,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: const TextStyle(
                                fontSize: 18,
                                height: 1.6,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        if (!_hasContent) ...[
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                _TipBadge(),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '쉐도잉 학습과 영상 자막 활용 경험을 나눠보세요',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : tipBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                            decoration: BoxDecoration(
                              color: panelBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _TipBullet(
                                  text: '영상 자막 자동 생성, 쉐도잉 팁, 학습 루틴을 자유롭게 공유해요.',
                                  forceWhite: isDark,
                                ),
                                const SizedBox(height: 14),
                                _TipBullet(
                                  text:
                                      '외국어 표현, 추천 콘텐츠, 발음 연습 경험처럼 학습에 도움이 되는 이야기를 나눠요.',
                                  forceWhite: isDark,
                                ),
                                const SizedBox(height: 14),
                                _TipBullet(
                                  text:
                                      '저작권을 침해하거나 학습 커뮤니티 성격에 맞지 않는 글은 제한될 수 있어요.',
                                  forceWhite: isDark,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // 등록된 태그 칩들을 보여주는 횡스크롤 영역
                if (_tags.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _tags
                            .map((tag) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: InputChip(
                                    label: Text('#$tag'),
                                    onDeleted: () {
                                      setState(() {
                                        _tags.remove(tag);
                                      });
                                    },
                                    backgroundColor: AppColors.primarySoft,
                                    deleteIconColor: AppColors.primary,
                                    labelStyle: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      side: const BorderSide(
                                          color: Colors.transparent),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ),

                // 태그 입력창 (활성화 시에만 보임)
                if (_isTagInputActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: panelBg,
                      border: Border(top: BorderSide(color: lineColor)),
                    ),
                    child: TextField(
                      controller: _tagController,
                      focusNode: _tagFocusNode,
                      decoration: InputDecoration(
                        hintText: '태그를 입력하고 엔터를 누르세요',
                        hintStyle: const TextStyle(
                            color: AppColors.textDisabled, fontSize: 15),
                        border: InputBorder.none,
                        isDense: true,
                        suffixText: '${_tags.length}/${PostValidator.maxTags}',
                        suffixStyle: const TextStyle(
                            color: AppColors.textDisabled,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (val) {
                        final text = val.trim();
                        if (text.isNotEmpty && !_tags.contains(text)) {
                          if (text.length > PostValidator.maxTagLength) {
                            showToast('태그는 ${PostValidator.maxTagLength}글자 이하로 입력해주세요.');
                            return;
                          }
                          if (_tags.length >= PostValidator.maxTags) {
                            showToast('태그는 최대 20개까지만 등록할 수 있습니다.');
                            return;
                          }

                          setState(() {
                            _tags.add(text);
                          });
                          _tagController.clear();
                          _tagFocusNode.requestFocus(); // 계속 입력할 수 있도록 포커스 유지
                        }
                      },
                    ),
                  ),
                if (_existingImageUrls.isNotEmpty || _selectedImages.isNotEmpty)
                  Container(
                    height: 100, // 잘림 방지를 위해 높이 증가
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    margin: const EdgeInsets.only(top: 16, bottom: 16),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none, // 스크롤 시 잘림 방지
                      itemCount: _existingImageUrls.length + _selectedImages.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 6), // 우측 패딩을 고려하여 간격 축소
                      itemBuilder: (context, index) {
                        final bool isExisting = index < _existingImageUrls.length;
                        
                        return Padding(
                          padding: const EdgeInsets.only(top: 10, right: 10),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: isExisting 
                                  ? Image.network(
                                      _existingImageUrls[index],
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(_selectedImages[index - _existingImageUrls.length].path),
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                              ),
                              Positioned(
                                top: -8,
                                right: -8,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (isExisting) {
                                        _existingImageUrls.removeAt(index);
                                      } else {
                                        _selectedImages.removeAt(index - _existingImageUrls.length);
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: colorScheme.scrim.withValues(alpha: 0.55),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                Container(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: lineColor)),
                  ),
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 18),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () async {
                                final int currentCount = _existingImageUrls.length + _selectedImages.length;
                                final int remainingSlot = 5 - currentCount;
                                if (remainingSlot <= 0) {
                                  showToast('사진은 최대 5장까지만 첨부할 수 있습니다.');
                                  return;
                                }

                                List<XFile>? images;
                                try {
                                  images = await _picker.pickMultiImage(
                                    limit: remainingSlot, // 갤러리 자체에서 선택 개수 제한
                                    requestFullMetadata:
                                        false, // 아이클라우드 및 메타데이터 로드 실패 버그 우회용
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  showToast('지원하지 않는 형식이거나 깨진 이미지입니다. 다른 사진을 골라주세요.');
                                  return;
                                }
                                if (images.isEmpty) return;

                                setState(() {
                                  _selectedImages.addAll(images!);
                                });
                              },
                        child: _BottomTool(
                            icon: Icons.image_outlined,
                            label: '사진 (${_existingImageUrls.length + _selectedImages.length}/5)'),
                      ),
                      const SizedBox(width: 28),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isTagInputActive = !_isTagInputActive;
                            if (_isTagInputActive) {
                              _tagFocusNode.requestFocus();
                            }
                          });
                        },
                        child: _BottomTool(
                          icon: Icons.tag_rounded,
                          label: '태그',
                          isActive: _isTagInputActive,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isImageUploading)
          Container(
            color: colorScheme.scrim.withValues(alpha: 0.5),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}

class _TipBadge extends StatelessWidget {
  const _TipBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Text(
        'TIP',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _TipBullet extends StatelessWidget {
  final String text;
  final bool forceWhite;

  const _TipBullet({required this.text, this.forceWhite = false});

  @override
  Widget build(BuildContext context) {
    final bodyColor = forceWhite ? Colors.white : AppColors.textPrimary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 6),
          child: Icon(Icons.circle, size: 8, color: bodyColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: bodyColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomTool extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;

  const _BottomTool({
    required this.icon,
    required this.label,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.textDisabled;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 28, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
