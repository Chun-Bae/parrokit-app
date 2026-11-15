import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parrokit/data/models/user.dart';

class CoinsToParrotsMigration {
  int readParrots(Map<String, dynamic> data) {
    final parrots = (data['parrots'] as num?)?.toInt() ?? 0;
    final coins = (data['coins'] as num?)?.toInt() ?? 0;
    return parrots + coins;
  }

  Future<void> migrateLegacyCoinsField({
    required DocumentReference<Map<String, dynamic>> userRef,
    required Map<String, dynamic> data,
  }) async {
    if (!data.containsKey('coins')) {
      return;
    }

    final legacyCoins = (data['coins'] as num?)?.toInt();
    if (legacyCoins == null) return;

    final currentParrots = (data['parrots'] as num?)?.toInt() ?? 0;
    final updates = <String, dynamic>{
      'coins': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
      'parrots': currentParrots + legacyCoins,
    };

    await userRef.set(updates, SetOptions(merge: true));
  }

  AppUser buildAppUser({
    required String uid,
    required Map<String, dynamic> data,
  }) {
    return AppUser(
      id: uid,
      displayName: data['displayName'],
      email: data['email'],
      photoUrl: data['photoUrl'],
      parrots: readParrots(data),
      crackers: (data['crackers'] as num?)?.toInt() ?? 0,
      // 구독으로 받은 패롯. 서버만 쓰고 앱은 읽기만 한다(5차).
      subParrots: (data['subParrots'] as num?)?.toInt() ?? 0,
      unreadNotificationCount:
          (data['unreadNotificationCount'] as num?)?.toInt() ?? 0,
      blockedUserIds: (data['blockedUserIds'] as List<dynamic>?)
              ?.map((value) => value.toString())
              .where((value) => value.isNotEmpty)
              .toList() ??
          const [],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      lastNicknameChangedAt: data['lastNicknameChangedAt'] != null
          ? (data['lastNicknameChangedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
