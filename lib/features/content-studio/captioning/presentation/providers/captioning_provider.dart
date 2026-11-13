// ============================================================================
// lib/features/content-studio/captioning/presentation/providers/captioning_provider.dart
// ============================================================================
//
// [역할]
// 캡션링 provider. UI 상태 관리에 집중.
// 비즈니스 로직은 Domain/UseCase 레이어에 위임.
//
// [레이어]
// Presentation Layer - Provider
// ============================================================================

import 'package:parrokit/core/shared/utils/user_error_message.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:flutter/material.dart';

import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/data/local/dao/collections_dao.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart' as utils;

import '../../data/adapters/asr_engine.dart';
import '../../data/adapters/openai_api_exception.dart';
import '../../data/adapters/video_picker_files.dart';
import '../../data/adapters/video_picker_gallery.dart';
import '../../data/services/audio_to_video.dart';
import '../../data/services/clip_load_service.dart';
import '../../data/services/clip_save_service.dart';
import '../../data/services/file_staging_service.dart';
import '../../data/services/remote_caption_draft_service.dart';
import '../../data/services/video_meta_service.dart';
import '../../data/usecases/extract_duration_usecase.dart';
import '../../data/usecases/extract_thumbnail_usecase.dart';
import '../../data/usecases/generate_draft_usecase.dart';
import '../../data/usecases/load_clip_for_edit_usecase.dart';
import '../../data/usecases/pick_video_usecase.dart';
import '../../data/usecases/save_clip_usecase.dart';

import '../../domain/models/clip_form_data.dart';
import '../../domain/models/edit_mode.dart';
import '../../domain/validators/clip_validator.dart';
import '../models/edit_state.dart';

import 'mixins/edit_file_mixin.dart';
import 'mixins/edit_segment_mixin.dart';
import 'mixins/edit_tag_mixin.dart';
import 'mixins/edit_autocomplete_mixin.dart';

