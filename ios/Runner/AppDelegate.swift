import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {

  private let shareChannelName = "native/share"
  private let notificationChannelName = "native/notification"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    GeneratedPluginRegistrant.register(with: self)

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // ✅ ShareSheet
    let shareChannel = FlutterMethodChannel(
      name: shareChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    shareChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "share":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "BAD_ARGS", message: "arguments is null", details: nil))
          return
        }
        let text = args["text"] as? String
        let urlString = args["url"] as? String
        let items = self.buildShareItems(text: text, urlString: urlString)

        if items.isEmpty {
          result(FlutterError(code: "EMPTY", message: "share items is empty", details: nil))
          return
        }

        DispatchQueue.main.async {
          let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

          // iPad対策（iPhoneだけでも付けておくと安全）
          if let popover = activityVC.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(
              x: controller.view.bounds.midX,
              y: controller.view.bounds.midY,
              width: 0,
              height: 0
            )
            popover.permittedArrowDirections = []
          }

          controller.present(activityVC, animated: true)
          result(true)
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // ✅ 通知許可状態（取得だけ）
    let notificationChannel = FlutterMethodChannel(
      name: notificationChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    notificationChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "getAuthorizationStatus":
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          // 0: notDetermined, 1: denied, 2: authorized, 3: provisional, 4: ephemeral
          let code: Int
          switch settings.authorizationStatus {
          case .notDetermined: code = 0
          case .denied: code = 1
          case .authorized: code = 2
          case .provisional: code = 3
          case .ephemeral: code = 4
          @unknown default: code = 0
          }
          result(code)
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func buildShareItems(text: String?, urlString: String?) -> [Any] {
    var items: [Any] = []
    if let t = text, !t.isEmpty {
      items.append(t)
    }
    if let u = urlString, let url = URL(string: u) {
      items.append(url)
    }
    return items
  }
}