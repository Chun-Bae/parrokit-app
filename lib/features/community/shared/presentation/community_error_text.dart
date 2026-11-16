import 'package:parrokit/core/shared/utils/network_error.dart';

/// 커뮤니티에서 실패했을 때 사람에게 보여줄 말(5차 310).
///
/// 전에는 Provider가 `e.toString()`을 그대로 담아서, 글쓰기 실패 창에
/// `[cloud_firestore/permission-denied] ...` 같은 글이 떴다. 무엇이 안 됐는지도,
/// 무엇을 하면 되는지도 알 수 없었다. 예외는 로그에만 남긴다.
enum CommunityJob {
  /// 목록·상세 불러오기
  load,

  /// 글·댓글 올리기
  write,

  /// 글 고치기
  edit,

  /// 글·댓글 지우기
  delete,

  /// 공감 누르기
  like,

  /// 투표하기
  vote,

  /// 답변 채택하기
  accept,
}

String communityErrorText(CommunityJob job, Object error) {
  if (looksOffline(error)) {
    return '인터넷이 안 되는 것 같아요. 연결을 확인하고 다시 해 주세요.';
  }
  if (looksPermissionDenied(error)) {
    return '지금은 할 수 없어요. 로그인 상태를 확인하고 다시 해 주세요.';
  }
  return switch (job) {
    CommunityJob.load => '불러오지 못했어요. 잠시 뒤 다시 해 주세요.',
    CommunityJob.write => '올리지 못했어요. 잠시 뒤 다시 해 주세요.',
    CommunityJob.edit => '고치지 못했어요. 잠시 뒤 다시 해 주세요.',
    CommunityJob.delete => '지우지 못했어요. 잠시 뒤 다시 해 주세요.',
    CommunityJob.like => '공감을 남기지 못했어요. 잠시 뒤 다시 해 주세요.',
    CommunityJob.vote => '투표하지 못했어요. 잠시 뒤 다시 해 주세요.',
    CommunityJob.accept => '답변을 채택하지 못했어요. 잠시 뒤 다시 해 주세요.',
  };
}
