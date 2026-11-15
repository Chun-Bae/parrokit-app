// 영상과 소리를 한 플레이어로 다룬다 (5차, 사용자 결정 2026-11-16).
//
// 지금까지는 화면용(video_player)과 백그라운드용(just_audio) 플레이어가 따로라,
// 앱을 내릴 때마다 파일을 다시 읽고 자리를 맞춰 트느라 0.3초쯤 끊겼다.
// 하나의 AVPlayer가 계속 돌게 하면 넘기는 과정 자체가 없어진다.
//
// 그림은 텍스처로 넘긴다. AVPlayerLayer를 플랫폼 뷰에 얹어 봤더니 시뮬레이터에서
// 까맣게 나왔다(반복 262). AVPlayerItemVideoOutput으로 프레임을 받아 Flutter
// 텍스처로 주면 video_player와 같은 길이라 시뮬레이터에서도 그려지고, AVPlayer는
// 그대로 우리 것이라 2단계(백그라운드에서 비디오 트랙만 끄기)도 그대로 된다.
//
// 2단계까지: 앱을 내리면 비디오 트랙만 끄고 같은 플레이어가 소리를 잇는다.
// 잠금화면·제어센터에서도 멈추고 이어 들을 수 있다.

import AVFoundation
import Flutter
import MediaPlayer
import UIKit

final class NativePlayerPlugin: NSObject, FlutterPlugin {
  static let channelName = "parrokit/native_player"

  private let registry: FlutterTextureRegistry
  private let messenger: FlutterBinaryMessenger
  private var players: [Int64: NativePlayer] = [:]

  init(registry: FlutterTextureRegistry, messenger: FlutterBinaryMessenger) {
    self.registry = registry
    self.messenger = messenger
    super.init()
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = NativePlayerPlugin(
      registry: registrar.textures(), messenger: registrar.messenger())
    let channel = FlutterMethodChannel(
      name: channelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(plugin, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]

    if call.method == "create" {
      let player = NativePlayer(registry: registry, messenger: messenger)
      players[player.textureId] = player
      result(["textureId": player.textureId])
      return
    }

    guard let id = (args["textureId"] as? NSNumber)?.int64Value,
          let player = players[id] else {
      result(FlutterError(
        code: "no-player", message: "플레이어를 찾지 못했다", details: nil))
      return
    }

    switch call.method {
    case "load":
      guard let path = args["path"] as? String, !path.isEmpty else {
        result(FlutterError(
          code: "bad-path", message: "영상 파일 경로가 필요하다", details: nil))
        return
      }
      player.load(
        path: path,
        speed: (args["speed"] as? NSNumber)?.floatValue ?? 1.0,
        title: args["title"] as? String ?? "")
      result(nil)
    case "play":
      player.play()
      result(nil)
    case "pause":
      player.pause()
      result(nil)
    case "seek":
      player.seek(toMs: (args["positionMs"] as? NSNumber)?.int64Value ?? 0) {
        result(nil)
      }
    case "setSpeed":
      player.setSpeed((args["speed"] as? NSNumber)?.floatValue ?? 1.0)
      result(nil)
    case "dispose":
      player.tearDown()
      players[id] = nil
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

/// 플레이어 하나 = 텍스처 하나.
final class NativePlayer: NSObject, FlutterTexture, FlutterStreamHandler {
  private let registry: FlutterTextureRegistry
  private let player = AVPlayer()
  private let output: AVPlayerItemVideoOutput
  private var events: FlutterEventChannel?
  private var sink: FlutterEventSink?

  /// 보이지 않는 AVPlayerLayer(크기 0). 눈에는 안 보인다.
  ///
  /// video_player도 같은 것을 둔다. 보호된 영상에서 그림이 빈 화면으로
  /// 나오는 것과, 어떤 영상의 가로세로가 뒤바뀌는 것을 막으려는 것이다
  /// ("An invisible AVPlayerLayer is used to overwrite the protection of
  /// pixel buffers"). 우리 시험 영상에서는 이게 없어도 그려졌지만, 겪지
  /// 못한 영상을 위해 같이 둔다.
  private let playerLayer: AVPlayerLayer
  private var displayLink: CADisplayLink?
  /// 진단용: 받은 프레임 수와 Flutter가 가져간 횟수.
  private var frames = 0
  private var pulls = 0
  private var timeObserver: Any?
  private var statusObservation: NSKeyValueObservation?
  private var rateObservation: NSKeyValueObservation?

  /// 사용자가 고른 속도. 멈췄다 다시 틀어도 그대로 쓴다.
  private var speed: Float = 1.0

  /// 잠금화면에 보일 이름.
  private var title: String = ""

  /// 앱을 내릴 때 틀고 있었는지.
  private var wasPlayingOnBackground = false
  private var appObservers: [NSObjectProtocol] = []

  private(set) var textureId: Int64 = 0

  init(registry: FlutterTextureRegistry, messenger: FlutterBinaryMessenger) {
    self.registry = registry
    output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
      kCVPixelBufferPixelFormatTypeKey as String:
        Int(kCVPixelFormatType_32BGRA),
      // Flutter 텍스처는 IOSurface로 받쳐진 버퍼만 그린다. 이게 없으면
      // 프레임이 와도 화면은 까맣다(video_player도 같은 설정을 쓴다).
      kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
    ])
    playerLayer = AVPlayerLayer()
    super.init()

    playerLayer.player = player
    NativePlayer.hostLayer()?.addSublayer(playerLayer)

    textureId = registry.register(self)
    events = FlutterEventChannel(
      name: "\(NativePlayerPlugin.channelName)/\(textureId)/events",
      binaryMessenger: messenger)
    events?.setStreamHandler(self)

    configureAudioSession()
    observePlayer()
    observeAppState()
    observeRemoteCommands()
    startDisplayLink()
  }

  /// Flutter 화면의 레이어. 여기에 몰래 붙인다.
  private static func hostLayer() -> CALayer? {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
    let window = windows.first { $0.isKeyWindow } ?? windows.first
    return window?.rootViewController?.view.layer
  }

  // MARK: - 명령

  func load(path: String, speed: Float, title: String) {
    self.speed = speed
    self.title = title
    let item = AVPlayerItem(url: URL(fileURLWithPath: path))
    item.add(output)

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

  func play() {
    player.playImmediately(atRate: speed)
  }

  func pause() {
    player.pause()
  }

  func seek(toMs ms: Int64, done: @escaping () -> Void) {
    player.seek(
      to: CMTime(value: ms, timescale: 1000),
      toleranceBefore: .zero,
      toleranceAfter: .zero
    ) { [weak self] _ in
      self?.sendState()
      done()
    }
  }

  func setSpeed(_ value: Float) {
    speed = value
    if player.rate != 0 { player.rate = value }
    sendState()
  }

  // MARK: - 백그라운드에서도 소리 잇기

  /// 앱을 내려도 소리가 나려면 오디오 세션이 playback이어야 한다.
  private func configureAudioSession() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .moviePlayback)
    try? session.setActive(true)

    // iOS 17부터는 이것까지 켜야 앱을 내렸을 때 영상 플레이어가 안 멈춘다.
    // 기본값(.automatic)은 '영상이니까 멈춘다'이다.
    if #available(iOS 17.0, *) {
      player.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
    }
  }

