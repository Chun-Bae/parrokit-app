import 'package:flutter/material.dart';
import 'package:parrokit/features/community/shell/presentation/utils/community_post_ui_utils.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/data/models/comment.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/features/community/board/presentation/board_write_screen.dart';
import 'package:parrokit/features/community/board/presentation/widgets/board_action_tile.dart';
import 'package:parrokit/features/community/board/presentation/widgets/board_comment_input_bar.dart';
import 'package:parrokit/features/community/board/presentation/widgets/board_post_meta_row.dart';
import 'package:parrokit/features/community/board/presentation/widgets/board_post_author_row.dart';
import 'package:parrokit/features/community/board/presentation/widgets/board_post_content_section.dart';
import 'package:parrokit/features/community/board/presentation/sections/board_comments_section.dart';
import 'package:parrokit/features/community/board/presentation/handlers/board_options_handler.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/features/community/shell/presentation/missing_post_view.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/features/community/shared/presentation/community_error_text.dart';
import 'package:parrokit/features/community/shared/presentation/community_delete_confirm.dart';
import 'package:parrokit/features/community/shared/presentation/comment_input_text.dart';

class BoardViewScreen extends StatefulWidget {
  final String postId;

  const BoardViewScreen({super.key, required this.postId});

  @override
  State<BoardViewScreen> createState() => _BoardViewScreenState();
}

