// 한도 조회를 앱에 하나만 두고 받아 둔 값을 다시 쓰는지 지킨다(5차 564).
//
// CloudSentenceAssist는 FirebaseFunctions가 있어야 돌아서 통째로 부르는
// 테스트를 두기 어렵다. 깨지면 안 되는 성질만 소스에서 본다.
//
// 화면마다 제 인스턴스를 만들면, 서버가 쉬다 깨는 첫 조회(15초 넘김)를
// 화면마다 따로 맞는다. 더보기에서 받아 놓고 문장 추가를 열면 처음부터
// 다시 물었다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final assist =
      File('lib/core/content/cloud_sentence_assist.dart').readAsStringSync();
  final providers =
      File('lib/core/state/di/providers.dart').readAsStringSync();

  test('앱에 하나만 둔다', () {
    expect(providers.contains('ChangeNotifierProvider<CloudSentenceAssist>'),
        isTrue);
  });

  test('화면은 만들지 않고 받아 쓴다', () {
    const sites = [
      'lib/features/settings/more/presentation/sections/assist_usage_section.dart',
      'lib/features/home/dashboard/presentation/add_sentence_screen.dart',
      'lib/features/collection/shell/presentation/widgets/word_collection_preview.dart',
      'lib/features/collection/shell/presentation/widgets/word_edit_sheet.dart',
    ];
    for (final path in sites) {
      final source = File(path).readAsStringSync();
      expect(source.contains('context.read<CloudSentenceAssist?>()'), isTrue,
          reason: '$path가 제 인스턴스를 만든다');
    }
  });

  test('받아 둔 값이 싱싱하면 다시 묻지 않는다', () {
    expect(assist.contains('if (_usageFresh) return;'), isTrue);
  });

  // 서버는 한국 자정으로 날을 가른다. 자정을 넘겨 들고 있으면 어제 쓴 수를
  // 보여 주게 되므로, 날이 바뀌면 신선도와 무관하게 다시 묻는다.
  test('날이 바뀌면 다시 묻는다', () {
    final fresh = assist.substring(
      assist.indexOf('bool get _usageFresh'),
      assist.indexOf('Future<void> refreshUsage'),
    );
    expect(fresh.contains("_fetchedDate != _todayKst()"), isTrue);
    expect(assist.contains("add(const Duration(hours: 9))"), isTrue);
  });

  // 실패했을 때 받은 때를 적어 두면, 서버가 안 깨어난 그 순간이 '싱싱한'
  // 상태로 굳어 5분 동안 다시 묻지 못한다.
  test('실패하면 받은 때를 적지 않는다', () {
    final refresh = assist.substring(
      assist.indexOf('Future<void> refreshUsage'),
      assist.indexOf('Future<Map<String, dynamic>> _call'),
    );
    final sets = '_mark()'.allMatches(refresh).length;
    expect(sets, 1, reason: '성공 갈래 한 곳에서만 적어야 한다');
    expect(refresh.indexOf('_mark()') < refresh.indexOf('catch'), isTrue);
  });

  // 계정이 바뀌면 남의 숫자를 보여 줄 수 없다.
  test('계정이 바뀌면 다시 묻는다', () {
    final fresh = assist.substring(
      assist.indexOf('bool get _usageFresh'),
      assist.indexOf('/// 받아 둔 숫자를 버린다'),
    );
    expect(fresh.contains('_fetchedUid != _uid'), isTrue);
  });

  // 어느 부름이든 응답에 지금 숫자가 들어 있다. 한 화면에서 쓴 뒤 다른
  // 화면이 옛 숫자를 들고 있지 않게, 받을 때마다 알린다.
  test('값이 바뀌면 알린다', () {
    expect(assist.contains('extends ChangeNotifier'), isTrue);
    expect('notifyListeners()'.allMatches(assist).length, greaterThanOrEqualTo(2));
  });

  // 패롯으로 몫을 사는 것은 다른 함수라 이 객체가 알 수 없다. 더보기 화면은
  // 산 뒤에 받아 둔 값을 버리고 다시 물어야 새 몫이 보인다.
  test('몫을 산 뒤에는 버리고 다시 묻는다', () {
    expect(assist.contains('void invalidateUsage()'), isTrue);
    final section = File(
      'lib/features/settings/more/presentation/sections/'
      'assist_usage_section.dart',
    ).readAsStringSync();
    expect(section.contains('assist.invalidateUsage()'), isTrue);
  });
}
