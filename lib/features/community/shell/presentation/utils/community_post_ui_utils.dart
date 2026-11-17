import 'package:parrokit/core/shared/utils/time_ago_label.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';

/// 글·댓글 시각. 일주일이 넘으면 '120일 전'처럼 세기 어려운 숫자 대신 날짜로
/// 보인다(5차). 올해가 아니면 연도도 붙인다.
String formatCommunityTimeAgo(DateTime? time, {DateTime? now}) {
  if (time == null) return '';
  return timeAgoLabel(time, now ?? DateTime.now());
}

String resolveCommunityAuthorName({
  required Post post,
  required CommunityProvider provider,
  required UserProvider userProvider,
}) {
  final currentUser = userProvider.currentUser;
  final isMe = currentUser != null && post.authorId == currentUser.id;
  if (isMe) {
    return currentUser.displayName ?? post.authorNickname;
  }

  return provider.getCachedUser(post.authorId)?.displayName ??
      post.authorNickname;
}

String? resolveCommunityAuthorAvatarUrl({
  required Post post,
  required CommunityProvider provider,
  required UserProvider userProvider,
}) {
  final currentUser = userProvider.currentUser;
  final isMe = currentUser != null && post.authorId == currentUser.id;
  if (isMe) {
    return currentUser.photoUrl ?? post.authorAvatarUrl;
  }

  return provider.getCachedUser(post.authorId)?.photoUrl ??
      post.authorAvatarUrl;
}
