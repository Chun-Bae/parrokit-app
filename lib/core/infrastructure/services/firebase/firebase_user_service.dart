// lib/services/firebase_user_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parrokit/data/models/user.dart';
import 'package:parrokit/core/infrastructure/services/firebase/migrations/coins_to_parrots_migration.dart';

class FirebaseUserService {
  final FirebaseFirestore _firestore;
  final CoinsToParrotsMigration _coinsToParrotsMigration;

  FirebaseUserService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _coinsToParrotsMigration = CoinsToParrotsMigration();

  Future<void> initUserDocument({
    required String uid,
    required String email,
    String? photoUrl,
  }) async {
    final docRef = _firestore.collection('users').doc(uid);

    await docRef.set({
      'email': email,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'parrots': 0,
      'coins': FieldValue.delete(),
      'unreadNotificationCount': 0,
      'blockedUserIds': <String>[],
      'fcmTokens': <String>[],
      'isPremium': false,
      'lastPurchaseAt': null,
    }, SetOptions(merge: true)); // 이미 있으면 덮어쓰지 않고 병합
  }

  Future<Map<String, dynamic>?> getUserMeta(String uid) async {
    final snap = await _firestore.collection('users').doc(uid).get();
    return snap.data();
  }

  Future<void> updateUserEconomy({
    required String uid,
    required int parrots,
    required int crackers,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'parrots': parrots,
      'coins': FieldValue.delete(),
      'crackers': crackers,
      'lastPurchaseAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> exchangeCurrency({
    required String uid,
    required int amountToDeduct,
    required int amountToAdd,
    required bool isParrotsToCrackers,
  }) async {
    final userRef = _firestore.collection('users').doc(uid);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) {
        throw Exception('유저 정보를 찾을 수 없습니다.');
      }
      
      final data = snapshot.data()!;
      int currentParrots = (data['parrots'] as num?)?.toInt() ?? 0;
      int currentCrackers = (data['crackers'] as num?)?.toInt() ?? 0;
      
      if (isParrotsToCrackers) {
        if (currentParrots < amountToDeduct) {
          throw Exception('보유하신 패롯이 부족합니다.');
        }
        currentParrots -= amountToDeduct;
        currentCrackers += amountToAdd;
      } else {
        if (currentCrackers < amountToDeduct) {
          throw Exception('보유하신 크래커가 부족합니다.');
        }
        currentCrackers -= amountToDeduct;
        currentParrots += amountToAdd;
      }
      
