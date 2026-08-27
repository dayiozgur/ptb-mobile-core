import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var apnsChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // APNs push köprüsü — Firebase YOK. Dart 'ptb/apns' kanalından
    // registerForRemoteNotifications tetiklenir; token geri gönderilir.
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "ptb/apns",
                                         binaryMessenger: controller.binaryMessenger)
      apnsChannel = channel
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "register":
          self?.requestPushAuthorization { granted in
            if granted {
              DispatchQueue.main.async { application.registerForRemoteNotifications() }
            }
            result(granted)
          }
        case "setBadge":
          // App-icon rozetini güncelle (okunmamış sayısı). 0 → rozet kaybolur.
          let count = (call.arguments as? [String: Any])?["count"] as? Int ?? 0
          DispatchQueue.main.async {
            if #available(iOS 16.0, *) {
              UNUserNotificationCenter.current().setBadgeCount(count)
            } else {
              application.applicationIconBadgeNumber = count
            }
          }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    // Bildirim tap/foreground olaylarını yakalamak için delegate ol. Local
    // notifications eklentisinin de işleyebilmesi için override'larda super çağrılır.
    UNUserNotificationCenter.current().delegate = self

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func requestPushAuthorization(_ completion: @escaping (Bool) -> Void) {
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]) { granted, _ in
      completion(granted)
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    let bundleId = Bundle.main.bundleIdentifier ?? ""
    apnsChannel?.invokeMethod("onToken", arguments: ["token": token, "bundleId": bundleId])
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    apnsChannel?.invokeMethod("onError", arguments: error.localizedDescription)
  }

  // Uygulama ÖN PLANDAYKEN push gelince banner+ses göster (yoksa sessiz düşer).
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .badge, .sound])
    } else {
      completionHandler([.alert, .badge, .sound])
    }
    super.userNotificationCenter(center, willPresent: notification,
                                 withCompletionHandler: completionHandler)
  }

  // Bildirime TIKLANINCA → payload'ı (route/entityId/type) Dart'a ilet (deep-link).
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    var payload: [String: Any] = [:]
    for (key, value) in userInfo {
      if let k = key as? String { payload[k] = value }
    }
    apnsChannel?.invokeMethod("onNotificationTap", arguments: payload)
    super.userNotificationCenter(center, didReceive: response,
                                 withCompletionHandler: completionHandler)
  }
}
