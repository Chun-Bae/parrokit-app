import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/features/community/shell/domain/data/community_filters.dart';

import 'package:provider/provider.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

// ─── VoteScreen ────────────────────────────────────────────────────────────────
class VoteScreen extends StatefulWidget {
  final String selectedFilter;
  final bool swipeEnabled;
  const VoteScreen(
      {super.key, required this.selectedFilter, this.swipeEnabled = true});

  @override
  State<VoteScreen> createState() => _VoteScreenState();
}

class _VoteScreenState extends State<VoteScreen> {
  int _currentCardIndex = 0;
  final Map<String, bool> _showResultsByPostId = {};

  final Set<String> _votedOnlyPostIds = {};
  int _voteSyncToken = 0;
  bool _isVoteStateReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<CommunityProvider>();
      await provider.fetchPosts(postType: 'vote', refresh: true);
      await _syncVoteState(
          loadVotedPosts: widget.selectedFilter == CommunityFilters.vote[2]);
      if (!mounted) return;
      setState(() {
        _isVoteStateReady = true;
      });
    });
  }

  @override
  void didUpdateWidget(covariant VoteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedFilter != widget.selectedFilter) {
      setState(() {
        _currentCardIndex = 0;
        _showResultsByPostId.clear();
        _isVoteStateReady = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _syncVoteState(
            loadVotedPosts: widget.selectedFilter == CommunityFilters.vote[2]);
        if (!mounted) return;
        setState(() {
          _isVoteStateReady = true;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    if (!_isVoteStateReady) {
      return const Center(child: CircularProgressIndicator());
    }
    final posts = _visibleVotePosts(provider);

    if (provider.isLoading && posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (posts.isEmpty) {
      return const Center(child: Text('진행 중인 투표가 없습니다.'));
    }

    return RefreshIndicator(
      onRefresh: _refreshVotes,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeOut,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: widget.selectedFilter == CommunityFilters.vote[0]
            ? _buildRandomView(posts, key: const ValueKey('random'))
            : _buildListView(posts,
                key: ValueKey('list_${widget.selectedFilter}')),
      ),
    );
  }

  Future<void> _refreshVotes() async {
    final provider = context.read<CommunityProvider>();
    await provider.fetchPosts(postType: 'vote', refresh: true);
    if (!mounted) return;
    setState(() {
      _currentCardIndex = 0;
      _showResultsByPostId.clear();
    });
    await _syncVoteState(
        loadVotedPosts: widget.selectedFilter == CommunityFilters.vote[2]);
  }

  Future<void> _syncVoteState({required bool loadVotedPosts}) async {
    if (!mounted) return;
    final token = ++_voteSyncToken;
    final user = context.read<UserProvider>().currentUser;
    if (user == null) {
      if (!mounted || token != _voteSyncToken) return;
      setState(() {
        _votedOnlyPostIds.clear();
      });
      return;
    }
    final provider = context.read<CommunityProvider>();
    final votedSet = await provider.getVotedPostIdSet(user.id);
    if (loadVotedPosts) {
      await provider.ensureVotedPostsLoaded(user.id);
    }
    await provider.fetchMyVotes(user.id);
    final votePostIds = provider.posts
        .where((p) => p.postType == 'vote')
        .map((p) => p.id)
        .toList();
    await provider.loadUserActionsForPosts(votePostIds, userId: user.id);
    if (!mounted || token != _voteSyncToken) return;
    setState(() {
      _votedOnlyPostIds
        ..clear()
        ..addAll(votedSet);
    });
  }

  // ── 랜덤 보기 (스와이프) ─────────────────────────────────────────────────────
  Widget _buildRandomView(List<Post> posts, {Key? key}) {
    final provider = context.watch<CommunityProvider>();
    if (_currentCardIndex >= posts.length) {
      return Center(
        key: key,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🎉', style: context.texts.displaySmall),
            const SizedBox(height: 16),
            Text('모든 투표를 확인했어요!', style: context.texts.titleLarge),
            const SizedBox(height: 8),
            Text('새 투표가 올라오면 알려드릴게요',
                style: context.texts.bodyMedium.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.45))),
            const SizedBox(height: 28),
            OutlinedButton(
              onPressed: () => setState(() {
                _currentCardIndex = 0;
                _showResultsByPostId.clear();
              }),
              child: const Text('처음부터 다시 보기'),
            ),
          ],
        ),
      );
    }

    return Column(
      key: key,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(maxHeight: constraints.maxHeight - 16),
                    child: _SwipeableCard(
                      key: ValueKey(posts[_currentCardIndex].id),
                      enabled: widget.swipeEnabled,
                      onDismiss: () => setState(() => _currentCardIndex++),
                      child: GestureDetector(
                        onTap: () {
                          context.push(AppRoutes.communityVoteViewPathOf(
                              posts[_currentCardIndex].id));
                        },
                        child: VoteCard(
                          item: posts[_currentCardIndex],
                          selectedOption: context
                              .watch<CommunityProvider>()
                              .myVotes[posts[_currentCardIndex].id],
                          showResult: _showResultsByPostId[
                                  posts[_currentCardIndex].id] ??
                              false,
                          showToggleResultButton: false,
                          enablePostActions: true,
                          isPostLiked:
                              provider.isPostLiked(posts[_currentCardIndex].id),
                          isPostScrapped: provider
                              .isPostScrapped(posts[_currentCardIndex].id),
                          onTogglePostLike: () {
                            final user =
                                context.read<UserProvider>().currentUser;
                            if (user == null) return;
                            context.read<CommunityProvider>().toggleLike(
                                posts[_currentCardIndex].id, user.id);
                          },
                          onTogglePostScrap: () {
                            final user =
                                context.read<UserProvider>().currentUser;
                            if (user == null) return;
                            context.read<CommunityProvider>().toggleScrap(
                                posts[_currentCardIndex].id, user.id);
                          },
                          showMoreButton: false,
                          onSelect: (idx) {
                            _submitVote(
                              postId: posts[_currentCardIndex].id,
                              optionIndex: idx,
                            );
                          },
                          onToggleResult: () => setState(() {
                            final postId = posts[_currentCardIndex].id;
                            _showResultsByPostId[postId] =
                                !(_showResultsByPostId[postId] ?? false);
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _NavButton(
                icon: Icons.arrow_back_ios_new_rounded,
                enabled: _currentCardIndex > 0,
                onTap: _currentCardIndex > 0
                    ? () => setState(() => _currentCardIndex--)
                    : null,
              ),
              const SizedBox(width: 36),
              _NavButton(
                icon: Icons.arrow_forward_ios_rounded,
                enabled: _currentCardIndex < posts.length,
                onTap: _currentCardIndex < posts.length
                    ? () => setState(() => _currentCardIndex++)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 한눈에 보기 (리스트) ─────────────────────────────────────────────────────
  Widget _buildListView(List<Post> posts, {Key? key}) {
    final provider = context.watch<CommunityProvider>();
    return ListView.builder(
      key: key,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: posts.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GestureDetector(
          onTap: () {
            context.push(AppRoutes.communityVoteViewPathOf(posts[i].id));
          },
          child: VoteCard(
            item: posts[i],
            selectedOption:
                context.watch<CommunityProvider>().myVotes[posts[i].id],
            showResult: _showResultsByPostId[posts[i].id] ?? false,
            showToggleResultButton: false,
            enablePostActions: true,
            isPostLiked: provider.isPostLiked(posts[i].id),
            isPostScrapped: provider.isPostScrapped(posts[i].id),
            onTogglePostLike: () {
              final user = context.read<UserProvider>().currentUser;
              if (user == null) return;
              context
                  .read<CommunityProvider>()
                  .toggleLike(posts[i].id, user.id);
            },
            onTogglePostScrap: () {
              final user = context.read<UserProvider>().currentUser;
              if (user == null) return;
              context
                  .read<CommunityProvider>()
                  .toggleScrap(posts[i].id, user.id);
            },
            showMoreButton: false,
            onSelect: (idx) {
              _submitVote(
                postId: posts[i].id,
                optionIndex: idx,
              );
            },
            onToggleResult: () => setState(() {
              final postId = posts[i].id;
              _showResultsByPostId[postId] =
                  !(_showResultsByPostId[postId] ?? false);
            }),
          ),
        ),
      ),
    );
  }

  List<Post> _visibleVotePosts(CommunityProvider provider) {
    final now = DateTime.now();
    return provider.posts.where((post) {
      if (post.postType != 'vote') return false;
      final isExpired =
          post.voteEndTime != null && post.voteEndTime!.isBefore(now);
      if (widget.selectedFilter == CommunityFilters.vote[3]) {
        return isExpired;
      }
      if (widget.selectedFilter == CommunityFilters.vote[2]) {
        return _votedOnlyPostIds.contains(post.id);
      }
      if (isExpired) return false;
      return !_votedOnlyPostIds.contains(post.id);
    }).toList();
  }

  Future<void> _submitVote({
    required String postId,
    required int optionIndex,
  }) async {
    final user = context.read<UserProvider>().currentUser;
    if (user == null) return;

    final success = await context.read<CommunityProvider>().votePost(
          postId,
          optionIndex,
          user.id,
        );
    if (!mounted || !success) return;

    setState(() {
      _votedOnlyPostIds.add(postId);
    });
  }
}

class _SwipeableCard extends StatefulWidget {
  const _SwipeableCard({
    super.key,
    required this.child,
    required this.onDismiss,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onDismiss;
  final bool enabled;

  @override
  State<_SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<_SwipeableCard> {
  double _dx = 0;
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: widget.enabled
          ? (details) => setState(() => _dx += details.delta.dx)
          : null,
      onHorizontalDragEnd: widget.enabled
          ? (_) {
              if (_dx.abs() > 110) {
                setState(() => _dismissed = true);
                Future.delayed(const Duration(milliseconds: 180), () {
                  if (!mounted) return;
                  widget.onDismiss();
                });
              } else {
                setState(() => _dx = 0);
              }
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..translateByDouble(_dismissed ? (_dx.sign * 420) : _dx, 0, 0, 1)
          ..rotateZ((_dx / 1200).clamp(-0.08, 0.08)),
        child: widget.child,
      ),
    );
  }
}

// ─── 네비게이션 버튼 (원형) ──────────────────────────────────────────────────────
class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.3,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color:
                enabled ? context.tokens.textPrimary : context.tokens.disabled,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color:
                enabled ? context.tokens.surface : context.tokens.textDisabled,
          ),
        ),
      ),
    );
  }
}

// ─── 투표 카드 (이미지 1:1 매치, 테두리 없음) ──────────────────────────────────
class VoteCard extends StatelessWidget {
  final Post item;
  final int? selectedOption;
  final bool showResult;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggleResult;
  final bool showToggleResultButton;
  final bool enablePostActions;
  final bool isPostLiked;
  final bool isPostScrapped;
  final VoidCallback? onTogglePostLike;
  final VoidCallback? onTogglePostScrap;
  final VoidCallback? onMorePressed;
  final bool showMoreButton;

  const VoteCard({
    super.key,
    required this.item,
    required this.selectedOption,
    required this.showResult,
    required this.onSelect,
    required this.onToggleResult,
    this.showToggleResultButton = true,
    this.enablePostActions = false,
    this.isPostLiked = false,
    this.isPostScrapped = false,
    this.onTogglePostLike,
    this.onTogglePostScrap,
    this.onMorePressed,
    this.showMoreButton = true,
  });

  String _formatTimeAgo(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) return '${diff.inDays}일 전';
    if (diff.inHours > 0) return '${diff.inHours}시간 전';
    if (diff.inMinutes > 0) return '${diff.inMinutes}분 전';
    return '방금 전';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int totalVotes =
        item.voteOptions?.fold(0, (sum, opt) => sum! + opt.count) ?? 0;

    // 남은 시간 계산
    String expiresInText = '';
    if (item.voteEndTime != null) {
      final diff = item.voteEndTime!.difference(DateTime.now());
      if (diff.isNegative) {
        expiresInText = '투표 종료';
      } else if (diff.inDays > 0) {
        expiresInText = '${diff.inDays}일 후 종료!';
      } else if (diff.inHours > 0) {
        expiresInText = '${diff.inHours}시간 ${diff.inMinutes % 60}분 후 종료!';
      } else {
        expiresInText = '${diff.inMinutes}분 후 종료!';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? context.tokens.surfaceContainerHigh
            : context.tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.45),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.18),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 타이머 + 메뉴 ──
            Row(
              children: [
                const Spacer(),
                Text(
                  expiresInText,
                  style: context.texts.labelMedium
                      .copyWith(color: context.tokens.primary),
                ),
                const Spacer(),
                if (showMoreButton)
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded, size: 22),
                    color: cs.onSurfaceVariant,
                    onPressed: onMorePressed,
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
            const SizedBox(height: 14),

            // ── 작성자 행 ──
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: cs.surfaceContainerHigh,
                  child: Icon(Icons.person, color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.authorNickname,
                          style: context.texts.bodyLarge
                              .copyWith(color: cs.onSurface)),
                      Text(
                          item.createdAt != null
                              ? _formatTimeAgo(item.createdAt!)
                              : '',
                          style: context.texts.bodySmall
                              .copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Text(
                  '$totalVotes명 참여',
                  style: context.texts.labelMedium
                      .copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── 제목 ──
            Text(
              item.title,
              style: context.texts.titleMedium
                  .copyWith(color: cs.onSurface, height: 1.3),
            ),
            const SizedBox(height: 6),

            // ── 설명 ──
            Text(
              item.content,
              style: context.texts.bodyMedium
                  .copyWith(color: cs.onSurface, height: 1.45),
            ),
            const SizedBox(height: 20),

            // ── 옵션 or 결과 ──
            !(showResult || selectedOption != null)
                ? _buildOptions(context, cs)
                : _buildResults(context, cs, totalVotes),
            const SizedBox(height: 16),

            // ── 결과 보기 / 리셋 버튼 ──
            if (showToggleResultButton && selectedOption == null) ...[
              Center(
                child: SizedBox(
                  width: 180,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: onToggleResult,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.onSurface,
                      side: BorderSide(
                          color: cs.onSurface.withValues(alpha: 0.55),
                          width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: showResult
                        ? Icon(Icons.refresh_rounded,
                            color: cs.onSurface, size: 22)
                        : Text('결과 보기', style: context.texts.titleMedium),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── 좋아요 + 댓글 ──
            Row(
              children: [
                GestureDetector(
                  onTap: enablePostActions ? onTogglePostLike : null,
                  child: Icon(
                    isPostLiked ? Icons.favorite : Icons.favorite_border,
                    size: 24,
                    color: isPostLiked ? context.tokens.danger : cs.onSurface,
                  ),
                ),
                const SizedBox(width: 6),
                Text('${item.likeCount}', style: context.texts.bodyMedium),
                if (enablePostActions) ...[
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: onTogglePostScrap,
                    child: Icon(
                      isPostScrapped ? Icons.bookmark : Icons.bookmark_outline,
                      size: 22,
                      color: isPostScrapped
                          ? context.tokens.primary
                          : cs.onSurface,
                    ),
                  ),
                ],
                const SizedBox(width: 16),
                Icon(Icons.chat_bubble_outline, size: 22, color: cs.onSurface),
                const SizedBox(width: 6),
                Text('${item.commentCount}',
                    style:
                        context.texts.bodyMedium.copyWith(color: cs.onSurface)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptions(BuildContext context, ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = item.voteOptions ?? [];
    return Column(
      children: List.generate(options.length, (i) {
        final isSelected = selectedOption == i;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('투표 확인', style: context.texts.titleLarge),
                  content: Text(
                      '\'${options[i].text}\' 항목에 투표하시겠습니까?\n한 번 투표하면 수정할 수 없습니다.'),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('취소',
                          style: TextStyle(color: context.tokens.textTertiary)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onSelect(i);
                      },
                      child: Text('투표하기',
                          style: TextStyle(
                              color: cs.primary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
            child: Container(
              width: double.infinity,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primary
                    : (isDark ? cs.surfaceContainer : cs.surfaceContainerHigh),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                options[i].text,
                style: context.texts.titleMedium
                    .copyWith(color: isSelected ? Colors.white : cs.onSurface),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildResults(BuildContext context, ColorScheme cs, int totalVotes) {
    final options = item.voteOptions ?? [];
    return Column(
      children: List.generate(options.length, (i) {
        final pct = totalVotes == 0 ? 0.0 : options[i].count / totalVotes;
        final isSelected = selectedOption == i;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  options[i].text,
                  style: AppTextScale.bodyMedium.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? cs.primary : cs.onSurface),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 26,
                  decoration: BoxDecoration(
                    color: context.tokens.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: pct,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cs.primary
                            : cs.primary.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                  '${(pct * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: AppTextScale.bodyMedium.copyWith(
                      color: isSelected
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
