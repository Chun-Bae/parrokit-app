import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';

/// 글·댓글 시각. 일주일이 넘으면 '120일 전'처럼 세기 어려운 숫자 대신 날짜로
/// 보인다(5차). 올해가 아니면 연도도 붙인다.
String formatCommunityTimeAgo(DateTime? time, {DateTime? now}) {
  if (time == null) return '';
  final current = now ?? DateTime.now();
  final diff = current.difference(time);
  if (diff.inDays >= 7) {
    final local = time.toLocal();
    return local.year == current.year
        ? '${local.month}월 ${local.day}일'
        : '${local.year}년 ${local.month}월 ${local.day}일';
  }
  if (diff.inDays > 0) return '${diff.inDays}일 전';
  if (diff.inHours > 0) return '${diff.inHours}시간 전';
  if (diff.inMinutes > 0) return '${diff.inMinutes}분 전';
  return '방금 전';
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
