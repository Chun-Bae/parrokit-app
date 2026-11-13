// ============================================================================
// lib/features/community/presentation/vote_view_screen.dart
// ============================================================================
//
// [역할]
// 투표 상세 보기 및 토론 피드 화면.
// 상단에 투표 카드(VoteCard)를 그대로 노출하여 직관성을 유지하고,
// 하단에 해당 주제에 대한 의견/토론 댓글 리스트와 스티키 입력 창을 배치.
//
// [레이어]
// Presentation Layer > Screens
import 'package:parrokit/features/community/shared/presentation/widgets/community_report_actions.dart';
import 'package:flutter/material.dart';
import 'package:parrokit/features/community/shell/presentation/utils/community_post_ui_utils.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/features/community/board/presentation/board_write_screen.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/data/models/comment.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'vote_screen.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/community_block_actions.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/community_options_sheet.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/comment_row.dart';

class VoteViewScreen extends StatefulWidget {
  final String voteId;

  const VoteViewScreen({super.key, required this.voteId});

  @override
  State<VoteViewScreen> createState() => _VoteViewScreenState();
}

class _VoteViewScreenState extends State<VoteViewScreen> {
  // ─────────────────────────────────────────────────────────────────
  // 상태 & 데이터
  // ─────────────────────────────────────────────────────────────────
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isFetchingDetails = true;

  bool get _canSubmitComment => _commentController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = context.read<UserProvider>().currentUser;
      final provider = context.read<CommunityProvider>();

      await provider.fetchPostDetails(widget.voteId);

      final futures = <Future<void>>[
        provider.fetchComments(widget.voteId, currentUserId: user?.id),
        provider.loadUserActions(widget.voteId, userId: user?.id),
      ];
      if (user != null) {
        futures.add(provider.fetchMyVotes(user.id));
      }

      await Future.wait(futures);
      provider.incrementViewCount(widget.voteId, userId: user?.id);

