// 공유 문장을 올린 사람의 프로필 사진(5차 338, 사용자 요청).
//
// 공유 문서에는 올린 사람의 uid와 그때 닉네임만 들어 있다. 사진은 users/{uid}의
// photoUrl에 있다. 문장 하나를 볼 때마다 읽으면 같은 사람을 여러 번 읽게 되니
// 한 번 읽은 것은 들고 있는다(앱을 켜 둔 동안만).
//
// 남의 users 문서는 로그인했으면 읽을 수 있다(firestore.rules: allow read if
// request.auth != null). 못 읽으면 기본 아이콘으로 둔다.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthorProfiles {
  AuthorProfiles._();

  /// 테스트에서 가짜 Firestore를 넣는 자리.
  @visibleForTesting
  static FirebaseFirestore? firestore;

  static final Map<String, String?> _cache = {};

  /// 이미 읽어 둔 값. 아직 안 읽었으면 null.
  static String? cached(String uid) => _cache[uid];

  @visibleForTesting
  static void resetForTest() {
    _cache.clear();
    firestore = null;
  }

  /// [uid]가 올린 사람의 프로필 사진 주소. 없거나 못 읽으면 null.
  static Future<String?> photoUrl(String uid) async {
    final id = uid.trim();
    if (id.isEmpty) return null;
    if (_cache.containsKey(id)) return _cache[id];
    try {
      final db = firestore ?? FirebaseFirestore.instance;
      final doc = await db.collection('users').doc(id).get();
      final url = (doc.data()?['photoUrl'] as String?)?.trim();
      return _cache[id] = (url == null || url.isEmpty) ? null : url;
    } catch (_) {
      // 못 읽은 것은 담아 두지 않는다. 다음에 다시 본다.
      return null;
    }
  }
}
