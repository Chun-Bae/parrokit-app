// 화면에 적힌 한도 숫자가 실제 규칙과 같은지 지킨다(5차 434).
//
// 같은 한도를 코드와 화면이 따로 적고 있었다. 한 곳만 바꾸면 화면은 예전
// 숫자를 말한다. 투표 항목 5개, 읽을 글 240자, 자동 자막 5분이 그랬다.
// 433에서는 투표 안내가 실제 조건(2개 미만)과 달리 '2개 넘게'라고 적혀
// 있기도 했다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/speaking_xp.dart';
import 'package:parrokit/features/community/shared/presentation/write_blocked_reason.dart';
import 'package:parrokit/features/content-studio/tts/domain/validators/tts_validator.dart';
import 'package:parrokit/features/content-studio/captioning/domain/validators/clip_validator.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('투표 항목 수를 화면이 손으로 적지 않는다', () {
    expect(voteTooManyOptionsMessage(maxVoteOptions), '항목은 5개까지 넣을 수 있어요.');

    final screen =
        _code('lib/features/community/vote/presentation/vote_write_screen.dart');
    expect(screen, contains('maxVoteOptions'));
    expect(screen, isNot(contains("'항목은 5개까지")));
    expect(screen, isNot(contains('length >= 5')));
  });

  test("투표 항목을 '보기'라 부르지 않는다", () {
    // 화면은 '투표 대상 항목', '항목 추가하기'라고 부른다.
    expect(writeNeedsTwoOptionsMessage, contains('항목'));
    expect(writeNeedsFilledOptionsMessage, contains('항목'));
  });

  test('읽을 글 길이를 네 곳이 따로 적지 않는다', () {
    expect(maxTtsTextLength, 240);
    expect(ttsTextTooLongMessage(maxTtsTextLength), '읽을 글은 240자까지 쓸 수 있어요.');

    for (final path in [
      'lib/features/content-studio/tts/presentation/providers/tts_provider.dart',
      'lib/features/content-studio/tts/presentation/screens/tts_screen.dart',
    ]) {
      final code = _code(path);
      expect(code, contains('maxTtsTextLength'), reason: path);
      expect(code, isNot(contains('240')), reason: path);
    }
  });

  test('자동 자막 길이 한도를 두 곳이 따로 적지 않는다', () {
    expect(ClipValidator.tooLongMessage(), '5분 이하 영상만 넣을 수 있어요.');
    expect(ClipValidator.tooLongMessage(3 * 60 * 1000), '3분 이하 영상만 넣을 수 있어요.');

    final service = _code(
        'lib/features/content-studio/captioning/data/services/remote_caption_draft_service.dart');
    expect(service, contains('ClipValidator.maxDurationMs'));
    expect(service, isNot(contains('5분')));
    expect(service, isNot(contains('처리할 수 있습니다')));
  });

  test('홈 도움말이 옛 XP 규칙을 적지 않는다', () {
    // 566에서 XP를 '한 번만 생기는 일'로 바꾸고 한 단계 값도 15에서 10씩
    // 늘게 했는데, 도움말만 '점수만큼 XP(100점이면 1 XP)'와 '10 XP마다
    // 레벨'로 남아 있었다. 머리의 막대는 '6 / 25 XP'였다(5차).
    expect(xpForLevel(1), 25 - levelXpStep);
    expect(xpForLevel(2), 25);
    expect(xpPerLevel, isNot(xpForLevel(2)));

    final help = _code(
        'lib/features/home/dashboard/presentation/stage_preview_screen.dart');
    expect(help.contains('10 XP마다'), isFalse);
    expect(help.contains('100점이면 1 XP'), isFalse);
  });
}
