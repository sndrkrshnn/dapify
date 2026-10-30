import 'package:flutter_riverpod/flutter_riverpod.dart';

final lockScreenVisibleProvider =
    NotifierProvider<LockScreenVisibleNotifier, bool>(
      LockScreenVisibleNotifier.new,
    );

class LockScreenVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void show() {
    if (!state) {
      state = true;
    }
  }

  void unlock() {
    if (state) {
      state = false;
    }
  }
}

/// Whether the lock screen is currently rendered as an always-on display.
/// Only possible while the player is on external power and resumed.
final aodActiveProvider =
    NotifierProvider<AodActiveNotifier, bool>(AodActiveNotifier.new);

class AodActiveNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool active) {
    if (state != active) {
      state = active;
    }
  }
}
