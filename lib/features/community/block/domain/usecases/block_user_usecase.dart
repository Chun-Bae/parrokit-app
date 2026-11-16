import 'package:parrokit/features/community/block/domain/repositories/block_repository.dart';

class BlockUserUseCase {
  final BlockRepository _repository;

  BlockUserUseCase(this._repository);

  Future<String?> executeByDisplayName({
    required String uid,
    required List<String> blockedUserIds,
    required String displayName,
  }) async {
    final blockedUserId =
        await _repository.resolveUserIdByDisplayName(displayName);
    if (blockedUserId == null || blockedUserId.isEmpty) {
      return null;
    }

    if (blockedUserId == uid) {
      throw Exception('자기 자신은 차단할 수 없습니다.');
    }

    if (!blockedUserIds.contains(blockedUserId)) {
      await _repository.blockUser(uid: uid, blockedUserId: blockedUserId);
    }

    return blockedUserId;
  }

  Future<String?> executeByUid({
    required String uid,
    required List<String> blockedUserIds,
    required String blockedUserId,
  }) async {
    final resolvedUserId = await _repository.resolveUserIdByUid(blockedUserId);
    if (resolvedUserId == null || resolvedUserId.isEmpty) {
      return null;
    }

    if (resolvedUserId == uid) {
      throw Exception('자기 자신은 차단할 수 없습니다.');
    }

    if (!blockedUserIds.contains(resolvedUserId)) {
      await _repository.blockUser(uid: uid, blockedUserId: resolvedUserId);
    }

    return resolvedUserId;
  }
}
