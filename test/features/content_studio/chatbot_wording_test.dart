// 챗봇 화면 말(5차). 앱의 다른 곳처럼 한국어로 부르고 '영상'으로 쓴다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _chatbotDir = 'lib/features/content-studio/chat-bot';

/// 화면 글만 본다(주석·코드 이름은 그대로 둔다).
List<String> _uiStrings() {
  final strings = <String>[];
  for (final file in Directory(_chatbotDir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//')) continue;
      for (final match in RegExp(r"'([^'\\]*)'").allMatches(line)) {
        strings.add(match.group(1)!);
      }
    }
  }
  return strings;
}

void main() {
  test("'비디오'라고 쓰지 않는다(앱은 '영상')", () {
    // 4b1f9e71에서 앱 전체를 '영상'으로 맞췄는데 챗봇에만 남아 있었다.
    final offenders = _uiStrings().where((s) => s.contains('비디오')).toList();
    expect(offenders, isEmpty);
  });

  test("'어시스턴트' 대신 '도우미'로 부른다", () {
    final offenders =
        _uiStrings().where((s) => s.contains('어시스턴트')).toList();
    expect(offenders, isEmpty);

    final sheet = File('$_chatbotDir/presentation/widgets/chat_bot_sheet.dart')
        .readAsStringSync();
    expect(sheet, contains('음성 도우미'));
    expect(sheet, contains('만들기 도우미'));
  });
}
