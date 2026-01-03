import Flutter

final class ChannelRegistry {

  static func register(with controller: FlutterViewController) {
    ShareService.register(with: controller)
    NotificationPermissionService.register(with: controller)
  }
}