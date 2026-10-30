import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final batteryLevelServiceProvider = Provider<BatteryLevelService>(
  (ref) => const BatteryLevelService(),
);

/// Reads the battery percentage from the native sticky
/// `ACTION_BATTERY_CHANGED` broadcast.
///
/// This is deliberately separate from `battery_plus`: on this Android 7 build
/// `BatteryManager.BATTERY_PROPERTY_CAPACITY` returns a frozen value, while
/// the sticky broadcast follows `/sys/class/power_supply` and matches
/// `dumpsys battery`.
class BatteryLevelService {
  static const MethodChannel _channel = MethodChannel(
    'com.sundara.classipod/system',
  );

  const BatteryLevelService();

  /// Returns `null` when the native side is unavailable so callers can fall
  /// back to `battery_plus`.
  Future<int?> read() async {
    try {
      return await _channel.invokeMethod<int>('batteryLevel');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
