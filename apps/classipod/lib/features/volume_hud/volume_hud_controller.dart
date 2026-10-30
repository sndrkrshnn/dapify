import 'dart:async';

import 'package:classipod/core/services/audio_player_service.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:classipod/features/settings/models/volume_mode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volume_controller/volume_controller.dart';

class VolumeHudState {
  const VolumeHudState({
    this.visible = false,
    this.volume = 0,
    this.isAppVolume = true,
  });

  final bool visible;
  final double volume;
  final bool isAppVolume;

  int get percent => (volume.clamp(0.0, 1.0) * 100).round();

  VolumeHudState copyWith({bool? visible, double? volume, bool? isAppVolume}) {
    return VolumeHudState(
      visible: visible ?? this.visible,
      volume: volume ?? this.volume,
      isAppVolume: isAppVolume ?? this.isAppVolume,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is VolumeHudState &&
        other.visible == visible &&
        other.volume == volume &&
        other.isAppVolume == isAppVolume;
  }

  @override
  int get hashCode => Object.hash(visible, volume, isAppVolume);
}

final volumeHudProvider = NotifierProvider<VolumeHudNotifier, VolumeHudState>(
  VolumeHudNotifier.new,
);

/// Owns the floating volume panel and the volume stream for whichever volume
/// mode (app or system) is active. Keeping this outside Now Playing means the
/// same panel is used by the hardware keys, the click wheel and the lock screen.
class VolumeHudNotifier extends Notifier<VolumeHudState> {
  StreamSubscription<double>? _volumeSubscription;
  Timer? _hideTimer;
  VolumeMode? _subscribedMode;

  @override
  VolumeHudState build() {
    // The Android system panel is replaced by our own HUD.
    VolumeController.instance.showSystemUI = false;

    _subscribe(ref.read(settingsPreferencesControllerProvider).volumeMode);
    ref.listen(
      settingsPreferencesControllerProvider.select((value) => value.volumeMode),
      (_, next) {
        _subscribe(next);
        if (state.visible) {
          unawaited(_refresh());
        }
      },
    );

    ref.onDispose(() {
      _hideTimer?.cancel();
      unawaited(_volumeSubscription?.cancel());
    });

    return const VolumeHudState();
  }

  void _subscribe(VolumeMode mode) {
    if (_subscribedMode == mode && _volumeSubscription != null) {
      return;
    }
    _subscribedMode = mode;
    unawaited(_volumeSubscription?.cancel());
    _volumeSubscription = null;

    if (mode == VolumeMode.app) {
      _volumeSubscription = ref
          .read(audioPlayerProvider)
          .volumeStream
          .listen(_onExternalVolumeChange);
    } else {
      _volumeSubscription = VolumeController.instance.addListener(
        _onExternalVolumeChange,
      );
    }
  }

  void _onExternalVolumeChange(double volume) {
    if (!state.visible) {
      return;
    }
    state = state.copyWith(volume: volume.clamp(0.0, 1.0));
    _restartHideTimer();
  }

  Future<double> _readVolume() async {
    if (ref.read(settingsPreferencesControllerProvider).volumeMode ==
        VolumeMode.app) {
      return ref.read(audioPlayerProvider).volume;
    }
    return VolumeController.instance.getVolume();
  }

  Future<void> _refresh() async {
    final volume = await _readVolume();
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      volume: volume.clamp(0.0, 1.0),
      isAppVolume:
          ref.read(settingsPreferencesControllerProvider).volumeMode ==
          VolumeMode.app,
    );
  }

  Future<void> showCurrent() async {
    final volume = await _readVolume();
    if (!ref.mounted) {
      return;
    }
    state = VolumeHudState(
      visible: true,
      volume: volume.clamp(0.0, 1.0),
      isAppVolume:
          ref.read(settingsPreferencesControllerProvider).volumeMode ==
          VolumeMode.app,
    );
    _restartHideTimer();
  }

  Future<void> adjust({required bool increase}) async {
    final settings = ref.read(settingsPreferencesControllerProvider.notifier);
    if (increase) {
      await settings.increaseVolume();
    } else {
      await settings.decreaseVolume();
    }
    await showCurrent();
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(visible: false);
    });
  }
}
