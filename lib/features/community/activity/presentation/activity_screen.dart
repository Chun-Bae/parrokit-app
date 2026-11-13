import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'providers/activity_provider.dart';
import 'widgets/activity_card.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

class CommunityActivityScreen extends StatefulWidget {
  const CommunityActivityScreen({
    super.key,
    required this.boardType,
    required this.activityType,
    this.activityProviderFactory,
  });

  final String boardType;
  final String activityType;
  final ActivityProvider Function()? activityProviderFactory;

  @override
  State<CommunityActivityScreen> createState() =>
      _CommunityActivityScreenState();
}

class _CommunityActivityScreenState extends State<CommunityActivityScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _getAppBarTitle() {
    String boardName = '';
    switch (widget.boardType) {
      case 'board':
        // 탭 이름이 '게시판'이라 '일반'을 뺐다(5차, 알림·내 활동 칩과 같게).
        boardName = '게시판';
        break;
      case 'question':
        boardName = '질문 게시판';
        break;
      case 'vote':
        boardName = '투표 게시판';
        break;
      default:
        boardName = '알 수 없음';
    }

    String activityName = '';
    switch (widget.activityType) {
      case 'written':
        activityName = '작성한 글';
        break;
      case 'written_posted':
        activityName = '게시한 투표';
        break;
      case 'commented':
        activityName = '작성한 댓글';
        break;
      case 'liked':
        activityName = '공감한 글';
        break;
      case 'liked_comment':
        activityName = '공감한 댓글';
        break;
      case 'scraped':
        activityName = '스크랩';
        break;
      default:
        activityName = '활동';
    }

    if (widget.boardType == 'vote' && widget.activityType == 'written') {
      activityName = '참여한 투표';
    }
    if (widget.boardType == 'question' && widget.activityType == 'written') {
      activityName = '작성한 질문/답변';
    }

    return '$boardName - $activityName';
  }

  String _getTotalCountLabel(int count) {
    String typeLabel = '';
    switch (widget.activityType) {
      case 'written':
      case 'written_posted':
        typeLabel = '글';
        if (widget.boardType == 'vote') typeLabel = '투표';
        if (widget.boardType == 'question') typeLabel = '질문/답변';
        break;
      case 'commented':
      case 'commented_reply':
        typeLabel = '댓글';
        break;
      case 'liked':
      case 'liked_comment':
        typeLabel = '공감';
        break;
      case 'scraped':
        typeLabel = '스크랩';
        break;
      default:
        typeLabel = '활동';
    }
    return '총 $typeLabel $count개';
  }

  String? _resolveDetailPath(String boardType, String postId) {
    if (postId.isEmpty) return null;
    switch (boardType) {
      case 'question':
        return AppRoutes.communityQuestionViewPathOf(postId);
      case 'vote':
        return AppRoutes.communityVoteViewPathOf(postId);
      case 'board':
      default:
        return AppRoutes.communityBoardViewPathOf(postId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.currentUser?.id ?? '';

    return ChangeNotifierProvider(
      create: (context) =>
          (widget.activityProviderFactory?.call() ?? ActivityProvider())
            ..fetchActivities(
              userId: userId,
              boardType: widget.boardType,
              activityType: widget.activityType,
            ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _getAppBarTitle(),
            style: context.texts.titleLarge,
          ),
          centerTitle: true,
        ),
        body: Consumer<ActivityProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.activities.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.error != null) {
              return Center(
                child: Text('오류가 발생했습니다: ${provider.error}',
                    style: TextStyle(color: colorScheme.error)),
              );
            }

            if (provider.activities.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_rounded,
                        size: 64, color: context.tokens.textDisabled),
                    const SizedBox(height: 16),
                    Text(
                      '아직 활동 내역이 없습니다.',
                      style: context.texts.titleMedium
                          .copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(color: colorScheme.outlineVariant),
                    ),
                  ),
                  child: Text(
                    _getTotalCountLabel(provider.activities.length),
                    style: context.texts.bodyMedium
                        .copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: provider.refresh,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.metrics.extentAfter <= 300) {
                          provider.loadMore();
                        }
                        return false;
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: provider.activities.length +
                            (provider.hasMore || provider.isLoadingMore
                                ? 1
                                : 0),
                        itemBuilder: (context, index) {
                          if (index >= provider.activities.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          }

                          final item = provider.activities[index];
                          return ActivityCard(
                            item: item,
                            onTap: () {
                              final path = _resolveDetailPath(
                                item.boardType,
                                item.sourcePostId,
                              );
                              if (path == null) return;
                              context.push(path);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
