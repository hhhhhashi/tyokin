import Flutter
import UserNotifications

final class NotificationPermissionService {

  private static let channelName = "native/notification"

  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getStatus":
        getStatus(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func getStatus(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let status: String

      switch settings.authorizationStatus {
      case .authorized:
        status = "authorized"
      case .denied:
        status = "denied"
      case .notDetermined:
        status = "notDetermined"
      default:
        status = "unknown"
      }

      result(status)
    }
  }
}
