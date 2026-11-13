// ============================================================================
// lib/features/content-studio/captioning/data/constants/edit_strings.dart
// ============================================================================
//
// [역할]
// Clip Edit에서 사용하는 UI 문자열 상수 모음.
// 라벨, 힌트, 헬퍼 텍스트 등을 한 곳에서 관리.
//
// [레이어]
// Data Layer > Constants
// ============================================================================

/// Clip Edit UI 문자열 상수.
class EditStrings {
  EditStrings._();

  // 컬렉션 섹션
  // 보관함에서는 컬렉션을 '폴더'로 보여준다. 폴더 안의 폴더는 고르기 창에서 만든다(5차).
  static const collectionLabel = '폴더 *';
  static const collectionHint = '눌러서 폴더 고르기';

  // 클립 제목 섹션
  static const clipTitleLabel = '클립 제목 *';
  static const clipTitleHint = '클립 제목을 입력해주세요.';

  // 태그 섹션
  static const addTagButtonLabel = '태그 추가';
  static const tagsLabel = '태그';
  static const tagsHint = '태그를 입력해주세요.';
  static const clearAllTagsButtonLabel = '모두 지우기';

  // 세그먼트 섹션
  static const segmentsSectionTitle = '자막 정보';
  static const segmentsNotice = '소음이나 음악이 많은 영상에선 자동 자막 정확도가 낮을 수 있어요.';
  static const sttButtonLabel = '자동 자막 생성';
  static const addSegmentButtonLabel = '구간 추가';
  static const removeSegmentButtonLabel = '구간 삭제';

  // 세그먼트 카드
  static String segmentCardTitle(int index) => '구간 #$index';
  static const pronLabel = '발음';
  static const pronHint = '발음을 입력해주세요.';
  static const originalLabel = '원문';
  static const originalHint = '원문을 입력해주세요.';
  static const koLabel = '해석';
  static const koHint = '해석을 입력해주세요.';
}