  private func observeAppState() {
    let center = NotificationCenter.default
    appObservers.append(center.addObserver(
      forName: UIApplication.didEnterBackgroundNotification,
      object: nil, queue: .main
    ) { [weak self] _ in self?.enterBackground() })
    appObservers.append(center.addObserver(
      forName: UIApplication.willEnterForegroundNotification,
      object: nil, queue: .main
    ) { [weak self] _ in self?.enterForeground() })
  }

  /// 앱을 내릴 때. 그림만 끄고 소리는 그대로 둔다.
  ///
  /// iOS는 화면에 붙은 영상이 있으면 앱을 내릴 때 플레이어를 멈춘다. 비디오
  /// 트랙을 꺼 두면 소리만 계속 난다. 넘기는 과정이 없으니 끊기지 않는다.
  private func enterBackground() {
    wasPlayingOnBackground = player.rate != 0
    playerLayer.player = nil
    let videoTracks = setVideoTracks(enabled: false)
    displayLink?.isPaused = true
    NSLog("[NativePlayer] 내림: 틀고 있었나=%@ 비디오 트랙=%d",
          wasPlayingOnBackground ? "예" : "아니오", videoTracks)
    if wasPlayingOnBackground {
      player.playImmediately(atRate: speed)
      // iOS가 내리는 순간 한 번 더 멈추는 일이 있어, 조금 뒤에 다시 본다.
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
        guard let self, self.wasPlayingOnBackground, self.player.rate == 0 else {
          return
        }
        NSLog("[NativePlayer] 내린 뒤 멈춰 있어 다시 튼다")
        self.player.playImmediately(atRate: self.speed)
      }
    }
  }

  /// 돌아올 때. 그림을 다시 켠다.
  private func enterForeground() {
    setVideoTracks(enabled: true)
    playerLayer.player = player
    displayLink?.isPaused = false
    if wasPlayingOnBackground, player.rate == 0 {
      player.playImmediately(atRate: speed)
    }
    sendState()
  }

  /// 끈(또는 켠) 비디오 트랙 수를 돌려준다.
  @discardableResult
  private func setVideoTracks(enabled: Bool) -> Int {
    guard let item = player.currentItem else { return 0 }
    var count = 0
    for track in item.tracks where track.assetTrack?.mediaType == .video {
      track.isEnabled = enabled
      count += 1
    }
    return count
  }

  // MARK: - 잠금화면·제어센터

  private func observeRemoteCommands() {
    let center = MPRemoteCommandCenter.shared()
    center.playCommand.addTarget { [weak self] _ in
      self?.play()
      return .success
    }
    center.pauseCommand.addTarget { [weak self] _ in
      self?.pause()
      return .success
    }
    center.togglePlayPauseCommand.addTarget { [weak self] _ in
      guard let self else { return .commandFailed }
      if self.player.rate == 0 { self.play() } else { self.pause() }
      return .success
    }
    center.changePlaybackPositionCommand.addTarget { [weak self] event in
      guard let self,
            let event = event as? MPChangePlaybackPositionCommandEvent else {
        return .commandFailed
      }
      self.seek(toMs: Int64(event.positionTime * 1000)) {}
      return .success
    }
  }

  private func updateNowPlaying() {
    var info: [String: Any] = [:]
    info[MPMediaItemPropertyTitle] = title.isEmpty ? "클립" : title
    if let seconds = player.currentItem?.duration.seconds,
       seconds.isFinite, seconds > 0 {
      info[MPMediaItemPropertyPlaybackDuration] = seconds
    }
    let position = player.currentTime().seconds
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] =
      position.isFinite ? position : 0
    info[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
  }


  // MARK: - 그림

  private func startDisplayLink() {
    let link = CADisplayLink(target: self, selector: #selector(onFrame))
    link.add(to: .main, forMode: .common)
    displayLink = link
  }

  @objc private func onFrame() {
    // 새 그림이 있다는 것만 알린다. 실제 복사는 Flutter가 가져갈 때 한다
    // (video_player와 같은 차례. 미리 받아 두면 까맣게 나왔다).
    let time = output.itemTime(forHostTime: CACurrentMediaTime())
    guard output.hasNewPixelBuffer(forItemTime: time) else { return }
    frames += 1
    registry.textureFrameAvailable(textureId)
  }

  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    pulls += 1
    let time = output.itemTime(forHostTime: CACurrentMediaTime())
    guard output.hasNewPixelBuffer(forItemTime: time),
          let buffer = output.copyPixelBuffer(
            forItemTime: time, itemTimeForDisplay: nil) else {
      // 새 그림이 없으면 nil. Flutter가 앞 그림을 그대로 쓴다.
      return nil
    }
    return Unmanaged.passRetained(buffer)
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
    var durationMs: Int64 = 0
    if let seconds = item?.duration.seconds, seconds.isFinite, seconds > 0 {
      durationMs = Int64(seconds * 1000)
    }
    var width = 0
    var height = 0
    if let size = item?.presentationSize, size.width > 0, size.height > 0 {
      width = Int(size.width)
      height = Int(size.height)
    }
    let positionSeconds = player.currentTime().seconds
    send([
      "event": "state",
      "ready": item?.status == .readyToPlay,
      "playing": player.rate != 0,
      "positionMs": positionSeconds.isFinite ? Int64(positionSeconds * 1000) : 0,
      "durationMs": durationMs,
      "speed": Double(speed),
      "width": width,
      "height": height,
      "frames": frames,
      "pulls": pulls,
    ])
    updateNowPlaying()
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

  func tearDown() {
    for observer in appObservers {
      NotificationCenter.default.removeObserver(observer)
    }
    appObservers = []
    let commands = MPRemoteCommandCenter.shared()
    commands.playCommand.removeTarget(self)
    commands.pauseCommand.removeTarget(self)
    commands.togglePlayPauseCommand.removeTarget(self)
    commands.changePlaybackPositionCommand.removeTarget(self)
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    displayLink?.invalidate()
    displayLink = nil
    if let timeObserver {
      player.removeTimeObserver(timeObserver)
      self.timeObserver = nil
    }
    statusObservation?.invalidate()
    statusObservation = nil
    rateObservation?.invalidate()
    rateObservation = nil
    player.pause()
    playerLayer.player = nil
    playerLayer.removeFromSuperlayer()
    player.currentItem?.remove(output)
    player.replaceCurrentItem(with: nil)
    events?.setStreamHandler(nil)
    events = nil
    sink = nil
    registry.unregisterTexture(textureId)
  }

  deinit {
    tearDown()
  }
}
