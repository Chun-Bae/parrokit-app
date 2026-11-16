// ============================================================================
// lib/features/more/presentation/widgets/backup_progress_dialog.dart
// ============================================================================
//
// [역할]
// 백업 및 복원 작업의 진행 상황을 단계별로 사용자에게 보여주는 다이얼로그.
//
// [단계]
// 1. Initial: 작업 설명 및 시작 확인
// 2. Progress: 진행률(LinearProgressIndicator) 및 상태 텍스트 표시
// 3. Result: 성공/실패 결과 아이콘 및 메시지 표시
//
// [사용법]
// showDialog(
//   context: context,
//   barrierDismissible: false,
//   builder: (context) => BackupProgressDialog(
//     type: BackupDialogType.backup, // or restore
//     onStart: () => BackupService.instance.createBackup(...),
//   ),
// ============================================================================

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';

enum BackupDialogType {
  backup,
  restore,
}

/// 실패했을 때 보여 줄 안내를 고른다(5차).
///
/// 전에는 `e.toString()`을 그대로 보여 줘서 사용자가 고칠 수 없는 내부 글이
/// 화면에 떴다. 앱이 직접 던진 짧은 한국어 안내('파일 선택이 취소되었습니다.'
/// 같은 것)는 도움이 되니 그대로 쓰고, 그 밖의 예외 글은 감추고 사람 말로
/// 바꾼다. 자세한 내용은 AppLogger로 남긴다.
String backupFailureMessage(Object error, {required BackupDialogType type}) {
  final raw = error.toString().replaceFirst('Exception: ', '').trim();
  if (_isUserFacingMessage(raw)) return raw;
  return type == BackupDialogType.backup
      ? '백업하지 못했어요. 저장 공간을 확인하고 다시 해 보세요.'
      : '불러오지 못했어요. 백업 파일이 맞는지 확인하고 다시 해 보세요.';
}

bool _isUserFacingMessage(String message) {
  if (message.isEmpty || message.length > 60) return false;
  // 한글이 없으면 내부 예외 글이다.
  if (!RegExp(r'[가-힣]').hasMatch(message)) return false;
  // 경로·클래스 이름·null이 섞인 글은 사람 말이 아니다.
  if (RegExp(r'''[/\\{}<>()\[\]'"]|Exception|Error|null''').hasMatch(message)) {
    return false;
  }
  return true;
}

/// 백업/복원 진행 단계
enum BackupProgressState {
  // 공통
  idle, // 대기 중

  // 백업 단계
  checking, // 데이터 확인
  compressing, // 데이터 압축
  saving, // 파일 저장

  // 복원 단계
  analyzing, // 파일 분석
  extracting, // 압축 해제
  restoring, // 데이터 복원

  // 완료
  done, // 완료
}

/// 백업/복원 진행 정보
class BackupProgress {
  final BackupProgressState state;
  final int? totalBytes; // 전체 용량 (bytes)
  final int? processedBytes; // 처리된 용량 (bytes)

  const BackupProgress({
    required this.state,
    this.totalBytes,
    this.processedBytes,
  });

  /// 용량 표시 문자열 (예: "12.5 MB / 35.2 MB")
  String? get sizeLabel {
    if (totalBytes == null || totalBytes == 0) return null;
    final totalMB = (totalBytes! / 1024 / 1024).toStringAsFixed(1);
    if (processedBytes != null) {
      final processedMB = (processedBytes! / 1024 / 1024).toStringAsFixed(1);
      return '$processedMB / $totalMB MB';
    }
    return '$totalMB MB';
  }
}

class BackupProgressDialog extends StatefulWidget {
  final BackupDialogType type;

  /// 작업 실행 함수
  /// onProgress 콜백을 받아 진행 정보를 보고해야 함
  final Future<void> Function(Function(BackupProgress) onProgress) onStart;

  const BackupProgressDialog({
    super.key,
    required this.type,
    required this.onStart,
  });

  @override
  State<BackupProgressDialog> createState() => _BackupProgressDialogState();
}

class _BackupProgressDialogState extends State<BackupProgressDialog> {
  // ─────────────────────────────────────────────────────────────────
  // State
  // ─────────────────────────────────────────────────────────────────

  /// 현재 단계 (0: 대기, 1: 진행 중, 2: 완료)
  int _step = 0;

  /// 현재 진행 상태
  BackupProgressState _currentState = BackupProgressState.idle;

  /// 용량 표시 라벨
  String? _sizeLabel;

  /// 작업 성공 여부 (완료 단계에서 사용)
  bool? _isSuccess;

  /// 발생한 에러 메시지
  String? _errorMessage;

  // ─────────────────────────────────────────────────────────────────
  // UI Helpers
  // ─────────────────────────────────────────────────────────────────

  String get _title {
    if (_step == 2) {
      if (_isSuccess == true) return '다 됐어요';
      return '안 됐어요';
    }
    // 더보기 카드의 칸 이름('백업' · '불러오기')과 같은 말로 둔다(5차).
    return widget.type == BackupDialogType.backup ? '데이터 백업' : '데이터 불러오기';
  }

