import Flutter
import Foundation

final class NotificationChannelHandler {
  static let channelName = "native/notification"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)

    channel.setMethodCallHandler { call, result in
      switch call.method {

      case "requestPermission":
        NotificationService.shared.requestPermission { granted, err in
          if let err = err {
            result(FlutterError(code: "PERMISSION_ERROR", message: err.localizedDescription, details: nil))
            return
          }
          result(granted)
        }

      case "cancel":
        guard let args = call.arguments as? [String: Any],
              let ids = args["ids"] as? [String] else {
          result(FlutterError(code: "ARG_ERROR", message: "ids is required", details: nil))
          return
        }
        NotificationService.shared.cancel(ids: ids) {
          result(true)
        }

      case "scheduleExpiry":
        // args: stockId, expirationEpochSec, fireHour, fireMinute, title/body optional
        guard let args = call.arguments as? [String: Any],
              let stockId = args["stockId"] as? String,
              let expirationEpoch = args["expirationEpochSec"] as? Int else {
          result(FlutterError(code: "ARG_ERROR", message: "stockId/expirationEpochSec is required", details: nil))
          return
        }

        let fireHour = (args["fireHour"] as? Int) ?? 9
        let fireMinute = (args["fireMinute"] as? Int) ?? 0

        let expDate = Date(timeIntervalSince1970: TimeInterval(expirationEpoch))
        let cal = Calendar.current

        // exp当日/前日の指定時刻
        func makeFireDate(daysBefore: Int) -> Date? {
          guard let base = cal.date(byAdding: .day, value: -daysBefore, to: expDate) else { return nil }
          var comps = cal.dateComponents([.year,.month,.day], from: base)
          comps.hour = fireHour
          comps.minute = fireMinute
          return cal.date(from: comps)
        }

        let idD0 = "stock_\(stockId)_d0"
        let idD1 = "stock_\(stockId)_d1"

        // まず既存をキャンセルしてから再スケジュール
        NotificationService.shared.cancel(ids: [idD0, idD1])

        let title = (args["title"] as? String) ?? "とりレコ"
        let bodyD0 = (args["bodyD0"] as? String) ?? "賞味期限が今日の胸肉があります🐔"
        let bodyD1 = (args["bodyD1"] as? String) ?? "賞味期限が明日の胸肉があります🐔"

        let group = DispatchGroup()
        var anyError: Error? = nil

        if let fire0 = makeFireDate(daysBefore: 0), fire0 > Date() {
          group.enter()
          NotificationService.shared.scheduleOnce(
            id: idD0,
            title: title,
            body: bodyD0,
            fireAt: fire0,
            userInfo: ["type":"expiry","stockId":stockId,"daysBefore":0]
          ) { err in
            if anyError == nil { anyError = err }
            group.leave()
          }
        }

        if let fire1 = makeFireDate(daysBefore: 1), fire1 > Date() {
          group.enter()
          NotificationService.shared.scheduleOnce(
            id: idD1,
            title: title,
            body: bodyD1,
            fireAt: fire1,
            userInfo: ["type":"expiry","stockId":stockId,"daysBefore":1]
          ) { err in
            if anyError == nil { anyError = err }
            group.leave()
          }
        }

        group.notify(queue: .main) {
          if let err = anyError {
            result(FlutterError(code: "SCHEDULE_ERROR", message: err.localizedDescription, details: nil))
          } else {
            result(true)
          }
        }

      case "scheduleDailyProtein":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "ARG_ERROR", message: "args required", details: nil))
          return
        }
        let hour = (args["hour"] as? Int) ?? 20
        let minute = (args["minute"] as? Int) ?? 0
        let id = (args["id"] as? String) ?? "protein_daily_\(String(format:"%02d%02d", hour, minute))"
        let title = (args["title"] as? String) ?? "とりレコ"
        let body = (args["body"] as? String) ?? "今日のタンパク質、摂れてる？💪🐔"

        // 同IDで上書きしたいので先にキャンセル
        NotificationService.shared.cancel(ids: [id])

        NotificationService.shared.scheduleDaily(
          id: id,
          title: title,
          body: body,
          hour: hour,
          minute: minute
        ) { err in
          if let err = err {
            result(FlutterError(code: "SCHEDULE_ERROR", message: err.localizedDescription, details: nil))
          } else {
            result(true)
          }
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}