/// 캡션링 provider.
class CaptioningProvider extends ChangeNotifier
    with EditFileMixin, EditSegmentMixin, EditTagMixin, EditAutocompleteMixin {
  CaptioningProvider({
    required this.clipProvider,
    required this.userProvider,
    required this.collectionsDao,
    this.clipId,
    this.initialCollectionName,
  }) {
    _init();
  }

  final String? initialCollectionName;

  // ─────────────────────────────────────────────────────────────────
  // 의존성
  // ─────────────────────────────────────────────────────────────────
  final ClipProvider clipProvider;
  final UserProvider userProvider;
  @override
  final CollectionsDao collectionsDao;
  final int? clipId;

  @override
  late final FileStagingService staging;
  @override
  late final AudioToVideoService audioToVideo;
  @override
  late final ExtractThumbnailUseCase extractThumb;
  @override
  late final ExtractDurationUseCase extractDuration;
  @override
  late final PickVideoUseCase pickVideo;

  late final SaveClipUseCase _saveClip;
  late final LoadClipForEditUseCase _loadClipForEdit;
  late final Map<AsrEngine, GenerateDraftUseCase> _generateDraftByEngine;
  final ClipValidator _validator = ClipValidator();

  // ─────────────────────────────────────────────────────────────────
  // 상태
  // ─────────────────────────────────────────────────────────────────

  // 저장 상태
  EditSaveState _saveState = EditSaveState.idle;
  EditSaveState get saveState => _saveState;
  bool get isSaving => _saveState == EditSaveState.saving;

  // STT 처리 진행 상태
  SttProcessState _sttState = SttProcessState.idle;
  SttProcessState get sttState => _sttState;
  bool get isSttProcessing =>
      _sttState != SttProcessState.idle &&
      _sttState != SttProcessState.done &&
      _sttState != SttProcessState.error;

  // 배치 진행률 (번역 단계에서)
  int _sttProgress = 0;
  int _sttTotal = 0;
  int get sttProgress => _sttProgress;
  int get sttTotal => _sttTotal;
  String get sttProgressText => _sttTotal > 0 ? '$_sttProgress/$_sttTotal' : '';

  // 에디터 모드
  EditModeBase _mode = const CreateMode();
  EditModeBase get mode => _mode;
  bool get isEdit => _mode is EditMode;

  // 편집 데이터(영상 파일 포함) 로드 중 여부. 서버/gdrive 클립은 캐시가
  // 없으면 원본을 새로 내려받아야 해서 시간이 걸릴 수 있어, 그동안 화면이
  // 멈춘 것처럼 보이지 않도록 로딩 오버레이를 띄우는 데 사용한다.
  bool _isLoadingForEdit = false;
  bool get isLoadingForEdit => _isLoadingForEdit;

  // TextEditingControllers (View에서 직접 사용)
  final titleCtl = TextEditingController(); // 클립 제목
  final collectionNameCtl = TextEditingController(); // 컬렉션 이름 (선택)
  @override
  final durationCtl = TextEditingController();
  final tagsCtl = TextEditingController();

  /// 새 클립 화면에서 아직 아무것도 고르거나 입력하지 않았는지.
  /// 이때는 나갈 때 "입력한 내용이 삭제된다" 확인 창을 띄우지 않는다.
  /// 편집 모드는 불러오기가 끝나야 [isEdit]가 켜지므로 [clipId]로 판단한다.
  bool get isUntouchedNew =>
      clipId == null &&
      picked == null &&
      titleCtl.text.trim().isEmpty &&
      tagsCtl.text.trim().isEmpty &&
      tags.isEmpty &&
      collectionNameCtl.text.trim() == (initialCollectionName ?? '').trim();

  // 저장 후 닫기 플래그
  bool _shouldClose = false;
  bool get shouldClose => _shouldClose;

  dynamic _closeResult;
  dynamic get closeResult => _closeResult;

  // ─────────────────────────────────────────────────────────────────
  // 초기화
  // ─────────────────────────────────────────────────────────────────

  void showToast(String msg) => utils.showToast(msg);

  void _init() {
    staging = FileStagingService();
    audioToVideo = FfmpegAudioToVideoService();
    extractThumb = ExtractThumbnailUseCase(VideoMetaServiceImpl());
    extractDuration = ExtractDurationUseCase(VideoMetaServiceImpl());
    pickVideo = PickVideoUseCase(
      files: VideoPickerFiles(),
      gallery: VideoPickerGallery(),
    );

    // Service 기반 UseCase 초기화
    _saveClip = SaveClipUseCase(
      service: ClipSaveService(repo: clipProvider, staging: staging),
    );
    _loadClipForEdit = LoadClipForEditUseCase(
      service: ClipLoadService(clipProvider: clipProvider),
    );

    _generateDraftByEngine = {
      AsrEngine.whisper: GenerateDraftUseCase(
        service: RemoteCaptionDraftService(engine: AsrEngine.whisper),
      ),
    };

    // 세그먼트 폼 초기화
    initSegmentForms();

    // 편집 모드 로드
    if (clipId != null) {
      _isLoadingForEdit = true;
      _loadForEdit(clipId!);
    }

    // 컬렉션 이름 목록 로드
    loadCollectionNames();

    // 초기 컬렉션 이름 pre-fill
    if (initialCollectionName != null && clipId == null) {
      collectionNameCtl.text = initialCollectionName!;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // STT + 초안 생성 (UseCase 위임)
  // ─────────────────────────────────────────────────────────────────

  /// 선택된 비디오 파일에 대해 STT를 수행하고 초안을 생성합니다.
  Future<void> startStt(AsrEngine engine) async {
    final generateDraft = _generateDraftByEngine[engine]!;
    if (picked == null || (picked!.path ?? '').isEmpty) {
      showToast('먼저 영상 파일을 선택해 주세요.');
      return;
    }

    // STT에는 원본 경로 사용 (mp3→mp4→wav 이중 변환 방지)
    // OpenAI API는 mp3, mp4, wav 등을 직접 지원
    final path = originalStagedPath ?? picked!.path!;

    // Step 1: 오디오 추출 준비
    _setSttState(SttProcessState.extracting);

    int? durationMs = int.tryParse(durationCtl.text.trim());
    durationMs ??= await extractDuration(path);

    if (durationMs == null || durationMs <= 0) {
      showToast('영상 길이를 확인할 수 없습니다.');
      _setSttState(SttProcessState.error);
      return;
    }

    // 패롯이 모자라면 시작하지 않는다. 서버도 같은 값으로 먼저 깎고, 모자라면
    // 거절한다. 전에는 가진 만큼만 깎고 만들어 줘서 0패롯이면 공짜였다.
    final cost = captionParrotCost(durationMs);
    if (userProvider.coins < cost) {
      showToast('패롯이 부족합니다. (필요 $cost / 보유 ${userProvider.coins})');
      _setSttState(SttProcessState.idle);
      return;
    }

    try {
      // Step 2: 음성 인식 (STT)
      _setSttState(SttProcessState.transcribing);

      // UseCase 호출 (내부에서 STT + 번역 처리)
      final result = await generateDraft(
        filePath: path,
        durationMs: durationMs,
        onProgress: (current, total, message) {
          _sttProgress = current;
          _sttTotal = total;
          if (_sttState != SttProcessState.translating) {
            _setSttState(SttProcessState.translating);
          } else {
            notifyListeners();
          }
        },
      );

      if (result.segments.isNotEmpty) {
        // UI에 세그먼트 채우기
        _fillSegmentsFromDraft(result.segments);

        // 패롯은 서버(generateCaptions)가 자막을 만든 뒤 깎았다. 모자라면
        // 가진 만큼만 깎는다. 잔액은 사용자 문서 구독으로 반영된다.
        final charged = result.coinCost;
        if (charged > 0) {
          Future.delayed(const Duration(milliseconds: 400), () {
            showToast('자막 생성 완료! ($charged패롯 소모)');
          });
        } else {
          Future.delayed(const Duration(milliseconds: 400), () {
            showToast('자막 생성 완료!');
          });
        }
      }

      _setSttState(SttProcessState.done);
      // 잠시 후 idle로 복귀
      Future.delayed(const Duration(seconds: 2), () {
        if (_sttState == SttProcessState.done) {
          _setSttState(SttProcessState.idle);
        }
      });
    } catch (e) {
      Future.delayed(const Duration(milliseconds: 400), () {
        showToast(_sttFailureMessage(e));
      });
      _setSttState(SttProcessState.error);
      Future.delayed(const Duration(seconds: 2), () {
        if (_sttState == SttProcessState.error) {
          _setSttState(SttProcessState.idle);
        }
      });
    }
  }

  String _sttFailureMessage(Object error) {
    if (error is OpenAIApiException) {
      return error.userMessage;
    }

    if (error is RemoteCaptionDraftException) {
      return error.message;
    }

    if (error is ArgumentError) {
      return error.message?.toString() ?? '자동 자막 설정을 확인해 주세요.';
    }

    return '자동 자막 생성 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.';
  }

  void _setSttState(SttProcessState state) {
    _sttState = state;
    notifyListeners();
  }

  void _fillSegmentsFromDraft(List<SegmentInput> segments) {
    ensureSegmentFormsLength(segments.length);

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      setSegmentAt(
        i,
        start: seg.start,
        end: seg.end,
        original: seg.original,
        pron: seg.pron,
        ko: seg.ko,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 저장 (Domain Validator + UseCase 위임)
  // ─────────────────────────────────────────────────────────────────

  /// 클립과 세그먼트 정보를 저장합니다.
  Future<void> save() async {
    final stagedPath = picked?.path;
    if (stagedPath == null || stagedPath.isEmpty) {
      showToast('영상 파일을 먼저 선택해 주세요.');
      return;
    }

    // 변환이 실패하면 예전엔 예외가 그대로 밖으로 나갔다. 안내하고 멈춘다.
    final String normalizedPath;
    try {
      normalizedPath = await audioToVideo.ensureMp4(stagedPath);
    } catch (e, st) {
      AppLogger.e('저장 전 영상 변환 실패', error: e, stackTrace: st);
      showToast(userErrorMessage(e,
          fallback: '영상을 준비하지 못했어요. 다른 파일로 다시 시도해 주세요.'));
      return;
    }

    // ClipFormData 생성
    final formData = _buildFormData(filePath: normalizedPath);

    // Domain Validator로 검증
    final validationResult = _validator.validateForm(formData);
    if (!validationResult.isValid) {
      showToast(validationResult.errorMessage!);
      return;
    }

    _setSaving(true);
    try {
      await _saveClip(
        formData: formData,
        mode: _mode,
        stagedFilePath: normalizedPath,
      );
      showToast(isEdit ? '업데이트 완료!' : '저장 완료!');
      _saveState = EditSaveState.success;
      _shouldClose = true;
      _closeResult = true;
      notifyListeners();
    } catch (e, st) {
      AppLogger.e('클립 저장 실패', error: e, stackTrace: st);
      showToast(userErrorMessage(e,
          fallback: '저장하지 못했어요. 잠시 뒤 다시 시도해 주세요.'));
      _saveState = EditSaveState.error;
      notifyListeners();
    }
    // finally에서 _setSaving(false)를 부르고 있었다. 그건 무조건 idle을 넣기
    // 때문에 방금 넣은 success와 error를 바로 덮어썼다. 두 상태는 밖에서
    // 한 번도 보이지 않았다. 지금은 성공·실패 상태가 그대로 남는다.
    // isSaving은 saving일 때만 참이라 저장 버튼은 똑같이 다시 열린다.
  }

  /// 현재 UI 상태에서 ClipFormData를 빌드합니다.
  ClipFormData _buildFormData({String? filePath}) {
    final segments = segmentForms
        .map((f) => SegmentInput(
              start: f.startCtl.text.trim(),
              end: f.endCtl.text.trim(),
              original: f.originalCtl.text.trim(),
              pron: f.pronCtl.text.trim(),
              ko: f.koCtl.text.trim(),
            ))
        .toList();

    final colName = collectionNameCtl.text.trim();

    return ClipFormData(
      collectionName: colName.isEmpty ? null : colName,
      clipTitle: titleCtl.text.trim(),
      durationMs: int.tryParse(durationCtl.text.trim()),
      segments: segments,
      tags: tags,
      filePath: filePath ?? picked?.path,
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // 편집 모드 로드 (UseCase 위임)
  // ─────────────────────────────────────────────────────────────────
  Future<void> _loadForEdit(int clipId) async {
    try {
      final result = await _loadClipForEdit(clipId);

      // 모드 설정
      _mode = result.mode;

      // UI에 데이터 채우기
      final form = result.formData;
      collectionNameCtl.text =
          form.collectionName ?? initialCollectionName ?? '';
      titleCtl.text = form.clipTitle;

      if (form.durationMs != null && form.durationMs! > 0) {
        durationCtl.text = form.durationMs.toString();
      }

      // 태그
      tags.clear();
      tags.addAll(form.tags);

      // 세그먼트
      //
      // EditSegmentMixin은 segmentForms와 겹침 판정용 스냅샷 목록을 짝으로
      // 관리한다. 여기서는 그 믹스인을 건너뛰고 segmentForms를 직접
      // clear/add 하고 있었다. 그래서 (1) 버린 폼의 컨트롤러가 해제되지 않고,
      // (2) 스냅샷은 초기 폼 한 개짜리로 남은 채 폼만 N개가 되어, 편집으로
      // 연 클립에서는 "겹침 방지 자동 조정"이 엉뚱한 구간을 기준으로 돌았다.
      // 믹스인이 제공하는 경로로 지나가게 한다.
      disposeSegmentForms();
      if (form.segments.isEmpty) {
        initSegmentForms();
      } else {
        _fillSegmentsFromDraft(form.segments);
      }

      // 기존 파일 경로가 있으면 Step 1에 표시
      if (form.filePath != null && form.filePath!.isNotEmpty) {
        await setExistingFile(form.filePath!);
      }
    } catch (e, st) {
      AppLogger.e('편집할 클립 불러오기 실패', error: e, stackTrace: st);
      showToast(userErrorMessage(e, fallback: '클립을 불러오지 못했어요.'));
    } finally {
      _isLoadingForEdit = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 유틸리티
  // ─────────────────────────────────────────────────────────────────
  void _setSaving(bool saving) {
    _saveState = saving ? EditSaveState.saving : EditSaveState.idle;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────
  // Dispose
  // ─────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    titleCtl.dispose();
    collectionNameCtl.dispose();
    durationCtl.dispose();
    tagsCtl.dispose();
    for (final f in segmentForms) {
      f.dispose();
    }
    super.dispose();
  }
}

/// 자동 자막 가격. 10초에 1패롯, 올림. functions/src/pricing.ts의 captionCost와 같다.
int captionParrotCost(int durationMs) {
  final seconds = (durationMs / 1000).ceil();
  if (seconds <= 0) return 0;
  return (seconds + 9) ~/ 10;
}
