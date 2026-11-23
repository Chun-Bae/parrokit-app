// ============================================================================
// lib/core/services/cache_service.dart
// ============================================================================
//
// [역할]
// 앱의 임시 파일(캐시)을 관리하는 서비스.
//
// [기능]
// 1. 임시 디렉터리(tmp) 용량 계산
// 2. 임시 파일 삭제
//
// [레이어]
// Core Layer > Services
// ============================================================================

import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:path_provider/path_provider.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';

class CacheService {
  CacheService._();

  static final CacheService instance = CacheService._();

  /// 마지막으로 잰 임시 파일 크기. 아직 안 쟀으면 null.
  ///
  /// 더보기의 '임시 파일' 칸과 저장 용량 시트가 같은 값을 보여야 한다
  /// (5차 450, 477). 전에는 각자 제 시점에 재서, 그 사이에 임시 파일이
  /// 늘면 한 화면 안에서 '34 MB'와 '38 MB'가 같이 보였다. 자동 자막을
  /// 한 번 만들면 바로 그렇게 됐다.
  final ValueNotifier<int?> sizeBytes = ValueNotifier<int?>(null);

  /// 캐시(임시 디렉터리) 현재 용량 계산 (bytes)
  ///
  /// iOS에서 `getTemporaryDirectory()`가 주는 곳은 `tmp`가 아니라
  /// `Library/Caches`다(기기에서 경로를 찍어 확인, 5차 566). `tmp`에
  /// 쌓이는 것은 `flutter run`이 넣는 디버그 산물이라 출시 빌드에는
  /// 없다. 여기서 세고 지우는 것은 Caches뿐이다.
  ///
  /// 한 칸이라도 못 읽으면 `list(recursive: true)`는 거기서 스트림을
  /// 끊는다. 그러면 지금까지 센 것까지 함께 버려져 0이 나왔다(5차 566).
  /// 기기에서 임시 폴더가 2.9GB인데 '62 MB'로 보였고, 정리한 뒤에는
  /// '0 B'가 됐다 - 둘 다 거짓이었다. 못 읽는 칸은 건너뛰고 나머지를
  /// 센다.
  Future<int> getCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (!await tempDir.exists()) return 0;

      final totalSize = await measureDirectory(tempDir);
      sizeBytes.value = totalSize;
      return totalSize;
    } catch (e) {
      // 용량을 못 읽으면 더보기 화면에 잘못된 수치가 뜬다.
      AppLogger.e('[Cache] 용량 계산 실패', error: e);
      return 0;
    }
  }

  /// 캐시 삭제 (임시 디렉터리 비우기)
  ///
  /// 임시 디렉터리 **자체**는 지우지 않는다. 통째로 지우려다 한 칸에서
  /// 막히면 아무것도 안 지워지는데, 전에는 그래 놓고 크기를 0으로
  /// 적어서 "정리했어요"가 거짓이 됐다(5차 566). 안의 것을 하나씩
  /// 지우고, 끝나면 **다시 재서** 남은 양을 그대로 적는다.
  ///
  /// 돌려주는 값은 지운 뒤 남은 바이트다. 0이 아니면 못 지운 것이 있다.
  Future<int> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (!await tempDir.exists()) {
        sizeBytes.value = 0;
        return 0;
      }
      await clearDirectoryContents(tempDir);
    } catch (e) {
      // 사용자가 캐시 삭제를 눌렀는데 아무 일도 일어나지 않은 경우다.
      AppLogger.e('[Cache] 캐시 삭제 실패', error: e);
    }
    // 지운 셈 치지 않는다. 실제로 남은 것을 다시 잰다.
    return getCacheSize();
  }

  /// 바이트 단위를 보기 좋은 문자열로 변환 (예: 12.5 MB)
}

/// [dir] 아래 파일 크기를 더한다. 못 읽는 칸은 0으로 보고 넘어간다.
///
/// `list(recursive: true)`는 한 칸에서 막히면 스트림을 끊어, 지금까지
/// 센 것까지 함께 버린다. 칸마다 따로 읽어 그 칸만 포기한다(5차 566).
Future<int> measureDirectory(Directory dir) async {
  final List<FileSystemEntity> entries;
  try {
    entries = await dir.list(followLinks: false).toList();
  } catch (_) {
    return 0;
  }
  var total = 0;
  for (final entity in entries) {
    if (entity is File) {
      try {
        total += await entity.length();
      } catch (_) {
        // 재는 사이에 사라진 파일. 없는 것으로 본다.
      }
    } else if (entity is Directory) {
      total += await measureDirectory(entity);
    }
  }
  return total;
}

/// [dir] **안**의 것을 하나씩 지운다. 디렉터리 자체는 남긴다.
///
/// 통째로 지우려다 한 칸에서 막히면 아무것도 안 지워진다. 막힌 칸만
/// 남기고 나머지는 지운다(5차 566).
Future<void> clearDirectoryContents(Directory dir) async {
  final List<FileSystemEntity> entries;
  try {
    entries = await dir.list(followLinks: false).toList();
  } catch (_) {
    return;
  }
  for (final entity in entries) {
    try {
      await entity.delete(recursive: true);
    } catch (_) {
      // 쓰는 중이거나 손댈 수 없는 칸. 건너뛰고 계속 지운다.
    }
  }
}