      if (mounted) {
        setState(() {
          _isFetchingDetails = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  void _focusCommentInput() {
    FocusScope.of(context).requestFocus(_commentFocusNode);
  }

  void _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = context.read<UserProvider>().currentUser;
    if (user == null) {
      showToast('로그인이 필요합니다.');
      return;
    }

    final provider = context.read<CommunityProvider>();

    _commentController.clear();
    _commentFocusNode.unfocus();

    final success = await provider.addComment(
      widget.voteId,
      text,
      authorId: user.id,
      authorNickname: user.displayName ?? '',
      authorAvatarUrl: user.photoUrl,
    );

    if (success) {
      _scrollToBottom();
    } else {
      if (mounted) {
        // 미리 비우는 건 반응이 빨라 보이려는 것이지, 실패했을 때 사용자가
        // 다시 타이핑해야 한다는 뜻은 아니다. 쓴 글을 돌려준다.
        _commentController.text = text;
        showToast(provider.errorMessage ?? '댓글 등록 실패');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = context.watch<CommunityProvider>();
    final currentUser = context.watch<UserProvider>().currentUser;
    final voteItem =
        provider.posts.where((p) => p.id == widget.voteId).firstOrNull;

    if (_isFetchingDetails) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (voteItem == null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(child: Text('투표를 찾을 수 없습니다.')),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: '뒤로',
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: colorScheme.onSurface, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          '투표 상세 토론',
          style:
              context.texts.titleMedium.copyWith(color: colorScheme.onSurface),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child:
              Container(color: context.tokens.surfaceContainerHigh, height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 투표 카드 표시
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: VoteCard(
                      item: voteItem,
                      selectedOption: provider.myVotes[voteItem.id],
                      showResult: false,
                      showToggleResultButton: false,
                      enablePostActions: true,
                      isPostLiked: provider.isCurrentPostLiked,
                      isPostScrapped: provider.isCurrentPostScrapped,
                      onTogglePostLike: () {
                        if (currentUser == null) {
                          showToast('로그인이 필요합니다.');
                          return;
                        }
                        provider.toggleLike(voteItem.id, currentUser.id);
                      },
                      onTogglePostScrap: () {
                        if (currentUser == null) {
                          showToast('로그인이 필요합니다.');
                          return;
                        }
                        provider.toggleScrap(voteItem.id, currentUser.id);
                      },
                      onMorePressed: () => _showVoteOptionsSheet(voteItem),
                      onSelect: (idx) {
                        final user = context.read<UserProvider>().currentUser;
                        if (user != null) {
                          provider.votePost(voteItem.id, idx, user.id);
                        }
                      },
                      onToggleResult: () {},
                    ),
                  ),

                  // Divider
                  Container(
                    height: 8,
                    color: colorScheme.onSurface.withValues(alpha: 0.08),
                  ),

                  // Comments section header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(
                      '토론 & 의견 (${provider.currentPostComments.length})',
                      style: context.texts.titleMedium
                          .copyWith(color: colorScheme.onSurface),
                    ),
                  ),

                  // List of comments
                  if (provider.currentPostComments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      child: Center(
                        child: Text(
                          '첫 의견을 작성해 투표 토론에 참여해보세요!',
                          style: context.texts.bodyMedium
                              .copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    ..._buildStructuredComments(
                        provider.currentPostComments, voteItem.authorId),
                ],
              ),
            ),
          ),

          // Sticky Reply Input Bar
          _buildStickyReplyBar(),
        ],
      ),
    );
  }


  List<Widget> _buildStructuredComments(
      List<Comment> allComments, String postAuthorId) {
    final colorScheme = Theme.of(context).colorScheme;
    final parentComments =
        allComments.where((c) => c.parentId == null).toList();
    final childComments = allComments.where((c) => c.parentId != null).toList();

    final List<Widget> widgets = [];
    for (var i = 0; i < parentComments.length; i++) {
      final parent = parentComments[i];
      widgets.add(_buildCommentItem(parent, postAuthorId, isReply: false));

      final children =
          childComments.where((c) => c.parentId == parent.id).toList();
      for (var child in children) {
        widgets.add(_buildCommentItem(child, postAuthorId, isReply: true));
      }

      if (i < parentComments.length - 1) {
        widgets.add(Divider(
            color: colorScheme.onSurface.withValues(alpha: 0.06), height: 1));
      }
    }
    return widgets;
  }

  Widget _buildCommentItem(Comment comment, String postAuthorId,
      {required bool isReply}) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = context.read<UserProvider>().currentUser;
    final isDeleted = comment.status == 'deleted';
    final provider = context.watch<CommunityProvider>();
    final isLiked = provider.likedCommentIds.contains(comment.id);
    final isBlocked = provider.isAuthorBlocked(comment.authorId);

    return GestureDetector(
      onLongPress: () => _showCommentOptionsSheet(comment),
      behavior: HitTestBehavior.opaque,
      child: CommentRow(
        isReply: isReply,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: context.tokens.surfaceContainerHigh,
              backgroundImage: (comment.authorAvatarUrl != null &&
                      comment.authorAvatarUrl!.isNotEmpty &&
                      !isDeleted &&
                      !isBlocked)
                  ? CachedNetworkImageProvider(comment.authorAvatarUrl!)
                  : null,
              child: (comment.authorAvatarUrl == null ||
                      comment.authorAvatarUrl!.isEmpty ||
                      isDeleted ||
                      isBlocked)
                  ? Icon(isBlocked ? Icons.block_rounded : Icons.person,
                      color: context.tokens.textDisabled, size: 20)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        isDeleted
                            ? '알 수 없음'
                            : isBlocked
                                ? '차단한 사용자'
                                : comment.authorNickname,
                        style: context.texts.bodyMedium
                            .copyWith(color: colorScheme.onSurface),
                      ),
                      if (comment.authorId == postAuthorId &&
                          !isDeleted &&
                          !isBlocked) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: context.tokens.primarySoft,
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: Text(
                            '작성자',
                            style: context.texts.labelSmall
                                .copyWith(color: context.tokens.primary),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (comment.createdAt != null && !isBlocked)
                        Text(
                          formatCommunityTimeAgo(comment.createdAt),
                          style: context.texts.bodySmall
                              .copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      if (!isBlocked) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: '댓글 옵션',
                          icon: const Icon(Icons.more_vert_rounded, size: 18),
                          color: colorScheme.onSurfaceVariant,
                          onPressed: () => _showCommentOptionsSheet(comment),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (isReply &&
                      comment.replyToNickname != null &&
                      !isDeleted &&
                      !isBlocked)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '@${comment.replyToNickname}',
                        style: context.texts.labelMedium
                            .copyWith(color: context.tokens.primary),
                      ),
                    ),
                  Text(
                    isDeleted
                        ? '삭제된 댓글입니다.'
                        : isBlocked
                            ? '차단된 사용자의 댓글입니다.'
                            : comment.content,
                    style: context.texts.bodyMedium.copyWith(
                        color: isDeleted
                            ? context.tokens.textDisabled
                            : colorScheme.onSurface,
                        height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  if (!isDeleted && !isBlocked)
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (currentUser == null) return;
                            provider.toggleCommentLike(
                                widget.voteId, comment.id, currentUser.id);
                          },
                          child: Row(
                            children: [
                              Icon(
                                isLiked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 15,
                                color: isLiked
                                    ? context.tokens.danger
                                    : colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${comment.likeCount}',
                                style: context.texts.bodySmall.copyWith(
                                    color: isLiked
                                        ? context.tokens.danger
                                        : colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () {
                            provider.setReplyingTo(comment);
                            _focusCommentInput();
                          },
                          child: Text(
                            '답글 쓰기',
                            style: context.texts.bodySmall
                                .copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCommentOptionsSheet(Comment comment) {
    if (comment.status == 'deleted') return;

    final currentUser = context.read<UserProvider>().currentUser;
    final isMyComment =
        currentUser != null && comment.authorId == currentUser.id;
    showCommunityOptionsSheet(
      context: context,
      title: '댓글 옵션',
      actions: [
        if (isMyComment)
          CommunityOptionAction(
            label: '삭제',
            icon: Icons.delete_outline_rounded,
            isDestructive: true,
            onTap: () async {
              final deleted = await context
                  .read<CommunityProvider>()
                  .deleteComment(widget.voteId, comment.id);
              if (!mounted) return;
              showToast(deleted ? '댓글이 삭제되었습니다.' : '삭제에 실패했습니다.');
            },
          ),
        if (!isMyComment)
          buildCommunityBlockAction(
            context: context,
            targetUid: comment.authorId,
            targetDisplayName: comment.authorNickname,
          ),
        if (!isMyComment)
          buildCommunityReportAction(
            context: context,
            postId: widget.voteId,
            commentId: comment.id,
            targetAuthorId: comment.authorId,
          ),
      ],
    );
  }

  Future<void> _showVoteOptionsSheet(Post vote) async {
    final currentUser = context.read<UserProvider>().currentUser;
    final isMyPost = currentUser != null && vote.authorId == currentUser.id;

    await showCommunityOptionsSheet(
      context: context,
      title: '투표 옵션',
      actions: [
        if (isMyPost)
          CommunityOptionAction(
            label: '수정',
            icon: Icons.edit_outlined,
            onTap: () async {
              if (!mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BoardWriteScreen(editPost: vote),
                ),
              );
            },
          ),
        if (isMyPost)
          CommunityOptionAction(
            label: '삭제',
            icon: Icons.delete_outline_rounded,
            isDestructive: true,
            onTap: () async {
              final deleted =
                  await context.read<CommunityProvider>().deletePost(vote.id);
              if (!mounted) return;
              if (deleted) {
                showToast('투표가 삭제되었습니다.');
                Navigator.maybePop(context);
              } else {
                showToast('삭제에 실패했습니다.');
              }
            },
          ),
        if (!isMyPost)
          buildCommunityBlockAction(
            context: context,
            targetUid: vote.authorId,
            targetDisplayName: vote.authorNickname,
          ),
        if (!isMyPost)
          buildCommunityReportAction(
            context: context,
            postId: vote.id,
            targetAuthorId: vote.authorId,
          ),
      ],
    );
  }

  Widget _buildStickyReplyBar() {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = context.watch<CommunityProvider>();
    final currentUser = context.watch<UserProvider>().currentUser;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (provider.replyingTo != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: context.tokens.surfaceContainer,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${provider.replyingTo?.authorNickname} 님에게 답글 남기는 중',
                    style: context.texts.labelMedium
                        .copyWith(color: context.tokens.textSecondary),
                  ),
                ),
                GestureDetector(
                  onTap: () => provider.setReplyingTo(null),
                  child: Icon(Icons.close,
                      size: 16, color: context.tokens.textTertiary),
                ),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
            border: Border(
              top: BorderSide(
                  color: context.tokens.surfaceContainerHigh, width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: SafeArea(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: context.tokens.surfaceContainerHigh,
                  backgroundImage: (currentUser?.photoUrl != null &&
                          currentUser!.photoUrl!.isNotEmpty)
                      ? CachedNetworkImageProvider(currentUser.photoUrl!)
                      : null,
                  child: (currentUser?.photoUrl == null ||
                          currentUser!.photoUrl!.isEmpty)
                      ? Icon(Icons.person,
                          color: context.tokens.textDisabled, size: 18)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(color: colorScheme.surface, width: 1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _submitComment(),
                      decoration: InputDecoration(
                        hintText: '투표 의견 남기기...',
                        fillColor: colorScheme.surfaceContainerHigh,
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                      ),
                      style: context.texts.bodyMedium
                          .copyWith(color: colorScheme.onSurface),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '보내기',
                  icon: Icon(
                    Icons.send_rounded,
                    color: _canSubmitComment
                        ? context.tokens.primary
                        : colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                  onPressed: _canSubmitComment ? _submitComment : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