      transaction.update(userRef, {
        'parrots': currentParrots,
        'coins': FieldValue.delete(),
        'crackers': currentCrackers,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> updateUserPhoto({
    required String uid,
    required String? photoUrl,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserDisplayName({
    required String uid,
    required String? newNickname,
    String? oldNickname,
  }) async {
    // 닉네임 관리를 위해 기존 메서드 업그레이드
    if (newNickname == null || newNickname.isEmpty) return;
    
    final userRef = _firestore.collection('users').doc(uid);
    final newNickRef = _firestore.collection('nicknames').doc(newNickname);

    // 트랜잭션으로 묶는다. 전에는 WriteBatch였는데, 배치는 읽지 않고 쓰기만
    // 하므로 "이미 남이 쓰는 닉네임인지"를 볼 수 없었다. 화면이 미리
    // isNicknameAvailable로 확인하긴 하지만, 그 사이에 다른 사람이 같은
    // 닉네임을 선점하면 batch.set이 그대로 덮어썼다. nicknames 컬렉션은
    // 중복을 막으려고 두는 것인데 그 목적이 무너진다.
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(newNickRef);
      if (existing.exists) {
        final ownerUid = existing.data()?['uid'] as String?;
        // 내 닉네임을 그대로 다시 저장하는 건 통과시킨다.
        if (ownerUid != null && ownerUid != uid) {
          throw Exception('이미 사용 중인 닉네임이에요.');
        }
      }

      // 1. 유저 문서 업데이트 (lastNicknameChangedAt 기록)
      transaction.update(userRef, {
        'displayName': newNickname,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastNicknameChangedAt': FieldValue.serverTimestamp(),
      });

      // 2. 새 닉네임 선점 (nicknames 컬렉션)
      transaction.set(newNickRef, {
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. 기존 닉네임 해제 (nicknames 컬렉션)
      if (oldNickname != null &&
          oldNickname.isNotEmpty &&
          oldNickname != newNickname) {
        transaction
            .delete(_firestore.collection('nicknames').doc(oldNickname));
      }
    });
  }

  Future<void> blockUser({
    required String uid,
    required String blockedUserId,
  }) async {
    final userRef = _firestore.collection('users').doc(uid);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) {
        throw Exception('유저 정보를 찾을 수 없습니다.');
      }

      transaction.update(userRef, {
        'blockedUserIds': FieldValue.arrayUnion([blockedUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> addFcmToken({
    required String uid,
    required String token,
  }) async {
    if (token.isEmpty) return;

    await _firestore.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeFcmToken({
    required String uid,
    required String token,
  }) async {
    if (token.isEmpty) return;

    await _firestore.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayRemove([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<int> syncUnreadNotificationCount({required String uid}) async {
    final unreadSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    final unreadCount = unreadSnapshot.docs.length;

    await _firestore.collection('users').doc(uid).set({
      'unreadNotificationCount': unreadCount,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return unreadCount;
  }

  Future<void> unblockUser({
    required String uid,
    required String blockedUserId,
  }) async {
    final userRef = _firestore.collection('users').doc(uid);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) {
        throw Exception('유저 정보를 찾을 수 없습니다.');
      }

      transaction.update(userRef, {
        'blockedUserIds': FieldValue.arrayRemove([blockedUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 닉네임 중복 확인 (이미 해당 문서가 있으면 누군가 사용 중)
  Future<bool> isNicknameAvailable(String nickname) async {
    if (nickname.isEmpty) return false;
    final doc = await _firestore.collection('nicknames').doc(nickname).get();
    return !doc.exists;
  }

  Future<AppUser?> loadUserDocument({required String uid}) async {
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .get()
        .timeout(const Duration(seconds: 5), onTimeout: () => throw TimeoutException('loadUserDocument timeout'));
    if (!snap.exists) {
      return null;
    }

    final data = snap.data()!;
    await _coinsToParrotsMigration.migrateLegacyCoinsField(
      userRef: snap.reference,
      data: data,
    );
    return _coinsToParrotsMigration.buildAppUser(uid: uid, data: data);
  }

  Future<void> deleteUserDocument({required String uid}) async {
    await _firestore.collection('users').doc(uid).delete();
  }

  Future<AppUser?> loadUserDocumentByNickname(String nickname) async {
    if (nickname.isEmpty) return null;

    final nicknameSnap = await _firestore.collection('nicknames').doc(nickname).get();
    if (!nicknameSnap.exists) {
      return null;
    }

    final data = nicknameSnap.data();
    final uid = data?['uid'] as String?;
    if (uid == null || uid.isEmpty) {
      return null;
    }

    return loadUserDocument(uid: uid);
  }

  Future<AppUser?> loadUserDocumentByDisplayName(String displayName) async {
    if (displayName.isEmpty) return null;

    final snapshot = await _firestore
        .collection('users')
        .where('displayName', isEqualTo: displayName)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final doc = snapshot.docs.first;
    final data = doc.data();
    await _coinsToParrotsMigration.migrateLegacyCoinsField(
      userRef: doc.reference,
      data: data,
    );
    return _coinsToParrotsMigration.buildAppUser(uid: doc.id, data: data);
  }

  Stream<AppUser?> watchUserDocument({required String uid}) {
    if (uid.isEmpty) {
      return Stream<AppUser?>.value(null);
    }

    return _firestore.collection('users').doc(uid).snapshots().asyncMap((snap) async {
      if (!snap.exists) {
        return null;
      }

      final data = snap.data()!;
      await _coinsToParrotsMigration.migrateLegacyCoinsField(
        userRef: snap.reference,
        data: data,
      );
      return _coinsToParrotsMigration.buildAppUser(uid: uid, data: data);
    });
  }

}
