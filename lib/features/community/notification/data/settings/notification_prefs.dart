import 'package:cloud_firestore/cloud_firestore.dart';

/// 커뮤니티 알림 중 휴대폰 푸시로 받을 종류. 사용자 문서 users/{uid}의
/// `notificationPrefs` 필드에 둔다. 서버 함수(communityNotifications)가 같은
/// 키를 읽어, 꺼진 종류는 푸시만 보내지 않는다. 알림 목록에는 그대로 쌓인다.
///
/// 키 이름은 functions/src/notificationPrefs.ts와 같아야 한다.
class NotificationPrefs {
  const NotificationPrefs({
    this.postComment = true,
    this.commentReply = true,
    this.voteEnd = true,
  });

  /// 내 글에 댓글 (post_comment)
  final bool postComment;

  /// 내 댓글에 답글 (comment_reply)
  final bool commentReply;

  /// 참여한 투표 종료 (vote_end)
  final bool voteEnd;

  static const fieldName = 'notificationPrefs';

  /// 저장값이 없거나 모양이 다르면 켜진 것으로 본다(예전 사용자는 모두 받았다).
  factory NotificationPrefs.fromMap(Object? raw) {
    if (raw is! Map) return const NotificationPrefs();
    bool read(String key) => raw[key] is bool ? raw[key] as bool : true;
    return NotificationPrefs(
      postComment: read('postComment'),
      commentReply: read('commentReply'),
      voteEnd: read('voteEnd'),
    );
  }

  Map<String, bool> toMap() => {
        'postComment': postComment,
        'commentReply': commentReply,
        'voteEnd': voteEnd,
      };

  NotificationPrefs copyWith(
          {bool? postComment, bool? commentReply, bool? voteEnd}) =>
      NotificationPrefs(
        postComment: postComment ?? this.postComment,
        commentReply: commentReply ?? this.commentReply,
        voteEnd: voteEnd ?? this.voteEnd,
      );

  @override
  bool operator ==(Object other) =>
      other is NotificationPrefs &&
      other.postComment == postComment &&
      other.commentReply == commentReply &&
      other.voteEnd == voteEnd;

  @override
  int get hashCode => Object.hash(postComment, commentReply, voteEnd);
}

/// 알림 설정 읽기·쓰기. 사용자 문서의 다른 필드는 건드리지 않는다(merge).
class NotificationPrefsRepository {
  NotificationPrefsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection('users').doc(uid);

  Future<NotificationPrefs> load(String uid) async {
    final snap = await _doc(uid).get();
    return NotificationPrefs.fromMap(snap.data()?[NotificationPrefs.fieldName]);
  }

  Future<void> save(String uid, NotificationPrefs prefs) => _doc(uid).set({
        NotificationPrefs.fieldName: prefs.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}
