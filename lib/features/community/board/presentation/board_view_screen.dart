import 'package:flutter/material.dart';
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

  String _formatTimeAgo(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) return '${diff.inDays}일 전';
    if (diff.inHours > 0) return '${diff.inHours}시간 전';
    if (diff.inMinutes > 0) return '${diff.inMinutes}분 전';
    return '방금 전';
  }

  void _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final currentUser = context.read<UserProvider>().currentUser;
    if (currentUser == null) {
      showToast('로그인이 필요합니다.');
      return;
    }

    _commentController.clear();
    _commentFocusNode.unfocus();

    final provider = context.read<CommunityProvider>();
    final success = await provider.addComment(
      widget.postId,
      text,
      authorId: currentUser.id,
      authorNickname: currentUser.displayName ?? '알 수 없음',
      authorAvatarUrl: currentUser.photoUrl,
    );

    if (success) {
      _scrollToBottom();
    } else if (mounted) {
      showToast(provider.errorMessage ?? '댓글 등록에 실패했습니다.');
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
    final currentUser = context.read<UserProvider>().currentUser;
    final isMyComment = currentUser != null && comment.authorId == currentUser.id;
    BoardOptionsHandler.showCommentOptionsSheet(
      context: context,
      isMyComment: isMyComment,
      blockedUserId: comment.authorId,
      blockedUserDisplayName: comment.authorNickname,
      onDelete: () async {
        final provider = context.read<CommunityProvider>();
        final colorScheme = Theme.of(context).colorScheme;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('댓글 삭제', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text('정말로 이 댓글을 삭제하시겠습니까?\n삭제 후에는 복구할 수 없습니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('취소', style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('삭제', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        if (confirm != true || !mounted) return false;
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
      onEdit: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => BoardWriteScreen(editPost: post)),
        );
      },
      onDelete: () async {
        final provider = context.read<CommunityProvider>();
        final colorScheme = Theme.of(context).colorScheme;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('게시글 삭제', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text('정말로 이 게시글을 삭제하시겠습니까?\n삭제 후에는 복구할 수 없습니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('취소', style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('삭제', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        if (confirm != true || !mounted) return false;
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
    const likeAccent = AppColors.primary; // blue[600] 느낌
    const scrapAccent = AppColors.communityScrapAccent; // 부드러운 노랑 느낌
    const sendAccent = AppColors.primary;

    final provider = context.watch<CommunityProvider>();
    final liked = provider.isCurrentPostLiked;
    final scrapped = provider.isCurrentPostScrapped;

    final likeMetaColor = liked ? likeAccent : AppColors.textDisabled;
    final likeIconColor = liked ? likeAccent : AppColors.textDisabled;

    final post = provider.posts.firstWhere(
      (p) => p.id == widget.postId,
      orElse: () => Post(
        id: widget.postId,
        postType: 'board',
        category: '알 수 없음',
        title: '게시글을 찾을 수 없습니다.',
        content: '삭제되었거나 접근할 수 없는 게시글입니다.',
        authorId: '',
        authorNickname: '알 수 없음',
        snippet: '',
        createdAt: DateTime.now(),
      ),
    );

    final currentUser = context.watch<UserProvider>().currentUser;
    final isMe = currentUser != null && post.authorId == currentUser.id;
    final cachedAuthor = provider.getCachedUser(post.authorId);

    final comments = provider.currentPostComments;
    if (_isFetchingDetails) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: likeAccent),
        ),
      );
    }

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
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 24),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon:
                        const Icon(Icons.notifications_off_outlined, size: 24),
                  ),
                  IconButton(
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
                    BoardPostMetaRow(
                      post: post,
                      likeMetaColor: likeMetaColor,
                      likeIconColor: likeIconColor,
                    ),
                    const SizedBox(height: 26),
                    BoardPostAuthorRow(
                      post: post,
                      currentUser: currentUser,
                      cachedAuthor: cachedAuthor,
                      isMe: isMe,
                      timeAgoText:
                          '${_formatTimeAgo(post.createdAt)}${post.editHistory.isNotEmpty ? ' (수정됨)' : ''}',
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
                          selected: liked,
                          accentColor: likeAccent,
                          onTap: () {
                            final user =
                                context.read<UserProvider>().currentUser;
                            if (user == null) {
                              showToast('로그인이 필요합니다.');
                              return;
                            }
                            provider.toggleLike(widget.postId, user.id);
                          },
                        ),
                        const SizedBox(width: 26),
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
                              showToast('로그인이 필요합니다.');
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
                      formatTimeAgo: _formatTimeAgo,
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
