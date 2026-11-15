// 영상과 소리를 한 플레이어로 다룬다 (5차, 사용자 결정 2026-11-16).
//
// 지금까지는 화면용(video_player)과 백그라운드용(just_audio) 플레이어가 따로라,
// 앱을 내릴 때마다 파일을 다시 읽고 자리를 맞춰 트느라 0.3초쯤 끊겼다.
// 하나의 AVPlayer가 계속 돌게 하면 넘기는 과정 자체가 없어진다.
//
// 이 파일은 1단계(뼈대)다. 로컬 파일을 읽어 영상을 보이고 play/pause/seek/
// 속도까지만 한다. 백그라운드 유지와 잠금화면 조작은 2단계에서 붙인다.

import AVFoundation
import Flutter
import UIKit

/// 뷰 하나에 플레이어 하나. Flutter 쪽은 뷰 id로 채널을 찾는다.
final class NativePlayerFactory: NSObject, FlutterPlatformViewFactory {
  static let viewType = "parrokit/native_player"

  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    NativePlayerView(frame: frame, viewId: viewId, messenger: messenger)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

/// AVPlayerLayer를 sublayer로 얹고 크기만 맞춰 준다.
///
/// 뷰의 backing layer 자체를 AVPlayerLayer로 두는 방법(`layerClass`)도 있지만,
/// Flutter의 플랫폼 뷰 합성에서는 그림이 안 나왔다(까만 화면). 평범한 뷰에
/// 레이어를 얹는 쪽으로 한다.
final class PlayerSurfaceView: UIView {
  let playerLayer = AVPlayerLayer()

  override init(frame: CGRect) {
    super.init(frame: frame)
    layer.addSublayer(playerLayer)
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    layer.addSublayer(playerLayer)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    // 레이어는 오토레이아웃을 따르지 않는다. 직접 맞춘다.
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    playerLayer.frame = bounds
    CATransaction.commit()
  }
}

final class NativePlayerView: NSObject, FlutterPlatformView, FlutterStreamHandler {
  private let surface: PlayerSurfaceView
  private let player = AVPlayer()
  private let channel: FlutterMethodChannel
  private let events: FlutterEventChannel

  private var sink: FlutterEventSink?
  private var timeObserver: Any?
  private var statusObservation: NSKeyValueObservation?
  private var rateObservation: NSKeyValueObservation?
  /// 사용자가 고른 속도. 멈췄다 다시 틀어도 그대로 쓴다.
  private var speed: Float = 1.0

  init(frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger) {
    surface = PlayerSurfaceView(frame: frame)
    channel = FlutterMethodChannel(
      name: "parrokit/native_player/\(viewId)", binaryMessenger: messenger)
    events = FlutterEventChannel(
      name: "parrokit/native_player/\(viewId)/events", binaryMessenger: messenger)
    super.init()

    surface.backgroundColor = .black
    surface.playerLayer.player = player
    surface.playerLayer.videoGravity = .resizeAspect

    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    events.setStreamHandler(self)
    observePlayer()
  }

  func view() -> UIView { surface }

  // MARK: - Flutter에서 오는 말

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "load":
      guard let path = args["path"] as? String, !path.isEmpty else {
        result(FlutterError(
          code: "bad-path", message: "영상 파일 경로가 필요하다", details: nil))
        return
      }
      load(path: path, speed: (args["speed"] as? NSNumber)?.floatValue ?? 1.0)
      result(nil)
    case "play":
      player.playImmediately(atRate: speed)
      result(nil)
    case "pause":
      player.pause()
      result(nil)
    case "seek":
      let ms = (args["positionMs"] as? NSNumber)?.int64Value ?? 0
      seek(toMs: ms) { result(nil) }
    case "setSpeed":
      speed = (args["speed"] as? NSNumber)?.floatValue ?? 1.0
      if player.rate != 0 { player.rate = speed }
      result(nil)
    case "dispose":
      tearDown()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func load(path: String, speed: Float) {
    self.speed = speed
    let item = AVPlayerItem(url: URL(fileURLWithPath: path))
    statusObservation?.invalidate()
    statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
      guard let self else { return }
      if item.status == .failed {
        self.send(["event": "error",
                   "message": item.error?.localizedDescription ?? "영상을 열지 못했다"])
      } else {
        self.sendState()
      }
    }
    player.replaceCurrentItem(with: item)
    sendState()
  }

  private func seek(toMs ms: Int64, done: @escaping () -> Void) {
    let time = CMTime(value: ms, timescale: 1000)
    player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
      self?.sendState()
      done()
    }
  }

  // MARK: - 상태 알리기

  private func observePlayer() {
    // 0.2초마다 자리. 자막을 따라가기에 충분하고 너무 자주 알리지도 않는다.
    timeObserver = player.addPeriodicTimeObserver(
      forInterval: CMTime(value: 1, timescale: 5),
      queue: .main
    ) { [weak self] _ in
      self?.sendState()
    }
    rateObservation = player.observe(\.rate, options: [.new]) { [weak self] _, _ in
      self?.sendState()
    }
  }

  private func sendState() {
    let item = player.currentItem
    let durationMs: Int64
    if let seconds = item?.duration.seconds, seconds.isFinite, seconds > 0 {
      durationMs = Int64(seconds * 1000)
    } else {
      durationMs = 0
    }
    let positionSeconds = player.currentTime().seconds
    send([
      "event": "state",
      "ready": item?.status == .readyToPlay,
      "playing": player.rate != 0,
      "positionMs": positionSeconds.isFinite ? Int64(positionSeconds * 1000) : 0,
      "durationMs": durationMs,
      "speed": Double(speed),
    ])
  }

  private func send(_ payload: [String: Any]) {
    sink?(payload)
  }

  func onListen(
    withArguments arguments: Any?, eventSink: @escaping FlutterEventSink
  ) -> FlutterError? {
    sink = eventSink
    sendState()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  // MARK: - 정리

  private func tearDown() {
    if let timeObserver {
      player.removeTimeObserver(timeObserver)
      self.timeObserver = nil
    }
    statusObservation?.invalidate()
    statusObservation = nil
    rateObservation?.invalidate()
    rateObservation = nil
    player.pause()
    player.replaceCurrentItem(with: nil)
    channel.setMethodCallHandler(nil)
    events.setStreamHandler(nil)
    sink = nil
  }

  deinit {
    tearDown()
  }
}
