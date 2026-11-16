// 무대에서 그 언어 음성이 기기에 없을 때(5차 367).
//
// 전에는 아무 말 없이 돌아와서, 듣기를 켜도 앵무새가 소리를 내지 않는 것이
// 고장인지 기기에 음성이 없는 것인지 알 수 없었다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/shared/widgets/speak_controls.dart'
    show ttsNoVoiceHint;
import 'package:parrokit/features/home/dashboard/presentation/stage_preview_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(
        {'parrokit.speaking.auto_listen.v1.guest': false});
    MySentenceStore.cloud = null;
    await MySentenceStore.add('guest',
        language: '영어', text: 'Hello there!', translation: '안녕하세요!');
    // 이 기기에는 영어 음성이 없다고 답한다.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'),
            (call) async => call.method == 'isLanguageAvailable' ? false : 1);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Scaffold(
          body: SingleChildScrollView(
              child: StagePreviewScreen(embedded: true)),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  Future<void> turnOnListening(WidgetTester tester) async {
    await tester.ensureVisible(find.byTooltip('듣기 모드 켜기'));
    await tester.tap(find.byTooltip('듣기 모드 켜기'));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('음성이 없으면 까닭을 알린다', (tester) async {
    await open(tester);
    await turnOnListening(tester);
    expect(find.text(ttsNoVoiceHint), findsOneWidget);
  });

  testWidgets('같은 언어로 되풀이해서 알리지는 않는다', (tester) async {
    await open(tester);
    await turnOnListening(tester);
    expect(find.text(ttsNoVoiceHint), findsOneWidget);

    // 첫 안내를 치운다.
    await tester.tap(find.byTooltip('듣기 모드 끄기'));
    await tester.pump();
    scaffoldMessengerKey.currentState!.removeCurrentSnackBar();
    await tester.pump();
    expect(find.text(ttsNoVoiceHint), findsNothing);

    // 껐다 켜도(=다시 말하려 해도) 같은 말을 또 띄우지 않는다.
    await turnOnListening(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(ttsNoVoiceHint), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
