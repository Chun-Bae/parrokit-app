// 더보기·스튜디오·예전 보관함에 남아 있던 예전 말투(5차 376).
//
// 토스트와 창 글은 앱의 다른 곳처럼 '~어요'로 적는다. 예외로 던지는 글
// (Exception/ArgumentError)은 사용자에게 그대로 보이지 않으므로 손대지 않는다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('계정 칸 안내가 앱 말투다', () {
    final code = _read(
        'lib/features/settings/more/presentation/sections/account_section.dart');
    expect(code, contains('이메일 인증을 마쳤어요.'));
    expect(code, contains('인증 메일을 보냈어요.'));
    expect(code.contains('완료되었습니다'), isFalse);
    expect(code.contains('전송했습니다'), isFalse);
  });

  test('자동 자막 확인 창도 앱 말투다', () {
    final code = _read(
        'lib/features/content-studio/captioning/presentation/widgets/stt_confirm_dialog.dart');
    expect(code, contains('영상 소리를 듣고 자막 초안을 만들어요.'));
    expect(code.contains('자동 생성합니다'), isFalse);
  });

  test('예전 보관함 화면의 토스트도 앱 말투이고 조사가 맞다', () {
    final folder = _read(
        'lib/features/collection/library/presentation/sections/library_folder_section.dart');
    // '폴더이 존재합니다'는 조사도 틀렸다.
    expect(folder.contains('폴더이'), isFalse);
    expect(folder, contains('같은 이름의 그룹이나 폴더가 이미 있어요.'));

    final list = _read(
        'lib/features/collection/library/presentation/widgets/clip_list_view.dart');
    expect(list, contains('지웠어요.'));
    expect(list.contains('삭제되었습니다'), isFalse);

    final modal = _read(
        'lib/features/collection/library/presentation/widgets/group_collection_manager_modal.dart');
    expect(modal.contains('매핑이 저장되었습니다'), isFalse);
  });
}
