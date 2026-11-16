// 새 클립 화면의 태그 칸(5차 361).
//
// 이미 넣은 태그를 다시 적으면 칸만 비워지고 아무 일도 일어나지 않았다.
// 칸이 비었을 때도 '추가'가 켜져 있어서 눌러도 아무 반응이 없었다.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/content-studio/captioning/data/constants/edit_strings.dart';
import 'package:parrokit/features/content-studio/captioning/presentation/providers/mixins/edit_tag_mixin.dart';

class _Tags extends ChangeNotifier with EditTagMixin {}

void main() {
  test('새 태그는 더하고 true를 돌려준다', () {
    final tags = _Tags();
    expect(tags.addTag('여행'), isTrue);
    expect(tags.tags, ['여행']);
  });

  test('이미 있는 태그는 더하지 않고 false를 돌려준다', () {
    final tags = _Tags();
    tags.addTag('여행');
    var notified = 0;
    tags.addListener(() => notified++);
    expect(tags.addTag(' 여행 '), isFalse);
    expect(tags.tags, ['여행']);
    expect(notified, 0, reason: '바뀐 것이 없으면 알리지 않는다');
  });

  test('빈 글은 더하지 않는다', () {
    final tags = _Tags();
    expect(tags.addTag('   '), isFalse);
    expect(tags.tags, isEmpty);
  });

  test('화면은 겹친 태그를 말해 주고, 빈 칸에서는 추가를 꺼 둔다', () {
    final code = File(
            'lib/features/content-studio/captioning/presentation/sections/metadata_inputs_section.dart')
        .readAsStringSync();
    expect(code, contains('EditStrings.duplicateTagMessage'));
    expect(code, contains("value.text.trim().isEmpty ? null"));
  });

  test('겹친 태그 안내 글', () {
    expect(EditStrings.duplicateTagMessage, '이미 넣은 태그예요.');
  });
}
