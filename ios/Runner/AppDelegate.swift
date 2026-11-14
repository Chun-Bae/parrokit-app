import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// 플러그인들(FCM·flutter_local_notifications)이 잡아 둔 알림 델리게이트.
  /// 우리가 가로챈 뒤에도 하던 일을 그대로 하도록 넘겨준다.
  private weak var pluginNotificationDelegate: UNUserNotificationCenterDelegate?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // 앱을 보고 있는 동안에도 연습 알림이 배너로 뜨게 한다.
    // iOS는 앱이 앞에 있으면 알림을 앱에 넘기고 띄울지 말지를 앱이 정하는데,
    // 플러그인이 잡은 델리게이트가 아무것도 띄우지 않아 알림이 조용히
    // 지나갔다(5차, 사용자 확인).
    let center = UNUserNotificationCenter.current()
    pluginNotificationDelegate = center.delegate
    center.delegate = self

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// 연습 알림이 쓰는 id 범위(LocalNotificationService.practiceIdBase와 같다).
  private func isPracticeReminder(_ notification: UNNotification) -> Bool {
    guard let id = Int(notification.request.identifier) else { return false }
    return id >= 9100 && id < 9160
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler:
      @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if isPracticeReminder(notification) {
      if #available(iOS 14.0, *) {
        completionHandler([.banner, .list, .sound])
      } else {
        completionHandler([.alert, .sound])
      }
      return
    }
    // 나머지(커뮤니티 푸시 등)는 하던 대로.
    if let delegate = pluginNotificationDelegate,
       delegate.responds(
         to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:))) {
      delegate.userNotificationCenter?(
        center, willPresent: notification, withCompletionHandler: completionHandler)
      return
    }
    super.userNotificationCenter(
      center, willPresent: notification, withCompletionHandler: completionHandler)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    // 알림을 눌렀을 때의 처리는 플러그인이 그대로 받아야 한다.
    if let delegate = pluginNotificationDelegate,
       delegate.responds(
         to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:))) {
      delegate.userNotificationCenter?(
        center, didReceive: response, withCompletionHandler: completionHandler)
      return
    }
    super.userNotificationCenter(
      center, didReceive: response, withCompletionHandler: completionHandler)
  }
}
