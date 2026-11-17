import 'package:parrokit/core/shared/utils/korean_josa.dart';

// 자주 쓰는 실패 안내(5차 417).
//
// 같은 문장이 화면마다 손으로 적혀 있었다('저장하지 못했어요. 다시 시도해
// 주세요.'는 세 파일, '처리하지 못했어요...'도 세 파일). 한 곳만 다듬으면
// 나머지는 예전 말로 남아, 이번 주 내내 고쳐 온 어긋남이 다시 생긴다.
// 말은 지금 쓰던 것을 그대로 옮겨 적었다.

/// 무언가를 저장하지 못했을 때.
const String saveFailedMessage = '저장하지 못했어요. 다시 시도해 주세요.';

/// 문장을 저장하지 못했을 때(무엇을 저장하려 했는지 말한다).
const String sentenceSaveFailedMessage = '문장을 저장하지 못했어요. 다시 시도해 주세요.';

/// 무엇이 안 됐는지 딱 집어 말할 수 없을 때.
const String actionFailedMessage = '처리하지 못했어요. 다시 시도해 주세요.';

/// 목록·내용을 불러오지 못했을 때. 뒤에 '다시 시도' 단추를 함께 둔다.
const String loadFailedMessage = '불러오지 못했어요.';

/// 지우지 못했을 때. 커뮤니티의 deleteFailedMessage와 같은 말이다.
const String deleteFailedShortMessage = '지우지 못했어요. 잠시 뒤 다시 해 주세요.';

// ── 클립을 옮기고 지울 때(5차 424) ───────────────────────────────────
//
// 진행 막대(StorageTransferOverlay) 하나에 실패 안내 일곱 가지가 있었는데
// 끝말이 '잠시 뒤 다시 해 주세요'와 '잠시 뒤 다시 시도해 주세요'로 갈려
// 있었다. 무엇을 하다 막혔는지에 따라 말투가 바뀌면 안 된다.

/// 같은 화면에서 쓰는 끝말. 하나로 맞춘다.
const String retryLaterSuffix = '잠시 뒤 다시 해 주세요.';

/// 무엇을 지우지 못했는지 집어 말할 때(폴더·그룹 등).
String deleteFailedMessageFor(String what) =>
    '${eulReul(what)} 지우지 못했어요. $retryLaterSuffix';

/// 여러 개를 지우다 중간에 막혔을 때.
const String deleteInterruptedMessage = '지우는 중 문제가 생겼어요. $retryLaterSuffix';

/// 여러 개를 옮기다 중간에 막혔을 때.
const String moveInterruptedMessage = '옮기는 중 문제가 생겼어요. $retryLaterSuffix';

/// 저장 자리를 바꾸지 못했을 때. 어디로 옮기려 했는지 함께 말한다.
const String serverSaveFailedMessage = '서버에 저장하지 못했어요. $retryLaterSuffix';
const String driveSaveFailedMessage =
    'Google Drive에 저장하지 못했어요. $retryLaterSuffix';
const String deviceMoveFailedMessage = '내 기기로 옮기지 못했어요. $retryLaterSuffix';

// ── 여러 화면이 함께 쓰는 짧은 안내(5차 444) ────────────────────────
//
// 아래 넷은 각각 두 자리에 손으로 적혀 있었다.

/// 설정을 저장하지 못했을 때(알림 설정, 문장 설정).
const String settingsSaveFailedMessage = '설정을 저장하지 못했어요. 다시 시도해 주세요.';

/// 고친 것이 없어 저장할 까닭이 없을 때(프로필 편집, 문장 고치기).
const String noChangesMessage = '바뀐 것이 없어요.';

/// 문장 칸이 비었을 때(문장 추가, 문장 고치기).
const String sentenceNeededMessage = '문장을 적어 주세요.';

/// 아직 만들지 않은 기능을 불렀을 때(클립 검색, 문장 도우미).
const String comingSoonMessage = '아직 준비 중이에요';

/// 지우기 확인 창에 덧붙이는 한 줄(클립 여러 개 지우기, 단어 지우기).
const String cannotUndoMessage = '지우면 되돌릴 수 없어요.';

/// 환전이 막혔을 때(환전소 화면과 그 뒤 서비스).
const String exchangeFailedMessage = '환전하지 못했어요. 다시 시도해 주세요.';
