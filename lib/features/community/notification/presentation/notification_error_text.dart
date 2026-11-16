import 'package:parrokit/core/shared/utils/network_error.dart';

/// 알림 화면에 띄울 말. 예외 글을 그대로 보여 주지 않는다(5차 309).
///
/// 전에는 `[cloud_firestore/unavailable] Failed to get document because the
/// client is offline.` 같은 글이 빨간 띠에 그대로 떴다. 무엇이 안 됐는지도,
/// 무엇을 하면 되는지도 알 수 없었다.
enum NotificationJob {
  /// 알림 목록 불러오기·실시간 받기
  load,

  /// 읽음으로 바꾸기
  read,

  /// 알림 지우기
  delete,
}

String notificationErrorText(NotificationJob job, Object error) {
  if (looksOffline(error)) {
    return '인터넷이 안 되는 것 같아요. 연결을 확인하고 다시 해 주세요.';
  }
  return switch (job) {
    NotificationJob.load => '알림을 불러오지 못했어요. 잠시 뒤 다시 해 주세요.',
    NotificationJob.read => '읽음으로 바꾸지 못했어요. 잠시 뒤 다시 해 주세요.',
    NotificationJob.delete => '알림을 지우지 못했어요. 잠시 뒤 다시 해 주세요.',
  };
}
