import 'package:flutter/foundation.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/shared/utils/user_error_message.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/data/models/user.dart';
import 'package:parrokit/features/community/block/data/repositories/block_repository_impl.dart';
import 'package:parrokit/features/community/block/domain/entities/blocked_user.dart';
import 'package:parrokit/features/community/block/domain/usecases/block_user_usecase.dart';
import 'package:parrokit/features/community/block/domain/usecases/load_blocked_users_usecase.dart';
import 'package:parrokit/features/community/block/domain/usecases/unblock_user_usecase.dart';

class BlockProvider extends ChangeNotifier {
  final BlockRepositoryImpl _repository;
  final UserProvider _userProvider;
  late final LoadBlockedUsersUseCase _loadBlockedUsersUseCase;
  late final BlockUserUseCase _blockUserUseCase;
  late final UnblockUserUseCase _unblockUserUseCase;

  BlockProvider(this._repository, this._userProvider) {
    _loadBlockedUsersUseCase = LoadBlockedUsersUseCase(_repository);
    _blockUserUseCase = BlockUserUseCase(_repository);
    _unblockUserUseCase = UnblockUserUseCase(_repository);
  }

  final List<BlockedUser> _blockedUsers = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<BlockedUser> get blockedUsers => List.unmodifiable(_blockedUsers);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<String> get blockedUserIds => _userProvider.currentUser?.blockedUserIds ?? const [];

  Future<void> loadBlockedUsers() async {
    final currentUser = _userProvider.currentUser;
    if (currentUser == null) {
      _blockedUsers.clear();
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final users = await _loadBlockedUsersUseCase.execute(currentUser.blockedUserIds);
      _blockedUsers
        ..clear()
        ..addAll(users);
    } catch (e, st) {
      AppLogger.e('차단 목록 불러오기 실패', error: e, stackTrace: st);
      _errorMessage = userErrorMessage(e, fallback: '차단 목록을 불러오지 못했어요.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> blockUserByDisplayName(String displayName) async {
    final currentUser = _userProvider.currentUser;
    if (currentUser == null) {
      _errorMessage = '로그인이 필요합니다.';
      notifyListeners();
      return false;
    }

    final trimmedDisplayName = displayName.trim();
    if (trimmedDisplayName.isEmpty) {
      _errorMessage = '닉네임을 입력해 주세요.';
      notifyListeners();
      return false;
    }

    if (currentUser.displayName != null && currentUser.displayName!.trim() == trimmedDisplayName) {
      _errorMessage = '본인 닉네임은 차단할 수 없습니다.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final blockedUserId = await _blockUserUseCase.executeByDisplayName(
        uid: currentUser.id,
        blockedUserIds: currentUser.blockedUserIds,
        displayName: trimmedDisplayName,
      );
      if (blockedUserId == null) {
        _errorMessage = '차단할 사용자를 찾지 못했어요.';
        return false;
      }

      await _syncCurrentUser(
        currentUser.copyWith(
          blockedUserIds: _appendBlockedUserId(currentUser.blockedUserIds, blockedUserId),
          updatedAt: DateTime.now(),
        ),
      );
      await loadBlockedUsers();
      return true;
    } catch (e, st) {
      // 예외 원문(e.toString())을 토스트에 그대로 띄웠다(5차).
      AppLogger.e('차단·차단 해제 실패', error: e, stackTrace: st);
      _errorMessage = userErrorMessage(e, fallback: '처리하지 못했어요. 다시 시도해 주세요.');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> blockUserByUid(String blockedUserId) async {
    final currentUser = _userProvider.currentUser;
    if (currentUser == null) {
      _errorMessage = '로그인이 필요합니다.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final resolvedUserId = await _blockUserUseCase.executeByUid(
        uid: currentUser.id,
        blockedUserIds: currentUser.blockedUserIds,
        blockedUserId: blockedUserId,
      );
      if (resolvedUserId == null) {
        _errorMessage = '차단할 사용자를 찾지 못했어요.';
        return false;
      }

      await _syncCurrentUser(
        currentUser.copyWith(
          blockedUserIds: _appendBlockedUserId(currentUser.blockedUserIds, resolvedUserId),
          updatedAt: DateTime.now(),
        ),
      );
      await loadBlockedUsers();
      return true;
    } catch (e, st) {
      // 예외 원문(e.toString())을 토스트에 그대로 띄웠다(5차).
      AppLogger.e('차단·차단 해제 실패', error: e, stackTrace: st);
      _errorMessage = userErrorMessage(e, fallback: '처리하지 못했어요. 다시 시도해 주세요.');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> unblockUser(String blockedUserId) async {
    final currentUser = _userProvider.currentUser;
    if (currentUser == null) {
      _errorMessage = '로그인이 필요합니다.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _unblockUserUseCase.execute(uid: currentUser.id, blockedUserId: blockedUserId);

      await _syncCurrentUser(
        currentUser.copyWith(
          blockedUserIds:
              currentUser.blockedUserIds.where((id) => id != blockedUserId).toList(),
          updatedAt: DateTime.now(),
        ),
      );
      await loadBlockedUsers();
      return true;
    } catch (e, st) {
      // 예외 원문(e.toString())을 토스트에 그대로 띄웠다(5차).
      AppLogger.e('차단·차단 해제 실패', error: e, stackTrace: st);
      _errorMessage = userErrorMessage(e, fallback: '처리하지 못했어요. 다시 시도해 주세요.');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _syncCurrentUser(AppUser user) async {
    await _userProvider.updateUser(user);
  }

  List<String> _appendBlockedUserId(List<String> blockedUserIds, String blockedUserId) {
    final updated = List<String>.from(blockedUserIds);
    if (!updated.contains(blockedUserId)) {
      updated.add(blockedUserId);
    }
    return updated;
  }
}
