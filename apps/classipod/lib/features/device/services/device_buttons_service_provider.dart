import 'dart:async';

import 'package:classipod/core/services/audio_player_service.dart';
import 'package:classipod/core/services/click_sound_service.dart';
import 'package:classipod/core/services/haptics_service.dart';
import 'package:classipod/features/device/models/device_action.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final clickWheelGestureProvider =
    NotifierProvider<ClickWheelGestureNotifier, bool>(
      ClickWheelGestureNotifier.new,
    );

class ClickWheelGestureNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  set active(bool value) => state = value;
}

final deviceButtonsServiceProvider =
    NotifierProvider<DeviceButtonsServiceNotifier, DeviceAction?>(
      DeviceButtonsServiceNotifier.new,
    );

class DeviceButtonsServiceNotifier extends Notifier<DeviceAction?> {
  @override
  DeviceAction? build() {
    return null;
  }

  Future<void> buttonPressVibrate() async {
    if (ref.read(settingsPreferencesControllerProvider).vibrate) {
      await ref.read(hapticsServiceProvider).tap();
    }
  }

  Future<void> clickWheelSound() async {
    if (ref.read(settingsPreferencesControllerProvider).clickWheelSound) {
      ref.read(clickSoundServiceProvider).click();
    }
  }

  void _emit(DeviceAction action) {
    // Reset first so repeating the same action (for example clicking Select
    // twice) always notifies the listeners.
    state = null;
    state = action;
  }

  Future<void> setDeviceAction(DeviceAction action) async {
    final isWheelRotation =
        action == DeviceAction.rotateForward ||
        action == DeviceAction.rotateBackward;

    // Haptics and the click sound must never delay the action itself.
    // Wheel detents fire in the same call as the rotation tick so the
    // haptic and sound are perfectly synchronised — one pulse per tick.
    if (isWheelRotation) {
      unawaited(wheelDetent());
    } else {
      unawaited(buttonPressVibrate());
    }
    unawaited(clickWheelSound());
    _emit(action);
  }

  /// Wheel detent: fires at the exact same moment as the rotation tick,
  /// keeping haptic and audio in sync.
  Future<void> wheelDetent() async {
    if (ref.read(settingsPreferencesControllerProvider).vibrate) {
      await ref.read(hapticsServiceProvider).detent();
    }
  }

  Future<void> playPauseButtonClick() async {
    unawaited(buttonPressVibrate());
    unawaited(clickWheelSound());
    _emit(DeviceAction.playPause);
    unawaited(ref.read(audioPlayerServiceProvider.notifier).togglePlayback());
  }

  void resetDeviceAction() {
    state = null;
  }
}
