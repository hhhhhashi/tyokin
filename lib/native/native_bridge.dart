import 'package:flutter/services.dart';

class NativeBridge {
  static const _share = MethodChannel('native/share');
  static const _notification = MethodChannel('native/notification');

  static Future<bool> share({required String text, String? url}) async {
    final ok = await _share.invokeMethod<bool>('share', {
      'text': text,
      'url': url,
    });
    return ok ?? false;
  }

  /// 0:notDetermined 1:denied 2:authorized 3:provisional 4:ephemeral
  static Future<int> getNotificationAuthorizationStatus() async {
    final code = await _notification.invokeMethod<int>('getAuthorizationStatus');
    return code ?? 0;
  }
}