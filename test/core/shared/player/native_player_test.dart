// 네이티브 플레이어 Flutter 쪽(5차 1단계).
//
// 네이티브는 기기에서 봐야 하지만, 텍스처를 받아 두는 것과 알림을 읽어 상태로
// 옮기는 것, 만들기 전에 부른 명령이 조용히 넘어가는지는 여기서 지킨다.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/player/native_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreamController<dynamic> events;
  late List<MethodCall> calls;
  late NativePlayerController player;
  const channel = MethodChannel('test/native_player');

  setUp(() {
    events = StreamController<dynamic>.broadcast();
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'create') return {'textureId': 7};
      return null;
    });
    player = NativePlayerController(
      channel: channel,
      eventsOf: (_) => events.stream,
    );
  });

  tearDown(() {
    player.dispose();
    events.close();
  });

  test('만들기 전에는 명령이 조용히 넘어간다', () async {
    await player.play();
    await player.load('/tmp/a.mp4');

    expect(player.isReady, isFalse);
    expect(player.textureId, isNull);
    expect(calls, isEmpty);
  });

  test('만들면 텍스처를 받아 둔다', () async {
    await player.create();

    expect(player.textureId, 7);
    expect(player.isReady, isTrue);
    expect(calls.single.method, 'create');
  });

  test('두 번 만들지 않는다', () async {
    await player.create();
    await player.create();

    expect(calls.where((c) => c.method == 'create').length, 1);
  });

  test('명령마다 어느 플레이어인지 함께 보낸다', () async {
    await player.create();
    calls.clear();

    await player.load('/tmp/a.mp4', speed: 1.5);
    await player.play();
    await player.seek(const Duration(seconds: 3));
    await player.setSpeed(2.0);
    await player.pause();

    expect(calls.map((c) => c.method).toList(),
        ['load', 'play', 'seek', 'setSpeed', 'pause']);
    expect(calls.first.arguments,
        {'textureId': 7, 'path': '/tmp/a.mp4', 'speed': 1.5});
    expect(calls[2].arguments, {'textureId': 7, 'positionMs': 3000});
    expect(calls[3].arguments, {'textureId': 7, 'speed': 2.0});
  });

  test('네이티브가 알려 준 상태를 그대로 담는다', () async {
    await player.create();
    var notified = 0;
    player.addListener(() => notified++);

    events.add({
      'event': 'state',
      'ready': true,
      'playing': true,
      'positionMs': 1500,
      'durationMs': 8000,
      'speed': 1.5,
      'width': 1080,
      'height': 1920,
    });
    await Future<void>.delayed(Duration.zero);

    expect(player.state.ready, isTrue);
    expect(player.state.playing, isTrue);
    expect(player.state.position, const Duration(milliseconds: 1500));
    expect(player.state.duration, const Duration(seconds: 8));
    expect(player.state.speed, 1.5);
    expect(player.state.aspectRatio, closeTo(1080 / 1920, 0.0001));
    expect(notified, greaterThan(0));
  });

  test('영상 크기를 모르면 16:9로 본다', () {
    expect(const NativePlayerState().aspectRatio, closeTo(16 / 9, 0.0001));
  });

  test('영상을 못 열면 그 까닭을 들고 멈춘 것으로 본다', () async {
    await player.create();
    events.add({'event': 'state', 'ready': true, 'playing': true});
    await Future<void>.delayed(Duration.zero);

    events.add({'event': 'error', 'message': '파일이 깨졌어요.'});
    await Future<void>.delayed(Duration.zero);

    expect(player.state.errorMessage, '파일이 깨졌어요.');
    expect(player.state.playing, isFalse);
  });

  test('다시 읽으면 앞선 오류를 지운다', () async {
    await player.create();
    events.add({'event': 'error', 'message': '파일이 깨졌어요.'});
    await Future<void>.delayed(Duration.zero);

    await player.load('/tmp/b.mp4');

    expect(player.state.errorMessage, isNull);
    expect(player.state.ready, isFalse);
  });

  test('알 수 없는 알림은 무시한다', () async {
    await player.create();
    events.add('그냥 글자');
    events.add({'event': '모르는 것'});
    await Future<void>.delayed(Duration.zero);

    expect(player.state.ready, isFalse);
    expect(player.state.errorMessage, isNull);
  });

  test('닫으면 네이티브에도 치우라고 알린다', () async {
    await player.create();
    calls.clear();

    player.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(calls.single.method, 'dispose');
    expect(calls.single.arguments, {'textureId': 7});
  });
}
