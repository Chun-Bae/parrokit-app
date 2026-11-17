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
///
/// 안내는 앱의 다른 화면과 같은 말투로 적는다('~해주세요.'가 아니라
/// '~ 적어 주세요'). 지우는 동작은 어디서나 '지우기'다(5차).
class EditStrings {
  EditStrings._();

  // 컬렉션 섹션
  // 보관함에서는 컬렉션을 '폴더'로 보여준다. 폴더 안의 폴더는 고르기 창에서 만든다(5차).
  static const collectionLabel = '폴더 *';
  static const collectionHint = '눌러서 폴더 고르기';

  // 클립 제목 섹션
  static const clipTitleLabel = '클립 제목 *';
  static const clipTitleHint = '클립 제목을 적어 주세요';

  // 태그 섹션
  static const addTagButtonLabel = '태그 추가';
  static const tagsLabel = '태그';
  static const tagsHint = '태그를 적어 주세요';

  /// 이미 넣은 태그를 다시 넣으려 할 때(5차 361).
  static const duplicateTagMessage = '이미 넣은 태그예요.';
  static const clearAllTagsButtonLabel = '모두 지우기';

  // 세그먼트 섹션
  static const segmentsSectionTitle = '자막 정보';
  static const segmentsNotice = '소음이나 음악이 많은 영상에선 자동 자막 정확도가 낮을 수 있어요.';
  // 같은 기능을 네 가지 이름으로 부르고 있었다(5차 427):
  // '자동 자막 생성', '자막 자동 생성', '자동 자막 생성 중', 'AI 자막 생성 중...'.
  // 앱은 '만들기'를 쓴다(음성 만들기·영상 만들기·클립 만들기).
  static const sttButtonLabel = '자동 자막 만들기';

  /// 확인 창 제목. 단추와 같은 이름을 쓴다.
  static const sttConfirmTitle = sttButtonLabel;

  /// 만드는 동안 보여 주는 글.
  static const sttRunningLabel = '자동 자막 만드는 중';

  /// 만들지 못했을 때.
  static const sttFailedMessage = '자동 자막을 만들지 못했어요. 잠시 뒤 다시 시도해 주세요.';
  static const addSegmentButtonLabel = '구간 추가';
  static const removeSegmentButtonLabel = '구간 지우기';

  // 세그먼트 카드
  static String segmentCardTitle(int index) => '구간 #$index';
  static const pronLabel = '발음';
  static const pronHint = '발음을 적어 주세요';
  static const originalLabel = '원문';
  static const originalHint = '원문을 적어 주세요';
  static const koLabel = '해석';
  static const koHint = '해석을 적어 주세요';
}
