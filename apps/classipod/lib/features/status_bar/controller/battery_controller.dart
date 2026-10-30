import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:classipod/core/services/battery_level_service.dart';
import 'package:classipod/core/services/power_status_service.dart';
import 'package:classipod/features/status_bar/model/battery_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BatteryDetailsControllerNotifier extends AsyncNotifier<BatteryModel> {
  final Battery _battery = Battery();
  BatteryModel? _lastKnown;

  @override
  Future<BatteryModel> build() async {
    // The native ACTION_BATTERY_CHANGED receiver pushes every percentage
    // change, so the level stays live without polling. battery_plus only
    // streams charging-state changes, which is why the level used to freeze
    // at whatever it was when the app started.
    ref.listen(batteryLevelProvider, (_, next) {
      final level = next;
      if (level != null) {
        unawaited(_applyLevel(level));
      }
    });
    ref.listen(onBatteryStateChangeProvider, (_, _) => unawaited(_refresh()));

    final model = await _read();
    _lastKnown = model;
    return model;
  }

  Future<BatteryModel> _read() async {
    final nativeLevel = await ref.read(batteryLevelServiceProvider).read();
    return BatteryModel(
      // Fall back to the plugin when the native channel is unavailable.
      level: nativeLevel ?? await _battery.batteryLevel,
      batteryState: await _battery.batteryState,
    );
  }

  Future<void> _applyLevel(int level) async {
    if (!ref.mounted || _lastKnown?.level == level) {
      return;
    }
    final BatteryModel next;
    try {
      next = BatteryModel(
        level: level,
        batteryState: await _battery.batteryState,
      );
    } catch (_) {
      return;
    }
    if (!ref.mounted || next == _lastKnown) {
      return;
    }
    _lastKnown = next;
    state = AsyncData(next);
  }

  Future<void> _refresh() async {
    if (!ref.mounted) {
      return;
    }
    final BatteryModel next;
    try {
      next = await _read();
    } catch (_) {
      return;
    }
    if (!ref.mounted || next == _lastKnown) {
      return;
    }
    _lastKnown = next;
    state = AsyncData(next);
  }
}

final onBatteryStateChangeProvider = StreamProvider<BatteryState>((ref) {
  return Battery().onBatteryStateChanged;
});

final batteryDetailsControllerProvider =
    AsyncNotifierProvider<BatteryDetailsControllerNotifier, BatteryModel>(() {
      return BatteryDetailsControllerNotifier();
    });
