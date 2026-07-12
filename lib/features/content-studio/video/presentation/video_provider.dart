import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';

import '../data/data_sources/video_remote_data_source.dart';
import '../data/repositories/video_generation_repository_impl.dart';
import '../domain/models/video_generation_models.dart';
import '../domain/usecases/check_video_operation_usecase.dart';
import '../domain/usecases/generate_video_usecase.dart';
import '../domain/usecases/list_recent_video_generations_usecase.dart';

class VideoProvider extends ChangeNotifier {
  static const int dialogueMaxLength = 100;

  late final GenerateVideoUseCase _generateUseCase;
  late final CheckVideoOperationUseCase _checkOperationUseCase;
  late final ListRecentVideoGenerationsUseCase _listRecentUseCase;
  final UserProvider userProvider;

  VideoProvider({
    required this.userProvider,
    GenerateVideoUseCase? generateUseCase,
    CheckVideoOperationUseCase? checkOperationUseCase,
    ListRecentVideoGenerationsUseCase? listRecentUseCase,
  }) {
    final repository = VideoGenerationRepositoryImpl(VideoRemoteDataSource());
    _generateUseCase = generateUseCase ?? GenerateVideoUseCase(repository);
    _checkOperationUseCase =
        checkOperationUseCase ?? CheckVideoOperationUseCase(repository);
    _listRecentUseCase =
        listRecentUseCase ?? ListRecentVideoGenerationsUseCase(repository);
  }

  String _dialogue = '';
  String get dialogue => _dialogue;

  String _scenePrompt = '';
  String get scenePrompt => _scenePrompt;

  String _ratio = '16:9';
  String get ratio => _ratio;

  int _duration = 5;
  int get duration => _duration;

  String _model = veo31LiteModelId;
  String get model => _model;

  String _resolution = veo31Resolution720p;
  String get resolution => _resolution;

  /// 1080p는 8초 영상만 지원하므로, 길이 선택을 8초로 고정해야 하는지 여부.
  bool get isDurationLocked => veo31ResolutionRequiresEightSeconds(_resolution);

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  String? _generatedFilePath;
  String? get generatedFilePath => _generatedFilePath;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isExportingForCaptioning = false;
  bool get isExportingForCaptioning => _isExportingForCaptioning;

  List<VideoGenerationRecord> _recentVideos = const [];
  List<VideoGenerationRecord> get recentVideos => _recentVideos;

  Timer? _pollingTimer;
  Timer? _recentRefreshTimer;
  int _pendingCost = 0;

