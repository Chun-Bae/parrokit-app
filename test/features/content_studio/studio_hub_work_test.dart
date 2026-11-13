import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/content-studio/hub/presentation/studio_hub_provider.dart';

void main() {
  test('아무 탭도 작업이 없으면 나갈 때 묻지 않는다', () {
    final hub = StudioHubProvider();
    expect(hub.hasUnsavedWork, isFalse);
    hub.setWorkCheck('caption', () => false);
    hub.setWorkCheck('tts', () => false);
    expect(hub.hasUnsavedWork, isFalse);
  });

  test('한 탭이라도 작업이 있으면 묻고, 나중에 바뀐 값을 그때 읽는다', () {
    final hub = StudioHubProvider();
    var text = '';
    hub.setWorkCheck('caption', () => false);
    hub.setWorkCheck('tts', () => text.isNotEmpty);
    expect(hub.hasUnsavedWork, isFalse);
    text = 'Could you give me a hand?';
    expect(hub.hasUnsavedWork, isTrue);
  });

  test('확인 함수가 실패하면 묻는 쪽으로 둔다', () {
    final hub = StudioHubProvider()
      ..setWorkCheck('video', () => throw StateError('x'));
    expect(hub.hasUnsavedWork, isTrue);
  });
}
