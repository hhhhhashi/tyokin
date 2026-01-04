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

class NativeNotification {
  static const _ch = MethodChannel('native/notification');

  static Future<void> cancelByStockId(String stockId) async {
    await _ch.invokeMethod('cancelByStockId', {'stockId': stockId});
  }

  static Future<bool> requestPermission() async {
    final r = await _ch.invokeMethod<bool>('requestPermission');
    return r ?? false;
  }

  static Future<void> cancel(List<String> ids) async {
    await _ch.invokeMethod('cancel', {'ids': ids});
  }

  /// 賞味期限通知（exp は DateTime）
  static Future<void> scheduleExpiry({
    required String stockId,
    required DateTime expirationDate,
    int fireHour = 9,
    int fireMinute = 0,
    String? title,
    String? bodyD0,
    String? bodyD1,
  }) async {
    final expEpochSec = expirationDate.millisecondsSinceEpoch ~/ 1000;
    await _ch.invokeMethod('scheduleExpiry', {
      'stockId': stockId,
      'expirationEpochSec': expEpochSec,
      'fireHour': fireHour,
      'fireMinute': fireMinute,
      if (title != null) 'title': title,
      if (bodyD0 != null) 'bodyD0': bodyD0,
      if (bodyD1 != null) 'bodyD1': bodyD1,
    });
  }

  static Future<void> scheduleDailyProtein({
    int hour = 20,
    int minute = 0,
    String? id,
    String? title,
    String? body,
  }) async {
    await _ch.invokeMethod('scheduleDailyProtein', {
      'hour': hour,
      'minute': minute,
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
    });
  }
}