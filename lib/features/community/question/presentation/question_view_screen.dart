import 'package:flutter/material.dart';
import 'package:parrokit/features/community/shell/presentation/utils/community_post_ui_utils.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/features/community/board/presentation/board_write_screen.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/data/models/comment.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/community_block_actions.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/community_options_sheet.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

class QuestionViewScreen extends StatefulWidget {
  final String questionId;

  const QuestionViewScreen({super.key, required this.questionId});

  @override
  State<QuestionViewScreen> createState() => _QuestionViewScreenState();
}

class _QuestionViewScreenState extends State<QuestionViewScreen> {
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  bool _isFetchingDetails = true;
  bool _isAccepting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = context.read<UserProvider>().currentUser;
      final provider = context.read<CommunityProvider>();

      await Future.wait([
        provider.fetchPostDetails(widget.questionId),
        provider.fetchComments(widget.questionId, currentUserId: user?.id),
        provider.loadUserActions(widget.questionId, userId: user?.id),
      ]);

      provider.incrementViewCount(widget.questionId, userId: user?.id);

      if (mounted) {
        setState(() {
          _isFetchingDetails = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocusNode.dispose();
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

  void _submitReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    final currentUser = context.read<UserProvider>().currentUser;
    if (currentUser == null) {
      showToast('로그인이 필요합니다.');
      return;
    }

    _replyController.clear();
    _replyFocusNode.unfocus();

    final provider = context.read<CommunityProvider>();
    final success = await provider.addComment(
      widget.questionId,
      text,
      authorId: currentUser.id,
      authorNickname: currentUser.displayName ?? '익명',
      authorAvatarUrl: currentUser.photoUrl,
    );

    if (success) {
      _scrollToBottom();
    } else if (mounted) {
      // 미리 비우는 건 반응이 빨라 보이려는 것이지, 실패했을 때 사용자가
      // 다시 타이핑해야 한다는 뜻은 아니다. 쓴 글을 돌려준다.
      _replyController.text = text;
      showToast(provider.errorMessage ?? '답글 등록에 실패했습니다.');
    }
  }

  void _acceptAnswer(Post question, Comment comment) async {
    final currentUser = context.read<UserProvider>().currentUser;
    if (currentUser == null) return;

    if (question.questionStatus == 'resolved') {
      showToast('이미 채택된 질문입니다.');
      return;
    }
    if (question.questionStatus == 'expired') {
      showToast('마감 기한이 지난 질문입니다.');
      return;
    }

    // 채택 확인 팝업
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('답변 채택'),
        content: Text(
            '이 답변을 채택하시겠습니까?\n채택 시 ${question.rewardCrackers} 크래커가 송금됩니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('채택하기',
                style: TextStyle(
                    color: context.tokens.primary,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    setState(() => _isAccepting = true);

    final provider = context.read<CommunityProvider>();
    final success = await provider.acceptAnswer(
      postId: widget.questionId,
      commentId: comment.id,
      answererId: comment.authorId,
      rewardCrackers: question.rewardCrackers,
    );

    if (!mounted) return;
    setState(() => _isAccepting = false);

    if (success) {
      showToast('채택이 완료되었습니다! 🍪');
    } else {
      showToast(provider.errorMessage ?? '채택 처리에 실패했습니다.');
    }
  }

  Future<void> _showQuestionOptionsSheet(Post question) async {
    final currentUser = context.read<UserProvider>().currentUser;
    final isMyPost = currentUser != null && question.authorId == currentUser.id;

    await showCommunityOptionsSheet(
      context: context,
      title: '질문 옵션',
      actions: [
        if (isMyPost)
          CommunityOptionAction(
            label: '수정',
            icon: Icons.edit_outlined,
            onTap: () async {
              if (!mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BoardWriteScreen(editPost: question),
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
              final deleted = await context
                  .read<CommunityProvider>()
                  .deletePost(question.id);
              if (!mounted) return;
              if (deleted) {
                showToast('질문이 삭제되었습니다.');
                Navigator.maybePop(context);
              } else {
                showToast('삭제에 실패했습니다.');
              }
            },
          ),
        if (!isMyPost)
          buildCommunityBlockAction(
            context: context,
            targetUid: question.authorId,
            targetDisplayName: question.authorNickname,
          ),
        if (!isMyPost)
          CommunityOptionAction(
            label: '신고',
            icon: Icons.report_outlined,
            onTap: () async {
              showToast('신고가 접수되었습니다.');
            },
          ),
      ],
    );
  }

  Future<void> _showAnswerOptionsSheet(Post question, Comment answer) async {
    final currentUser = context.read<UserProvider>().currentUser;
    final isMyComment =
        currentUser != null && answer.authorId == currentUser.id;

    await showCommunityOptionsSheet(
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
                  .deleteComment(question.id, answer.id);
              if (!mounted) return;
              showToast(deleted ? '댓글이 삭제되었습니다.' : '삭제에 실패했습니다.');
            },
          ),
        if (!isMyComment)
          buildCommunityBlockAction(
            context: context,
            targetUid: answer.authorId,
            targetDisplayName: answer.authorNickname,
          ),
        if (!isMyComment)
          CommunityOptionAction(
            label: '신고',
            icon: Icons.report_outlined,
            onTap: () async {
              showToast('신고가 접수되었습니다.');
            },
          ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: colorScheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: colorScheme.onSurface, size: 20),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Text(
        '질문 스레드',
        style: context.texts.titleMedium.copyWith(color: colorScheme.onSurface),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: context.tokens.surfaceContainerHigh, height: 1),
      ),
    );
  }

  Widget _buildBody() {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = context.watch<CommunityProvider>();

    final questions = provider.posts.where((p) => p.id == widget.questionId);
    final question = questions.isNotEmpty ? questions.first : null;

    if (_isFetchingDetails) {
      return Center(
          child: CircularProgressIndicator(color: context.tokens.primary));
    }

    if (question == null) {
      return const Center(child: Text('질문을 찾을 수 없습니다.'));
    }

    final answers = provider.currentPostComments;

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildMainQuestionTweet(question, provider),
                    _buildDivider(),
                    _buildRepliesSection(question, answers),
                  ],
                ),
              ),
            ),
            _buildStickyReplyBar(),
          ],
        ),
        if (_isAccepting)
          Container(
            color: colorScheme.scrim.withValues(alpha: 0.3),
            child: Center(
                child:
                    CircularProgressIndicator(color: context.tokens.primary)),
          ),
      ],
    );
  }

  Widget _buildMainQuestionTweet(Post question, CommunityProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = context.read<UserProvider>().currentUser;
    final isMe = currentUser != null && question.authorId == currentUser.id;
    final authorName = isMe
        ? (currentUser.displayName ?? question.authorNickname)
        : (provider.getCachedUser(question.authorId)?.displayName ??
            question.authorNickname);

    final avatarUrl = isMe
        ? (currentUser.photoUrl ?? question.authorAvatarUrl)
        : (provider.getCachedUser(question.authorId)?.photoUrl ??
            question.authorAvatarUrl);

    final isLiked = provider.isCurrentPostLiked;
    final isBookmarked = provider.isCurrentPostScrapped;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: context.tokens.surfaceContainerHigh,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Icon(Icons.person, color: colorScheme.onSurfaceVariant)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          authorName,
                          style: context.texts.titleMedium
                              .copyWith(color: colorScheme.onSurface),
                        ),
                        if (question.questionStatus == 'resolved') ...[
                          const SizedBox(width: 4),
                          Icon(Icons.verified,
                              color: context.tokens.primary, size: 16),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (question.rewardCrackers > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.tokens.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                        color: context.tokens.primary.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🍪', style: context.texts.bodySmall),
                      const SizedBox(width: 4),
                      Text(
                        '${question.rewardCrackers}',
                        style: context.texts.labelMedium
                            .copyWith(color: context.tokens.primary),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                color: colorScheme.onSurfaceVariant,
                onPressed: () => _showQuestionOptionsSheet(question),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            question.title,
            style: context.texts.titleLarge
                .copyWith(color: colorScheme.onSurface, height: 1.35),
          ),
          const SizedBox(height: 12),
          Text(
            question.content,
            style: context.texts.titleMedium
                .copyWith(color: colorScheme.onSurface, height: 1.5),
          ),
          const SizedBox(height: 16),
          if (question.hasImage && question.imageUrls.isNotEmpty)
            Container(
              width: double.infinity,
              height: 250,
              color: colorScheme.surfaceContainerHigh,
              margin: const EdgeInsets.only(bottom: 12),
              child: Image.network(
                question.imageUrls.first,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.image_not_supported,
                    color: colorScheme.onSurfaceVariant),
              ),
            ),
          Text(
            '${formatCommunityTimeAgo(question.createdAt)} · 조회 ${question.viewCount}회',
            style: context.texts.bodyMedium
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
          Divider(
              height: 24, color: colorScheme.onSurface.withValues(alpha: 0.08)),
          Row(
            children: [
              Text('${question.likeCount}',
                  style: context.texts.bodyMedium
                      .copyWith(color: colorScheme.onSurface)),
              const SizedBox(width: 4),
              Text('유용해요',
                  style: context.texts.bodyMedium
                      .copyWith(color: colorScheme.onSurface)),
              const SizedBox(width: 16),
              Text('${question.commentCount}',
                  style: context.texts.bodyMedium
                      .copyWith(color: colorScheme.onSurface)),
              const SizedBox(width: 4),
              Text('답글',
                  style: context.texts.bodyMedium
                      .copyWith(color: colorScheme.onSurface)),
            ],
          ),
          Divider(
              height: 24, color: colorScheme.onSurface.withValues(alpha: 0.08)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: Icon(Icons.mode_comment_outlined,
                    size: 20, color: context.tokens.textSecondary),
                onPressed: () =>
                    FocusScope.of(context).requestFocus(_replyFocusNode),
              ),
              IconButton(
                // 글 공감은 엄지(예전엔 번개였다). 게시판과 같게.
                icon: Icon(isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    size: 22,
                    color: isLiked
                        ? context.tokens.primary
                        : context.tokens.textSecondary),
                onPressed: () => context
                    .read<CommunityProvider>()
                    .toggleLike(question.id, currentUser?.id ?? ''),
              ),
              IconButton(
                icon: Icon(
                    isBookmarked
                        ? Icons.bookmark
                        : Icons.bookmark_border_rounded,
                    size: 20,
                    color: isBookmarked
                        ? context.tokens.primary
                        : context.tokens.textSecondary),
                onPressed: () => context
                    .read<CommunityProvider>()
                    .toggleScrap(question.id, currentUser?.id ?? ''),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
        height: 8, color: colorScheme.onSurface.withValues(alpha: 0.1));
  }

  Widget _buildRepliesSection(Post question, List<Comment> answers) {
    final colorScheme = Theme.of(context).colorScheme;
    if (answers.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text('아직 답변이 없습니다.\n첫 번째 답변을 남겨보세요!',
              textAlign: TextAlign.center,
              style: context.texts.bodyMedium
                  .copyWith(color: context.tokens.textDisabled)),
        ),
      );
    }

    final parentAnswers = answers.where((c) => c.parentId == null).toList();
    final childAnswers = answers.where((c) => c.parentId != null).toList();

    parentAnswers
        .sort((a, b) => (b.isAccepted ? 1 : 0).compareTo(a.isAccepted ? 1 : 0));

    final List<Widget> widgets = [];
    for (var i = 0; i < parentAnswers.length; i++) {
      final parent = parentAnswers[i];
      widgets.add(_buildReplyItem(question, parent, isReply: false));

      final children =
          childAnswers.where((c) => c.parentId == parent.id).toList();
      for (var child in children) {
        widgets.add(_buildReplyItem(question, child, isReply: true));
      }

      if (i < parentAnswers.length - 1 || children.isNotEmpty) {
        widgets.add(Divider(
            height: 1, color: colorScheme.onSurface.withValues(alpha: 0.05)));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(color: colorScheme.surface, child: Column(children: widgets)),
      ],
    );
  }

  Widget _buildReplyItem(Post question, Comment answer,
      {bool isReply = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = context.read<UserProvider>().currentUser;
    final isMe = currentUser != null && question.authorId == currentUser.id;
    final provider = context.read<CommunityProvider>();
    final isBlocked = provider.isAuthorBlocked(answer.authorId);

    final answererName = (answer.authorId == currentUser?.id)
        ? (currentUser?.displayName ?? answer.authorNickname)
        : (provider.getCachedUser(answer.authorId)?.displayName ??
            answer.authorNickname);

    final answererAvatar = (answer.authorId == currentUser?.id)
        ? (currentUser?.photoUrl ?? answer.authorAvatarUrl)
        : (provider.getCachedUser(answer.authorId)?.photoUrl ??
            answer.authorAvatarUrl);

    final isAdopted = answer.isAccepted;

    return Container(
      padding: EdgeInsets.fromLTRB(isReply ? 16 + 18 + 12 : 16, 16, 16, 16),
      decoration: BoxDecoration(
        color: isReply ? Colors.transparent : colorScheme.surface,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: isReply ? 14 : 18,
                backgroundColor: context.tokens.surfaceContainerHigh,
                backgroundImage: (!isBlocked && answererAvatar != null)
                    ? NetworkImage(answererAvatar)
                    : null,
                child: answererAvatar == null || isBlocked
                    ? Icon(isBlocked ? Icons.block_rounded : Icons.person,
                        size: isReply ? 14 : 18,
                        color: colorScheme.onSurfaceVariant)
                    : null,
              ),
              if (!isReply)
                Container(
                    width: 2,
                    height: 40,
                    color: colorScheme.onSurface.withValues(alpha: 0.2)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(isBlocked ? '차단한 사용자' : answererName,
                        style: context.texts.bodyLarge
                            .copyWith(color: colorScheme.onSurface)),
                    const Spacer(),
                    if (!isBlocked) ...[
                      Text(formatCommunityTimeAgo(answer.createdAt),
                          style: context.texts.bodySmall
                              .copyWith(color: colorScheme.onSurfaceVariant)),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded, size: 18),
                        color: colorScheme.onSurfaceVariant,
                        onPressed: () =>
                            _showAnswerOptionsSheet(question, answer),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (isAdopted) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.tokens.primarySoft,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color:
                              context.tokens.primary.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified,
                            color: context.tokens.primary, size: 12),
                        const SizedBox(width: 4),
                        Text('채택된 답변',
                            style: context.texts.labelSmall
                                .copyWith(color: context.tokens.primary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                if (isReply && answer.replyToNickname != null && !isBlocked)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '@${answer.replyToNickname}',
                      style: context.texts.bodyMedium
                          .copyWith(color: context.tokens.primary),
                    ),
                  ),
                Text(
                  isBlocked ? '차단된 사용자의 답변입니다.' : answer.content,
                  style: context.texts.bodyLarge
                      .copyWith(color: colorScheme.onSurface, height: 1.45),
                ),
                const SizedBox(height: 12),
                if (!isBlocked)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                              icon: Icon(
                                  // 답변(댓글) 좋아요는 하트(투표 댓글과 같게).
                                  provider.likedCommentIds.contains(answer.id)
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 18,
                                  color: provider.likedCommentIds
                                          .contains(answer.id)
                                      ? context.tokens.danger
                                      : context.tokens.textSecondary),
                              onPressed: () {
                                if (currentUser != null) {
                                  provider.toggleCommentLike(
                                      question.id, answer.id, currentUser.id);
                                } else {
                                  showToast('로그인이 필요합니다.');
                                }
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints()),
                          const SizedBox(width: 4),
                          Text('${answer.likeCount}',
                              style: context.texts.bodySmall.copyWith(
                                  color: colorScheme.onSurfaceVariant)),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: Icon(Icons.mode_comment_outlined,
                                size: 18, color: context.tokens.textSecondary),
                            onPressed: () {
                              provider.setReplyingTo(answer);
                              FocusScope.of(context)
                                  .requestFocus(_replyFocusNode);
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      if (!isReply &&
                          isMe &&
                          question.questionStatus == 'waiting' &&
                          answer.authorId != currentUser.id)
                        GestureDetector(
                          onTap: () => _acceptAnswer(question, answer),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: context.tokens.primarySoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('채택하기',
                                style: context.texts.bodySmall
                                    .copyWith(color: context.tokens.primary)),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyReplyBar() {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = context.watch<UserProvider>().currentUser;
    final provider = context.watch<CommunityProvider>();
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
            top: BorderSide(
                color: colorScheme.onSurface.withValues(alpha: 0.12))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (provider.replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: colorScheme.surfaceContainerHigh,
              child: Row(
                children: [
                  Text(
                    '${provider.replyingTo!.authorNickname}님에게 답글 남기는 중',
                    style: context.texts.labelMedium
                        .copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      provider.setReplyingTo(null);
                    },
                    child: Icon(Icons.close,
                        size: 16, color: context.tokens.textDisabled),
                  ),
                ],
              ),
            ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: context.tokens.surfaceContainerHigh,
                    backgroundImage: currentUser?.photoUrl != null
                        ? NetworkImage(currentUser!.photoUrl!)
                        : null,
                    child: currentUser?.photoUrl == null
                        ? Icon(Icons.person,
                            size: 14, color: colorScheme.onSurfaceVariant)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      focusNode: _replyFocusNode,
                      decoration: InputDecoration(
                        hintText: '답글 남기기...',
                        hintStyle: context.texts.bodyMedium
                            .copyWith(color: colorScheme.onSurfaceVariant),
                        border: InputBorder.none,
                      ),
                      style: context.texts.bodyMedium
                          .copyWith(color: colorScheme.onSurface),
                    ),
                  ),
                  TextButton(
                    onPressed: _submitReply,
                    child: Text('답글',
                        style: context.texts.bodyMedium
                            .copyWith(color: context.tokens.primary)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
