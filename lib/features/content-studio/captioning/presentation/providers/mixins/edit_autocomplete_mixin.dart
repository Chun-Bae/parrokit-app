// ============================================================================
// lib/features/content-studio/captioning/presentation/providers/mixins/edit_autocomplete_mixin.dart
// ============================================================================
//
// [역할]
// 자동완성 데이터 로드 mixin.
// 컬렉션 이름 목록 로드.
//
// [레이어]
// Presentation Layer > Provider > Mixin
// ============================================================================

import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/data/local/dao/collections_dao.dart';

/// 자동완성 데이터 로드 mixin.
mixin EditAutocompleteMixin on ChangeNotifier {
  // 의존성 (추상 getter)
  CollectionsDao get collectionsDao;

  // ─────────────────────────────────────────────────────────────────
  // 상태
  // ─────────────────────────────────────────────────────────────────
  List<String> allCollectionNames = [];

  // ─────────────────────────────────────────────────────────────────
  // 데이터 로드
  // ─────────────────────────────────────────────────────────────────

  /// DB에 저장된 모든 컬렉션 이름 목록을 로드합니다. (자동완성용)
  /// 클립 생성/편집은 항상 로컬 클립을 다루므로 로컬 콜렉션 이름만 로드합니다.
  Future<void> loadCollectionNames() async {
    try {
      // 보관함은 위치가 달라도 이름이 같으면 한 폴더로 보여준다. 폴더 고르기도
      // 모든 위치의 폴더 이름을 보여준다. 고르면 로컬 컬렉션이 같은 이름으로
      // 생겨 보관함에서 한 폴더로 합쳐진다.
      final names = <String>{
        for (final mode in const [
          ClipStorageConstants.storageModeLocal,
          ClipStorageConstants.storageModeServer,
          ClipStorageConstants.storageModeGoogleDrive,
        ])
          ...await collectionsDao.fetchAllNames(mode),
      };
      allCollectionNames = names.toList()..sort();
      notifyListeners();
    } catch (e, st) {
      // 폴더 목록은 고르기 창을 채울 뿐이라, 실패해도 새 폴더는 만들 수 있다.
      AppLogger.e('폴더 목록 불러오기 실패', error: e, stackTrace: st);
      showToast('폴더 목록을 불러오지 못했어요. 새 폴더는 만들 수 있어요.');
    }
  }
}
