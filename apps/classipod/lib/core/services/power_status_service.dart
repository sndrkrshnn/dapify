import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether external (AC/USB) power is connected. This intentionally mirrors
/// the native [BatteryManager.EXTRA_PLUGGED] value, not the battery status,
/// because the charge-bypass daemon reports the battery as discharging even
/// while the device is still powered from the wall.
final externalPowerProvider =
    NotifierProvider<ExternalPowerNotifier, bool>(
      ExternalPowerNotifier.new,
    );

class ExternalPowerNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void update(bool plugged) {
    if (state != plugged) {
      state = plugged;
    }
  }
}

/// The live battery percentage, pushed from the native
/// `ACTION_BATTERY_CHANGED` receiver. A null value means no native event has
/// arrived yet, so readers should fall back to a direct platform read.
final batteryLevelProvider =
    NotifierProvider<BatteryLevelNotifier, int?>(BatteryLevelNotifier.new);

class BatteryLevelNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void update(int? level) {
    if (level != null && state != level) {
      state = level;
    }
  }
}
