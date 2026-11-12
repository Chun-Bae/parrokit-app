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

import 'package:path_provider/path_provider.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';

class CacheService {
  CacheService._();

  static final CacheService instance = CacheService._();

  /// 캐시(임시 디렉터리) 현재 용량 계산 (bytes)
  Future<int> getCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (!await tempDir.exists()) return 0;

      int totalSize = 0;
      await for (final entity
          in tempDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      // 용량을 못 읽으면 더보기 화면에 잘못된 수치가 뜬다.
      AppLogger.e('[Cache] 용량 계산 실패', error: e);
      return 0;
    }
  }

  /// 캐시 삭제 (임시 디렉터리 비우기)
  Future<void> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
        // 삭제 후 디렉터리가 필요할 수 있으므로 다시 생성
        await tempDir.create();
      }
    } catch (e) {
      // 사용자가 캐시 삭제를 눌렀는데 아무 일도 일어나지 않은 경우다.
      AppLogger.e('[Cache] 캐시 삭제 실패', error: e);
      // 일부 파일 삭제 실패는 무시 (시스템 파일 등)
    }
  }

  /// 바이트 단위를 보기 좋은 문자열로 변환 (예: 12.5 MB)
  String formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