  /// 백업이 실제로 담는 것은 클립과 자막(paro.db + 영상 파일)이다. 문장과
  /// 단어는 로그인하면 서버에, 게스트면 기기 설정에 따로 있어 백업에 들어
  /// 가지도, 불러오기로 지워지지도 않는다. 예전 안내는 '지금 앱에 있는 것'이
  /// 모두 담기고 모두 지워지는 것처럼 읽혔다(5차).
  String get _description {
    if (widget.type == BackupDialogType.backup) {
      return '이 기기에 있는 클립과 자막을 파일 하나로 묶어 둬요.\n\n'
          '묶은 파일은 앱 밖에 저장돼서, 나중에 \'불러오기\'로 다시 넣을 수 있어요.\n\n'
          '문장과 단어는 따로 저장돼서 묶지 않아요.';
    }
    return '백업해 둔 파일(.zip)을 골라 그때의 클립과 자막으로 되돌려요.\n\n'
        '지금 기기에 있는 클립과 자막은 모두 지워지고 백업 때의 것으로 바뀌어요. '
        '문장과 단어는 그대로예요.\n\n'
        '다 되면 앱이 다시 시작돼요. 꺼지면 다시 열어 주세요.';
  }

  String get _startLabel =>
      widget.type == BackupDialogType.backup ? '백업 시작' : '불러오기 시작';

  String get _headerLabel =>
      widget.type == BackupDialogType.backup ? '백업하는 중' : '불러오는 중';

  // ─────────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────────

  Future<void> _handleStart() async {
    setState(() {
      _step = 1;
      _currentState = BackupProgressState.idle;
      _sizeLabel = null;
    });

    try {
      await widget.onStart((progress) {
        if (mounted) {
          setState(() {
            _currentState = progress.state;
            _sizeLabel = progress.sizeLabel;
          });
        }
      });

      if (mounted) {
        setState(() {
          _step = 2;
          _isSuccess = true;
          _currentState = BackupProgressState.done;
        });
      }
    } catch (e, stack) {
      AppLogger.e(
        widget.type == BackupDialogType.backup ? '백업 실패' : '불러오기 실패',
        error: e,
        stackTrace: stack,
      );
      if (mounted) {
        setState(() {
          _step = 2;
          _isSuccess = false;
          _errorMessage = backupFailureMessage(e, type: widget.type);
          _currentState = BackupProgressState.done;
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: _step != 1, // 진행 중일 때는 뒤로가기 방지
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          _title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_step == 0) _buildInitialStep(theme),
            if (_step == 1) _buildProgressStep(theme),
            if (_step == 2) _buildResultStep(theme),
          ],
        ),
        actions: _buildActions(context),
      ),
    );
  }

  /// 1. 대기 화면 (설명 + 시작 버튼은 actions에)
  Widget _buildInitialStep(ThemeData theme) {
    return Text(
      _description,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.5,
      ),
    );
  }

  /// 2. 진행 화면
  Widget _buildProgressStep(ThemeData theme) {
    final cs = theme.colorScheme;
    final isBackup = widget.type == BackupDialogType.backup;

    // 백업 단계 정의 (State, Label, Icon)
    final backupSteps = [
      (BackupProgressState.checking, '데이터 확인', Icons.folder_open_rounded),
      (BackupProgressState.compressing, '데이터 압축', Icons.archive_rounded),
      (BackupProgressState.saving, '파일 저장', Icons.save_alt_rounded),
    ];

    // 복원 단계 정의
    final restoreSteps = [
      (BackupProgressState.analyzing, '파일 확인', Icons.manage_search_rounded),
      (BackupProgressState.extracting, '압축 풀기', Icons.unarchive_rounded),
      (BackupProgressState.restoring, '데이터 넣기', Icons.restore_page_rounded),
    ];

    final steps = isBackup ? backupSteps : restoreSteps;

    // 현재 상태의 인덱스 계산
    int currentIndex = -1;
    for (int i = 0; i < steps.length; i++) {
      if (steps[i].$1 == _currentState) {
        currentIndex = i;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더: 아이콘 + 제목 + 용량 (SttProgressCard 스타일)
        Row(
          children: [
            Icon(
              isBackup ? Icons.backup_rounded : Icons.restore_rounded,
              color: cs.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _headerLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ),
            if (_sizeLabel != null)
              Text(
                _sizeLabel!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // 단계별 리스트
        ...steps.asMap().entries.map((entry) {
          final index = entry.key;
          final (state, label, icon) = entry.value;

          final isCompleted = currentIndex > index;
          final isActive = currentIndex == index;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                // Status Icon
                if (isCompleted)
                  Icon(Icons.check_circle, color: cs.primary, size: 20)
                else if (isActive)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  )
                else
                  Icon(Icons.circle_outlined,
                      color: cs.onSurface.withValues(alpha: 0.3), size: 20),

                const SizedBox(width: 12),

                // Category Icon
                Icon(
                  icon,
                  size: 18,
                  color: isActive || isCompleted
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.4),
                ),

                const SizedBox(width: 8),

                // Label
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive || isCompleted
                        ? cs.onSurface
                        : cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// 3. 결과 화면
  Widget _buildResultStep(ThemeData theme) {
    final isSuccess = _isSuccess ?? false;
    // 성공 시에도 테마 primary 색상 사용 (Theme.of 준수)
    final color =
        isSuccess ? theme.colorScheme.primary : theme.colorScheme.error;
    final icon = isSuccess ? Icons.check_circle_rounded : Icons.error_rounded;

    final successMessage = widget.type == BackupDialogType.backup
        ? '백업했어요.'
        : '다 불러왔어요.';
    final failureMessage = widget.type == BackupDialogType.backup
        ? '백업하지 못했어요.'
        : '불러오지 못했어요.';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 16),
          Text(
            isSuccess ? successMessage : failureMessage,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (!isSuccess && _errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                _errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget>? _buildActions(BuildContext context) {
    if (_step == 1) return null; // 진행 중에는 버튼 없음

    if (_step == 2) {
      // 완료 시 닫기/확인 버튼
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ];
    }

    // 대기 시 취소/시작 버튼
    return [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: _handleStart,
        child: Text(_startLabel),
      ),
    ];
  }
}