class _BoardViewScreenState extends State<BoardViewScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  bool get _canSubmitComment => _commentController.text.trim().isNotEmpty;

  bool _isFetchingDetails = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = context.read<UserProvider>().currentUser;
      final provider = context.read<CommunityProvider>();

      await Future.wait([
        provider.fetchPostDetails(widget.postId),
        provider.fetchComments(widget.postId, currentUserId: user?.id),
        provider.loadUserActions(widget.postId, userId: user?.id),
      ]);

      provider.incrementViewCount(widget.postId, userId: user?.id);

      if (mounted) {
        setState(() {
          _isFetchingDetails = false;
        });
      }
    });
  }

  void _focusCommentInput() {
    FocusScope.of(context).requestFocus(_commentFocusNode);
    Future<void>.delayed(const Duration(milliseconds: 20), () {
      if (!mounted) return;
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  void _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final currentUser = context.read<UserProvider>().currentUser;
    if (currentUser == null) {
      showToast(communityLoginRequiredText);
      return;
    }

    _commentController.clear();
    _commentFocusNode.unfocus();

    final provider = context.read<CommunityProvider>();
    // 답글을 쓰는 중이었는지는 보내기 전에 잡아 둔다. 성공하면 provider가
    // 지운다. 입력칸·툴팁은 '답글'이라 하면서 실패 안내만 '댓글'이었다(5차 398).
    final replying = provider.replyingTo != null;
    final success = await provider.addComment(
      widget.postId,
      text,
      authorId: currentUser.id,
      authorNickname: currentUser.displayName ?? commentUnknownNickname,
      authorAvatarUrl: currentUser.photoUrl,
    );

    if (success) {
      _scrollToBottom();
    } else if (mounted) {
      // 미리 비우는 건 반응이 빨라 보이려는 것이지, 실패했을 때 사용자가
      // 다시 타이핑해야 한다는 뜻은 아니다. 쓴 글을 돌려준다.
      _commentController.text = text;
      showToast(
          provider.errorMessage ?? commentSendFailedText(replying: replying));
    }
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

  void _showCommentOptionsSheet(Comment comment) {
    // 이미 지운 댓글에는 지우기·신고가 뜨지 않게 한다. 투표 화면만
    // 막고 있었다(5차 399).
    if (comment.status == 'deleted') return;

    final currentUser = context.read<UserProvider>().currentUser;
    final isMyComment =
        currentUser != null && comment.authorId == currentUser.id;
    BoardOptionsHandler.showCommentOptionsSheet(
      context: context,
      isMyComment: isMyComment,
      blockedUserId: comment.authorId,
      blockedUserDisplayName: comment.authorNickname,
      postId: comment.postId,
      commentId: comment.id,
      onDelete: () async {
        final provider = context.read<CommunityProvider>();
        if (!await confirmDeleteComment(context) || !mounted) return false;
        return provider.deleteComment(widget.postId, comment.id);
      },
    );
  }

  void _showPostOptionsSheet(Post post) {
    final currentUser = context.read<UserProvider>().currentUser;
    final isMyPost = currentUser != null && post.authorId == currentUser.id;

    BoardOptionsHandler.showPostOptionsSheet(
      context: context,
      post: post,
      isMyPost: isMyPost,
      onEdit: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BoardWriteScreen(editPost: post),
          ),
        );
      },
      onDelete: () async {
        final provider = context.read<CommunityProvider>();
        if (!await confirmDeletePost(context, kind: '글') || !mounted) {
          return false;
        }
        return provider.deletePost(post.id);
      },
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = colorScheme.surface;
    final likeAccent = context.tokens.primary; // blue[600] 느낌
    const scrapAccent = AppColors.communityScrapAccent; // 부드러운 노랑 느낌
    final sendAccent = context.tokens.primary;

    final provider = context.watch<CommunityProvider>();
    final liked = provider.isCurrentPostLiked;
    final scrapped = provider.isCurrentPostScrapped;

    // 지워졌거나 못 여는 글은 가짜 글로 그리지 않는다(5차). 전에는 제목이
    // 없는 글을 글처럼 보여 줘서 공감·스크랩·댓글칸이
    // 그대로 살아 있었다.
    final found = provider.posts.where((p) => p.id == widget.postId).toList();
    final post = found.isEmpty ? null : found.first;

    final comments = provider.currentPostComments;
    if (_isFetchingDetails) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: likeAccent),
        ),
      );
    }

    if (post == null) {
      return const MissingPostView(boardType: 'board', appBarTitle: '게시판');
    }

    final currentUser = context.watch<UserProvider>().currentUser;
    final isMe = currentUser != null && post.authorId == currentUser.id;
    final cachedAuthor = provider.getCachedUser(post.authorId);

    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '뒤로',
                    onPressed: () => Navigator.maybePop(context),
                    icon:
                        const Icon(Icons.arrow_back_ios_new_rounded, size: 24),
                  ),
                  // 질문('질문')·투표('투표') 상세에는 제목이 있는데 여기만
                  // 없었다. 스크롤을 내리면 어느 탭의 글을 보는 중인지 알 수
                  // 없었다(5차).
                  Text(
                    '게시판',
                    style: context.texts.titleMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurface),
                  ),
                  const Spacer(),
                  // 글별 알림 끄기 버튼은 뺐다(5차). 기능이 없어 흐린 종 아이콘만
                  // 있었고, 글자도 없어 무엇인지 알 수 없었다(원칙 3·5).
                  IconButton(
                    tooltip: '글 옵션',
                    onPressed: () => _showPostOptionsSheet(post),
                    icon: const Icon(Icons.more_vert_rounded, size: 24),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 28),
                    BoardPostMetaRow(post: post),
                    const SizedBox(height: 26),
                    BoardPostAuthorRow(
                      post: post,
                      currentUser: currentUser,
                      cachedAuthor: cachedAuthor,
                      isMe: isMe,
                      timeAgoText:
                          '${formatCommunityTimeAgo(post.createdAt)}${post.editHistory.isNotEmpty ? ' (수정됨)' : ''}',
                    ),
                    const SizedBox(height: 28),
                    BoardPostContentSection(post: post),
                    const SizedBox(height: 44),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        BoardActionTile(
                          icon:
                              liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                          label: '공감',
                          count: post.likeCount,
                          selected: liked,
                          accentColor: likeAccent,
                          onTap: () {
                            final user =
                                context.read<UserProvider>().currentUser;
                            if (user == null) {
                              showToast(communityLoginRequiredText);
                              return;
                            }
                            provider.toggleLike(widget.postId, user.id);
                          },
                        ),
                        const SizedBox(width: AppSpacing.md),
                        BoardActionTile(
                          icon: scrapped
                              ? Icons.bookmark
                              : Icons.bookmark_outline,
                          label: '스크랩',
                          selected: scrapped,
                          accentColor: scrapAccent,
                          onTap: () {
                            final user =
                                context.read<UserProvider>().currentUser;
                            if (user == null) {
                              showToast(communityLoginRequiredText);
                              return;
                            }
                            provider.toggleScrap(widget.postId, user.id);
                          },
                        ),
                      ],
                    ),
                    BoardCommentsSection(
                      comments: comments,
                      postAuthorId: post.authorId,
                      postId: widget.postId,
                      onFocusCommentInput: _focusCommentInput,
                      onCommentMore: _showCommentOptionsSheet,
                      formatTimeAgo: formatCommunityTimeAgo,
                    ),
                    const SizedBox(height: 280),
                  ],
                ),
              ),
            ),
            BoardCommentInputBar(
              replyingTo: provider.replyingTo,
              onCancelReply: () => provider.setReplyingTo(null),
              controller: _commentController,
              focusNode: _commentFocusNode,
              onFocusInput: _focusCommentInput,
              onChanged: (_) => setState(() {}),
              onSubmit: _submitComment,
              onBlocked: () => showToast(commentBlockedReason(
                    hasText: _canSubmitComment,
                    replying: provider.replyingTo != null,
                  ) ??
                  ''),
              canSubmit: _canSubmitComment,
              sendAccent: sendAccent,
              backgroundColor: backgroundColor,
            ),
          ],
        ),
      ),
    );
  }
}
