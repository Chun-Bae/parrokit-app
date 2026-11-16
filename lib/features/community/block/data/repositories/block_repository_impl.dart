import 'package:parrokit/core/infrastructure/services/firebase/firebase_user_service.dart';
import 'package:parrokit/features/community/block/domain/entities/blocked_user.dart';
import 'package:parrokit/features/community/block/domain/repositories/block_repository.dart';

class BlockRepositoryImpl implements BlockRepository {
  final FirebaseUserService _firebaseUserService;

  BlockRepositoryImpl(this._firebaseUserService);

  @override
  Future<List<BlockedUser>> loadBlockedUsers(
      List<String> blockedUserIds) async {
    if (blockedUserIds.isEmpty) {
      return const [];
    }

    final users = await Future.wait(
      blockedUserIds.map((userId) async {
        final user = await _firebaseUserService.loadUserDocument(uid: userId);
        if (user == null) {
          return null;
        }
        return BlockedUser(
          id: user.id,
          displayName: user.displayName,
          photoUrl: user.photoUrl,
        );
      }),
    );

    return users.whereType<BlockedUser>().toList();
  }

  @override
  Future<String?> resolveUserIdByDisplayName(String displayName) async {
    if (displayName.isEmpty) return null;

    final byDisplayName =
        await _firebaseUserService.loadUserDocumentByDisplayName(displayName);
    return byDisplayName?.id;
  }

  @override
  Future<String?> resolveUserIdByUid(String uid) async {
    if (uid.isEmpty) return null;

    final byUid = await _firebaseUserService.loadUserDocument(uid: uid);
    return byUid?.id;
  }

  @override
  Future<void> blockUser({
    required String uid,
    required String blockedUserId,
  }) {
    return _firebaseUserService.blockUser(
        uid: uid, blockedUserId: blockedUserId);
  }

  @override
  Future<void> unblockUser({
    required String uid,
    required String blockedUserId,
  }) {
    return _firebaseUserService.unblockUser(
        uid: uid, blockedUserId: blockedUserId);
  }
}
