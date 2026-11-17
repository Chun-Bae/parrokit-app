import 'package:shared_preferences/shared_preferences.dart';

import 'package:parrokit/core/content/word_search_url.dart';

class AppConfig {
  static const int _defaultLocalKeepSpaceBytes = 1024 * 1024 * 1024;

  /// 플레이어
  /// 플레이어를 '전체' 범위로 열지(참) '구간'으로 열지(거짓).
  /// 저장 키는 예전 이름('segmentLoop') 그대로다. 예전에 저장한 값을 그대로
  /// 읽으려고 키는 두고 이름만 뜻에 맞췄다(5차 353). 이름과 뜻이 뒤집혀 있어
  /// 쓰는 쪽이 헷갈렸다.
  static bool playWholeClip = false;

  /// 구간을 끝에서 다시 돌릴지. 저장 키는 예전 이름('repeatAll') 그대로다.
  static bool loopSegment = false;
  static bool showSubtitles = true; // 자막 표시(플레이어)
  static double defaultPlaybackRate = 1.0; // 기본 재생 속도
  static bool pauseEachLine = false; // 전체 재생에서 자막 한 줄마다 멈춤

  /// 단어를 웹에서 찾을 때 어디서 찾을지(5차, 사용자 요청).
  static WordSearchSite wordSearchSite = WordSearchSite.naver;

  /// 쇼츠
  static bool autoNext = true; // 자동 넘기기
  static bool shortsShowSubtitles = true; // 자막 표시(쇼츠)

  /// 보관함: 마지막으로 본 탭(true면 둘러보기, false면 내 문장/내 단어)
  static bool sentenceExplore = true;
  static bool wordExplore = false;

  /// 보관함: 마지막으로 본 상단 탭(0 문장, 1 클립, 2 단어)
  static int libraryTab = 0;

  // '새 클립 화면' 스위치는 없앴다(사용자 결정 2026-11-17). 클립 탭은
  // 새 화면만 쓴다. 예전에 저장해 둔 newClipLibrary 값은 읽지 않는다.

  /// 저장 공간
  static int localKeepSpaceBytes = _defaultLocalKeepSpaceBytes;

  /// 앱 테마는 프로바이더 관리
  static Future<void> loadFromPrefs() async {
    final p = await SharedPreferences.getInstance();

    playWholeClip = p.getBool('segmentLoop') ?? false;
    loopSegment = p.getBool('repeatAll') ?? false;
    showSubtitles = p.getBool('showSubtitles') ?? true;
    defaultPlaybackRate = p.getDouble('defaultPlaybackRate') ?? 1.0;
    pauseEachLine = p.getBool('pauseEachLine') ?? false;

    wordSearchSite = WordSearchSite.fromStorage(p.getString('wordSearchSite'));

    autoNext = p.getBool('autoNext') ?? true;
    shortsShowSubtitles = p.getBool('shortsShowSubtitles') ?? true;
    sentenceExplore = p.getBool('sentenceExplore') ?? true;
    wordExplore = p.getBool('wordExplore') ?? false;
    libraryTab = (p.getInt('libraryTab') ?? 0).clamp(0, 2);
    localKeepSpaceBytes =
        p.getInt('localKeepSpaceBytes') ?? _defaultLocalKeepSpaceBytes;
  }

  static Future<void> saveToPrefs() async {
    final p = await SharedPreferences.getInstance();

    await p.setBool('segmentLoop', playWholeClip);
    await p.setBool('repeatAll', loopSegment);
    await p.setBool('showSubtitles', showSubtitles);
    await p.setDouble('defaultPlaybackRate', defaultPlaybackRate);
    await p.setBool('pauseEachLine', pauseEachLine);

    await p.setString('wordSearchSite', wordSearchSite.storageKey);

    await p.setBool('autoNext', autoNext);
    await p.setBool('shortsShowSubtitles', shortsShowSubtitles);
    await p.setBool('sentenceExplore', sentenceExplore);
    await p.setBool('wordExplore', wordExplore);
    await p.setInt('libraryTab', libraryTab);
    await p.setInt('localKeepSpaceBytes', localKeepSpaceBytes);
  }
}