  /// 현재 모델/해상도/길이 설정 기준 예상 소모 패롯.
  int get estimatedCost => veo31GenerationCost(
        modelId: _model,
        durationSeconds: _duration,
        resolution: _resolution,
      );

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _recentRefreshTimer?.cancel();
    super.dispose();
  }

  void updateDialogue(String newDialogue) {
    if (newDialogue.length > dialogueMaxLength) {
      _dialogue = newDialogue.substring(0, dialogueMaxLength);
    } else {
      _dialogue = newDialogue;
    }
    notifyListeners();
  }

  void updateScenePrompt(String newPrompt) {
    _scenePrompt = newPrompt;
    notifyListeners();
  }

  void updateRatio(String newRatio) {
    _ratio = newRatio;
    notifyListeners();
  }

  void updateDuration(int newDuration) {
    if (isDurationLocked) return;
    _duration = newDuration;
    notifyListeners();
  }

  void updateModel(String newModel) {
    _model = newModel;
    notifyListeners();
  }

  void updateResolution(String newResolution) {
    _resolution = newResolution;
    if (veo31ResolutionRequiresEightSeconds(newResolution)) {
      _duration = 8;
    }
    notifyListeners();
  }

  void showSavedVideo(String videoUrl) {
    _generatedFilePath = videoUrl;
    _errorMessage = null;
    notifyListeners();
  }

  Future<String?> prepareGeneratedVideoForCaptioning() async {
    final source = _generatedFilePath;
    if (source == null || source.isEmpty) {
      return null;
    }

    if (source.startsWith('file://')) {
      return Uri.parse(source).toFilePath();
    }

    if (source.startsWith('/')) {
      return source;
    }

    if (source.startsWith('data:')) {
      return null;
    }

    _isExportingForCaptioning = true;
    notifyListeners();

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(source));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('download failed: ${response.statusCode}');
      }

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/parrokit_caption_video_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      final sink = file.openWrite();
      await response.pipe(sink);
      await sink.close();
      return file.path;
    } catch (e, stack) {
      AppLogger.e('[VideoProvider][ExportToCaptioning] error reason=$e',
          error: e, stackTrace: stack);
      _errorMessage = '캡션 편집기로 보낼 영상을 준비하지 못했습니다.';
      notifyListeners();
      return null;
    } finally {
      _isExportingForCaptioning = false;
      notifyListeners();
    }
  }

  Future<void> loadRecentVideos() async {
    AppLogger.i('[VideoProvider][Recent] start');
    try {
      _recentVideos = await _listRecentUseCase.call();
      for (final record in _recentVideos) {
        AppLogger.i(
          '[VideoProvider][Recent] item uid=${record.uid} operator=${record.isOperatorAccount} generationId=${record.generationId}',
        );
      }
      AppLogger.i(
          '[VideoProvider][Recent] success count=${_recentVideos.length}');
      _syncRecentRefreshTimer();
      notifyListeners();
    } catch (e, stack) {
      AppLogger.e('[VideoProvider][Recent] error reason=$e',
          error: e, stackTrace: stack);
    }
  }

  void _syncRecentRefreshTimer() {
    final shouldRefresh = _recentVideos.any((record) {
      return record.hasExpiryCountdown;
    });

    if (!shouldRefresh) {
      _recentRefreshTimer?.cancel();
      _recentRefreshTimer = null;
      return;
    }

    if (_recentRefreshTimer != null) {
      return;
    }

    _recentRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  Future<void> generateVideo() async {
    if (_dialogue.trim().isEmpty && _scenePrompt.trim().isEmpty) return;

    final cost = veo31GenerationCost(
      modelId: _model,
      durationSeconds: _duration,
      resolution: _resolution,
    );
    if (userProvider.coins < cost) {
      showToast('패롯이 부족합니다. (필요 $cost / 보유 ${userProvider.coins})');
      return;
    }
    _pendingCost = cost;

    _isGenerating = true;
    _errorMessage = null;
    _generatedFilePath = null;
    notifyListeners();

    AppLogger.i(
        '[VideoProvider][Generate] start ratio=$_ratio duration=$_duration model=$_model resolution=$_resolution');

    try {
      final operationName = await _generateUseCase.call(
        dialogue: _dialogue,
        scenePrompt: _scenePrompt,
        ratio: _ratio,
        duration: _duration,
        model: _model,
        resolution: _resolution,
        debug: false,
      );

      AppLogger.i(
          '[VideoProvider][Generate] success operationName=$operationName');
      _startPolling(operationName);
    } catch (e, stack) {
      AppLogger.e('[VideoProvider][Generate] error reason=$e',
          error: e, stackTrace: stack);
      _errorMessage = e.toString();
      _isGenerating = false;
      _pendingCost = 0;
      notifyListeners();
    }
  }

  void _startPolling(String operationName) {
    AppLogger.i('[VideoProvider][Polling] start operationName=$operationName');
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      AppLogger.d(
          '[VideoProvider][Polling] check operationName=$operationName');
      try {
        final result = await _checkOperationUseCase.call(operationName);
        if (result['done'] == true) {
          timer.cancel();
          if (result['error'] != null) {
            AppLogger.e(
                '[VideoProvider][Polling] error reason=${result['error']}');
            _errorMessage = result['error'].toString();
            _pendingCost = 0;
          } else {
            AppLogger.i(
                '[VideoProvider][Polling] success videoUri=${result['videoUri']}');
            _generatedFilePath = result['videoUri'];
            if (_pendingCost > 0) {
              userProvider.addCoins(-_pendingCost);
              showToast('영상 생성 완료! ($_pendingCost패롯 소모)');
            }
            _pendingCost = 0;
            await loadRecentVideos();
          }
          _isGenerating = false;
          notifyListeners();
        }
      } catch (e, stack) {
        AppLogger.e('[VideoProvider][Polling] error reason=$e',
            error: e, stackTrace: stack);
        timer.cancel();
        _errorMessage = 'Polling failed: $e';
        _isGenerating = false;
        _pendingCost = 0;
        notifyListeners();
      }
    });
  }
}
