import Flutter
import UIKit

final class ShareService {

  private static let channelName = "native/share"

  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "share":
        handleShare(call: call, controller: controller, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func handleShare(
    call: FlutterMethodCall,
    controller: FlutterViewController,
    result: @escaping FlutterResult
  ) {
    guard let args = call.arguments as? [String: Any],
          let text = args["text"] as? String else {
      result(FlutterError(code: "INVALID_ARGS", message: "text is required", details: nil))
      return
    }

    let urlString = args["url"] as? String
    var items: [Any] = [text]

    if let urlString = urlString, let url = URL(string: urlString) {
      items.append(url)
    }

    let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
    controller.present(activityVC, animated: true)

    result(true)
  }
}