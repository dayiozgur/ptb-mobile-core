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
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

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
    apnsChannel?.invokeMethod("onToken", arguments: token)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    apnsChannel?.invokeMethod("onError", arguments: error.localizedDescription)
  }
}
