import 'package:parrokit/core/shared/utils/korean_josa.dart';
import 'package:flutter/material.dart';
import 'package:parrokit/features/community/menu/data/factories/community_menu_section_factory.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/features/community/activity/presentation/activity_empty_text.dart';
import 'package:parrokit/core/shared/widgets/app_empty_state.dart';
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

  /// 빈 화면에 적을 말. 메뉴에서 누른 줄 이름을 그대로 쓴다.
  String _emptyText() {
    final title =
        communityActivityTitle(widget.boardType, widget.activityType);
    if (title == null || title.isEmpty) return '아직 활동이 없어요.';
    return '아직 ${iGa(title)} 없어요.';
  }

  /// 왜 비었는지, 무엇을 하면 채워지는지 한 줄.
  String _emptyDescription() =>
      activityEmptyDescription(widget.boardType, widget.activityType);

  /// 쓰기 활동이면 글쓰기 화면 경로. 그 밖에는 null(버튼을 두지 않는다).
  String? _writePath() {
    if (widget.activityType != 'written' &&
        widget.activityType != 'written_posted') {
      return null;
    }
    switch (widget.boardType) {
      case 'board':
        return AppRoutes.communityBoardWritePath;
      case 'question':
        return AppRoutes.communityQuestionWritePath;
      case 'vote':
        // '참여한 투표'는 내가 쓴 투표가 아니라 참여한 것이라 버튼을 뺀다.
        return widget.activityType == 'written_posted'
            ? AppRoutes.communityVoteWritePath
            : null;
      default:
        return null;
    }
  }

  String _writeLabel() {
    switch (widget.boardType) {
      case 'question':
        return '질문하기';
      case 'vote':
        return '투표 만들기';
      default:
        return '글쓰기';
    }
  }

  String _getAppBarTitle() {
    String boardName = '';
    switch (widget.boardType) {
      case 'board':
        // 탭 이름이 '게시판'이라 '일반'을 뺐다(5차, 알림·내 활동 칩과 같게).
        boardName = '게시판';
        break;
      case 'question':
        // 메뉴 묶음 이름·탭과 같게(5차).
        boardName = '질문';
        break;
      case 'vote':
        boardName = '투표';
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
        // 글·질문은 엄지 '공감', 댓글·답변은 하트 '좋아요'다(89d57b67).
        // 메뉴와 화면이 '공감한 댓글'이라고 불러 버튼 이름과 어긋났다(5차).
        activityName = '좋아요한 댓글';
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
    // 메뉴에서 누른 줄과 같은 이름을 쓴다(5차).
    activityName =
        communityActivityTitle(widget.boardType, widget.activityType) ??
            activityName;

    return '$boardName - $activityName';
  }

  String _getTotalCountLabel(int count) {
    String typeLabel = '';
    switch (widget.activityType) {
      case 'written':
      case 'written_posted':
        typeLabel = '글';
        if (widget.boardType == 'vote') typeLabel = '투표';
        // 질문의 '작성한 질문'은 질문만 모은다(예전 '질문/답변').
        if (widget.boardType == 'question') typeLabel = '질문';
        break;
      case 'commented':
        typeLabel = widget.boardType == 'question' ? '답변' : '댓글';
        break;
      case 'commented_reply':
        typeLabel = '답글';
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
              // 내부 오류 글을 그대로 보여 주지 않는다(5차, 다른 화면과 같게).
              return Center(
                child: Text('불러오지 못했어요. 잠시 뒤 다시 열어 주세요.',
                    style: context.texts.bodyMedium
                        .copyWith(color: colorScheme.error)),
              );
            }

            if (provider.activities.isEmpty) {
              // 앱의 다른 빈 화면과 같은 모양으로(AppEmptyState). 무엇이
              // 없는지 말하고, 쓰기 활동이면 바로 쓰러 갈 길을 둔다(5차).
              // 전에는 글자 한 줄뿐이라 여기서 할 수 있는 일이 없었다.
              final writePath = _writePath();
              return AppEmptyState(
                icon: Icons.inbox_rounded,
                title: _emptyText(),
                description: _emptyDescription(),
                actionLabel: writePath == null ? null : _writeLabel(),
                onAction:
                    writePath == null ? null : () => context.push(writePath),
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
