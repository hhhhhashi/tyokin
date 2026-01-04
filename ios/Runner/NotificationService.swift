import Foundation
import UserNotifications

final class NotificationService {
  static let shared = NotificationService()
  private init() {}

  // 権限取得（未許可ならリクエスト）
  func requestPermission(completion: @escaping (Bool, Error?) -> Void) {
    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
      switch settings.authorizationStatus {
      case .authorized, .provisional, .ephemeral:
        completion(true, nil)
      case .notDetermined:
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, err in
          completion(granted, err)
        }
      case .denied:
        completion(false, nil)
      @unknown default:
        completion(false, nil)
      }
    }
  }

  func cancel(ids: [String], completion: (() -> Void)? = nil) {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: ids)
    center.removeDeliveredNotifications(withIdentifiers: ids)
    completion?()
  }

  // 1回だけの通知（指定日時）
  func scheduleOnce(
    id: String,
    title: String,
    body: String,
    fireAt: Date,
    userInfo: [String: Any] = [:],
    completion: @escaping (Error?) -> Void
  ) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.userInfo = userInfo

    // DateComponentsトリガー（正確にその日時）
    let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: fireAt)
    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

    let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request) { err in
      completion(err)
    }
  }

  // 毎日通知（時刻だけ）
  func scheduleDaily(
    id: String,
    title: String,
    body: String,
    hour: Int,
    minute: Int,
    completion: @escaping (Error?) -> Void
  ) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    var comps = DateComponents()
    comps.hour = hour
    comps.minute = minute

    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
    let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request) { err in
      completion(err)
    }
  }
}