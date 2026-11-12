import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const int _defaultLocalKeepSpaceBytes = 1024 * 1024 * 1024;

  /// 플레이어
  static bool segmentLoop = false; // 구간 재생
  static bool repeatAll = false; // 반복 재생(전체)
  static bool showSubtitles = true; // 자막 표시(플레이어)
  static double defaultPlaybackRate = 1.0; // 기본 재생 속도

  /// 쇼츠
  static bool autoNext = true; // 자동 넘기기
  static bool shortsShowSubtitles = true; // 자막 표시(쇼츠)

  /// 보관함: 마지막으로 본 탭(true면 둘러보기, false면 내 문장/내 단어)
  static bool sentenceExplore = true;
  static bool wordExplore = false;

  /// 보관함: 마지막으로 본 상단 탭(0 문장, 1 클립, 2 단어)
  static int libraryTab = 0;

  /// 보관함 클립 탭을 새 화면(폴더 + 모든 클립)으로 볼지. 끄면 예전 화면.
  /// 보관함이 다른 탭에 떠 있는 채로 바뀌므로 알림을 받을 수 있게 둔다.
  static final ValueNotifier<bool> newClipLibraryListenable =
      ValueNotifier<bool>(true);
  static bool get newClipLibrary => newClipLibraryListenable.value;

  /// 4차 개편 화면을 쓸지. 끄면 개편 전 화면으로 돌아간다. 더보기 > 앱 > "새 디자인".
  static final ValueNotifier<bool> newDesignListenable =
      ValueNotifier<bool>(true);
  static bool get newDesign => newDesignListenable.value;
  static set newDesign(bool value) => newDesignListenable.value = value;
  static set newClipLibrary(bool value) =>
      newClipLibraryListenable.value = value;

  /// 저장 공간
  static int localKeepSpaceBytes = _defaultLocalKeepSpaceBytes;

  /// 앱 테마는 프로바이더 관리
  static Future<void> loadFromPrefs() async {
    final p = await SharedPreferences.getInstance();

    segmentLoop = p.getBool('segmentLoop') ?? false;
    repeatAll = p.getBool('repeatAll') ?? false;
    showSubtitles = p.getBool('showSubtitles') ?? true;
    defaultPlaybackRate = p.getDouble('defaultPlaybackRate') ?? 1.0;

    autoNext = p.getBool('autoNext') ?? true;
    shortsShowSubtitles = p.getBool('shortsShowSubtitles') ?? true;
    sentenceExplore = p.getBool('sentenceExplore') ?? true;
    wordExplore = p.getBool('wordExplore') ?? false;
    libraryTab = (p.getInt('libraryTab') ?? 0).clamp(0, 2);
    newClipLibrary = p.getBool('newClipLibrary') ?? true;
    newDesign = p.getBool('newDesign') ?? true;
    localKeepSpaceBytes =
        p.getInt('localKeepSpaceBytes') ?? _defaultLocalKeepSpaceBytes;
  }

  static Future<void> saveToPrefs() async {
    final p = await SharedPreferences.getInstance();

    await p.setBool('segmentLoop', segmentLoop);
    await p.setBool('repeatAll', repeatAll);
    await p.setBool('showSubtitles', showSubtitles);
    await p.setDouble('defaultPlaybackRate', defaultPlaybackRate);

    await p.setBool('autoNext', autoNext);
    await p.setBool('shortsShowSubtitles', shortsShowSubtitles);
    await p.setBool('sentenceExplore', sentenceExplore);
    await p.setBool('wordExplore', wordExplore);
    await p.setInt('libraryTab', libraryTab);
    await p.setBool('newClipLibrary', newClipLibrary);
    await p.setBool('newDesign', newDesign);
    await p.setInt('localKeepSpaceBytes', localKeepSpaceBytes);
  }
}
