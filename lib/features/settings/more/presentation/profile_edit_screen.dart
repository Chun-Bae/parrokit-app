import 'package:parrokit/core/shared/utils/user_error_message.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/features/settings/more/presentation/widgets/editable_avatar.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/content/sentence_mastery.dart';
import 'package:parrokit/core/shared/utils/nickname_rule.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _nicknameController = TextEditingController();
  bool _isLoading = false;

  // 닉네임 변경 쿨타임 관련 상태
  bool _canChangeNickname = true;
  int _remainingDays = 0;
  DateTime? _lastChangedAt;

  // 프로필 사진 로컬 상태
  String? _selectedPhotoUrl;

  // 중복 확인 관련 상태
  bool _isCheckingDuplicate = false;
  bool _isNicknameAvailable = false;
  String? _checkedNickname;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<UserProvider>().currentUser;
      if (user != null) {
        _nicknameController.text = user.displayName ?? '';
        _checkedNickname = user.displayName;
        _isNicknameAvailable = true; // 본인의 기존 닉네임은 항상 통과 상태
        _lastChangedAt = user.lastNicknameChangedAt;
        _selectedPhotoUrl = user.photoUrl;

        // 30일 쿨타임 계산
        if (_lastChangedAt != null) {
          final diff = DateTime.now().difference(_lastChangedAt!);
          if (diff.inDays < 30) {
            _canChangeNickname = false;
            _remainingDays = 30 - diff.inDays;
          }
        }
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _checkDuplicate() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      showToast('닉네임을 입력해주세요.');
      return;
    }

    final user = context.read<UserProvider>().currentUser;
    // 기존 닉네임과 동일하면 중복 검사 패스
    if (user?.displayName == nickname) {
      setState(() {
        _isNicknameAvailable = true;
        _checkedNickname = nickname;
      });
      showToast('현재 사용 중인 닉네임입니다.');
      return;
    }

    setState(() => _isCheckingDuplicate = true);
    try {
      final isAvailable =
          await context.read<UserProvider>().isNicknameAvailable(nickname);
      if (!mounted) return;
      setState(() {
        _isNicknameAvailable = isAvailable;
        _checkedNickname = nickname;
      });
      if (isAvailable) {
        showToast('사용 가능한 닉네임입니다.');
      } else {
        showToast('이미 누군가 사용 중인 닉네임입니다.');
      }
    } catch (e) {
      if (!mounted) return;
      showToast('중복 확인 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _isCheckingDuplicate = false);
    }
  }

  Future<void> _saveProfile() async {
    final newNickname = _nicknameController.text.trim();
    if (newNickname.isEmpty) {
      showToast('닉네임을 입력해주세요.');
      return;
    }

    // 중복 확인 여부 검증
    if (newNickname != _checkedNickname || !_isNicknameAvailable) {
      showToast('닉네임 중복 확인을 먼저 완료해주세요.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userProvider = context.read<UserProvider>();
      final currentUser = userProvider.currentUser;

      // 사진이 변경되었을 때만 업데이트
      if (currentUser?.photoUrl != _selectedPhotoUrl) {
        String? finalPhotoUrl = _selectedPhotoUrl;

        // 1. 로컬 경로일 경우 (기기에서 갤러리로 선택한 경우) Storage 에 새로 업로드
        //
        // 전에는 기존 프사를 먼저 지우고 나서 올렸다. 업로드가 실패하면
        // 예전 사진은 이미 사라졌는데 새 사진은 안 올라가서, 사용자가
        // 프로필 사진을 통째로 잃었다. 올리고 저장이 끝난 뒤에 지운다.
        if (finalPhotoUrl != null &&
            (finalPhotoUrl.startsWith('/') ||
                finalPhotoUrl.startsWith('file://'))) {
          final file = File(finalPhotoUrl);
          // 파일명에 타임스탬프를 붙여 중복 방지 (확장자는 편의상 jpg 처리, 원한다면 추출 로직 추가 가능)
          final ref = FirebaseStorage.instance.ref().child(
              'users/${currentUser!.id}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');

          await ref.putFile(file);
          finalPhotoUrl = await ref.getDownloadURL();
        }

        // 2. 빈 문자열 '' 은 기본 프사(제거)를 의미합니다
        await userProvider
            .updatePhotoUrl(finalPhotoUrl == '' ? null : finalPhotoUrl);

        // 3. 저장까지 끝났으면 예전 프사를 지운다 (용량 절약)
        final previousPhotoUrl = currentUser?.photoUrl;
        if (previousPhotoUrl != null &&
            previousPhotoUrl.contains('firebasestorage.googleapis.com')) {
          try {
            await FirebaseStorage.instance
                .refFromURL(previousPhotoUrl)
                .delete();
          } catch (e) {
            // 삭제 실패하더라도 (이미 없거나 권한문제 등) 진행은 계속되도록 catch 처리
            AppLogger.w('[Profile] 옛 프로필 사진 삭제 실패: $e');
          }
        }
      }

      // 닉네임이 실제로 변경되었을 때만 업데이트 (null과 빈 문자열 동일 취급)
      final currentDisplayName = currentUser?.displayName ?? '';
      if (currentDisplayName != newNickname) {
        await userProvider.updateDisplayName(newNickname);
      }

      if (!mounted) return;
      showToast('프로필이 성공적으로 업데이트되었습니다.');
      context.pop();
    } catch (e, st) {
      AppLogger.e('프로필 업데이트 실패', error: e, stackTrace: st);
      if (!mounted) return;
      showToast(userErrorMessage(e, fallback: '프로필을 저장하지 못했어요. 다시 시도해 주세요.'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.currentUser;

    final currentInput = _nicknameController.text.trim();
    final effectivePhotoUrl =
        _selectedPhotoUrl == '' ? null : _selectedPhotoUrl;

    // 각각 변경되었는지 여부 확인
    final hasNicknameChanged = (user?.displayName ?? '') != currentInput;
    final hasPhotoChanged = user?.photoUrl != effectivePhotoUrl;
    final hasChanges = hasNicknameChanged || hasPhotoChanged;

    // 닉네임 저장이 가능한 상태인지 판별
    final isVerified =
        _isNicknameAvailable && (_checkedNickname ?? '') == currentInput;
    // 1) 닉네임이 안 바뀌었으면 조건 통과
    // 2) 닉네임이 바뀌었다면 -> 중복확인 완료(isVerified) + 쿨타임 통과(_canChangeNickname) 둘 다 만족해야 함
    final isNicknameValidToSave =
        !hasNicknameChanged || (isVerified && _canChangeNickname);

    // 저장 버튼 활성화 조건: 변경 사항이 있고, 닉네임 저장 조건이 충족될 때
    final canSave = hasChanges && isNicknameValidToSave;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('프로필 수정'),
        centerTitle: true,
        backgroundColor: cs.surface,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: (_isLoading || !canSave) ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    '완료',
                    style: context.texts.titleMedium.copyWith(
                        color: !canSave
                            ? cs.onSurface.withValues(alpha: 0.3)
                            : cs.primary),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 프로필 사진 수정 (EditableAvatar 재사용)
                  Center(
                    child: EditableAvatar(
                      photoUrl:
                          _selectedPhotoUrl == '' ? null : _selectedPhotoUrl,
                      size: 100, // 더 크게 표시
                      onSelected: (url) {
                        setState(() {
                          _selectedPhotoUrl = url;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      '사진을 눌러 변경',
                      style: context.texts.labelMedium
                          .copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // 2. 닉네임 입력 폼
                  Text(
                    '닉네임',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nicknameController,
                          maxLength: nicknameMaxLength,
                          enabled: _canChangeNickname, // 쿨타임 시 비활성화
                          onChanged: (_) =>
                              setState(() {}), // 상태 반영 (확인 버튼 상태용)
                          decoration: InputDecoration(
                            hintText: '새로운 닉네임을 입력하세요',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            filled: true,
                            fillColor: cs.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                            counterText: '',
                          ),
                          onSubmitted: (_) =>
                              _canChangeNickname ? _checkDuplicate() : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 52, // TextField와 비슷한 높이로 맞춤
                        child: FilledButton.tonal(
                          onPressed:
                              (!_canChangeNickname || _isCheckingDuplicate)
                                  ? null
                                  : _checkDuplicate,
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            backgroundColor: isVerified
                                ? context.tokens.success.withValues(alpha: 0.2)
                                : null,
                          ),
                          child: _isCheckingDuplicate
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(
                                  isVerified ? '확인됨' : '중복확인',
                                  style: TextStyle(
                                    color: isVerified
                                        ? context.tokens.success
                                        : null,
                                    fontWeight: isVerified
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),

                  // 3. 30일 쿨타임 안내 문구. 예전엔 기다리는 중을 빨간 오류처럼
                  // 한 줄로 보여 좁은 화면에서 넘칠 수 있었고, 바꿀 수 있을 때는
                  // 30일 규칙을 알리지 않았다(5차).
                  const SizedBox(height: 8),
                  if (!_canChangeNickname)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            nicknameCooldownNote(_remainingDays),
                            style: context.texts.bodySmall
                                .copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    )
                  else if (_lastChangedAt != null)
                    Text(
                      nicknameReadyNote(DateTime.now(), _lastChangedAt!),
                      style: context.texts.bodySmall
                          .copyWith(color: cs.onSurface.withValues(alpha: 0.4)),
                    )
                  else
                    Text(
                      '닉네임은 30일에 한 번 바꿀 수 있어요.',
                      style: context.texts.bodySmall
                          .copyWith(color: cs.onSurface.withValues(alpha: 0.4)),
                    ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

/// 닉네임을 아직 바꿀 수 없을 때 안내. [remainingDays]일 뒤에 바꿀 수 있다.
@visibleForTesting
/// 30일이 지나 지금 바꿀 수 있을 때의 안내.
///
/// 예전엔 '마지막 변경일: 2026년 5월 27일 · 바꾸면 30일 동안 다시 바꿀 수
/// 없어요'만 적혀서, 지금 바꿀 수 있는지 알 수 없었다. 날짜도 앱의 다른
/// 곳(문장 기록·알림)과 달리 늘 연도를 붙였다(5차).
String nicknameReadyNote(DateTime now, DateTime lastChangedAt) =>
    '지금 바꿀 수 있어요. 마지막으로 바꾼 날은 '
    '${relativeDayLabel(now, lastChangedAt)}이고, '
    '바꾸면 30일 동안 다시 바꿀 수 없어요.';

String nicknameCooldownNote(int remainingDays) => remainingDays <= 1
    ? '닉네임은 30일에 한 번 바꿀 수 있어요. 내일부터 바꿀 수 있어요.'
    : '닉네임은 30일에 한 번 바꿀 수 있어요. $remainingDays일 뒤에 바꿀 수 있어요.';
