import 'package:cloud_firestore/cloud_firestore.dart';

/// 신고 사유. 저장값(code)은 Firestore 규칙(firestore.rules의 reports)과 같아야 한다.
enum ReportReason {
  spam('spam', '스팸·홍보'),
  abuse('abuse', '욕설·비하·괴롭힘'),
  sexual('sexual', '음란하거나 불쾌한 내용'),
  other('other', '그 밖의 문제');

  const ReportReason(this.code, this.label);
  final String code;
  final String label;
}

/// 커뮤니티 글·댓글 신고. 예전에는 '신고'를 누르면 "신고가 접수되었습니다."
/// 토스트만 띄우고 아무 데도 남기지 않았다(5차). 이제 reports 컬렉션에
/// 남긴다. 앱은 쓰기만 하고 읽지 않는다(운영자가 콘솔에서 본다).
class CommunityReportRepository {
  CommunityReportRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> submit({
    required String reporterId,
    required String postId,
    String? commentId,
    required String targetAuthorId,
    required ReportReason reason,
  }) =>
      _firestore.collection('reports').add({
        'reporterId': reporterId,
        'targetType': commentId == null ? 'post' : 'comment',
        'postId': postId,
        if (commentId != null) 'commentId': commentId,
        'targetAuthorId': targetAuthorId,
        'reason': reason.code,
        'createdAt': FieldValue.serverTimestamp(),
      });
}
