import 'package:flutter/services.dart';

/// Volume buttons for the mala counter, handled in MainActivity.kt.
class VolumeKeys {
  static const _ch = MethodChannel('prayer/volume');
  static void Function(String key)? onKey;
  static bool _ready = false;

  static void _ensure() {
    if (_ready) return;
    _ready = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'key') onKey?.call(call.arguments as String);
      return null;
    });
  }

  static Future<void> setActive(bool on) async {
    _ensure();
    try {
      await _ch.invokeMethod('setActive', on);
    } catch (_) {}
  }
}
