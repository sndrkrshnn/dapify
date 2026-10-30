import 'dart:async';

import 'package:classipod/core/services/power_status_service.dart';
import 'package:classipod/features/device/models/device_action.dart';
import 'package:classipod/features/device/services/device_buttons_service_provider.dart';
import 'package:classipod/features/lock_screen/lock_screen.dart';
import 'package:classipod/features/lock_screen/lock_screen_controller.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:classipod/features/volume_hud/volume_hud.dart';
import 'package:classipod/features/volume_hud/volume_hud_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Native bridge for the few things Flutter cannot do on its own on this
/// Android 7 device: opening the companion settings app in its own task,
/// consuming the HOME-app Back key, screen on/off events, and volume keys.
class SystemIntegration {
  const SystemIntegration._();

  static const MethodChannel _channel = MethodChannel(
    'com.sundara.classipod/system',
  );
  static const EventChannel _screenEvents = EventChannel(
    'com.sundara.classipod/screen',
  );
  static const EventChannel _powerEvents = EventChannel(
    'com.sundara.classipod/power',
  );

  static Future<void> openDapSettings() async {
    try {
      await _channel.invokeMethod<void>('openDapSettings');
    } on PlatformException {
      // Settings app unavailable; leave the player in front.
    } on MissingPluginException {
      // Desktop/test environment.
    }
  }

  /// Keeps the display awake while the AOD lock screen is shown.
  static Future<void> setKeepScreenOn(bool enabled) =>
      _invokeSystemFlag('setKeepScreenOn', enabled);

  /// Overrides the window brightness to the lowest usable level while the
  /// AOD lock screen is shown, and restores the system brightness otherwise.
  static Future<void> setScreenDim(bool enabled) =>
      _invokeSystemFlag('setScreenDim', enabled);

  static Future<void> _invokeSystemFlag(String method, bool enabled) async {
    try {
      await _channel.invokeMethod<void>(method, enabled);
    } on PlatformException {
      // The flag is best-effort; the lock screen remains visible regardless.
    } on MissingPluginException {
      // Desktop/test environment.
    }
  }
}

class SystemIntegrationHost extends ConsumerStatefulWidget {
  const SystemIntegrationHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SystemIntegrationHost> createState() =>
      _SystemIntegrationHostState();
}

class _SystemIntegrationHostState extends ConsumerState<SystemIntegrationHost>
    with WidgetsBindingObserver {
  /// How long the player may stay idle before the lock screen goes into
  /// AOD mode while external power is connected.
  static const Duration _aodIdleDelay = Duration(seconds: 30);

  StreamSubscription<dynamic>? _screenSubscription;
  StreamSubscription<dynamic>? _powerSubscription;
  Timer? _screenOnTimer;
  Timer? _aodTimer;
  bool _screenWasOff = false;
  bool _lockPending = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemIntegration._channel.setMethodCallHandler(_onMethodCall);
    _screenSubscription = SystemIntegration._screenEvents
        .receiveBroadcastStream()
        .listen(_onScreenEvent);
    _powerSubscription = SystemIntegration._powerEvents
        .receiveBroadcastStream()
        .listen(_onPowerEvent);
  }

  @override
  void dispose() {
    _screenOnTimer?.cancel();
    _aodTimer?.cancel();
    unawaited(_screenSubscription?.cancel());
    unawaited(_powerSubscription?.cancel());
    unawaited(SystemIntegration.setScreenDim(false));
    unawaited(SystemIntegration.setKeepScreenOn(false));
    SystemIntegration._channel.setMethodCallHandler(null);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      if (_lockPending) {
        _screenOnTimer?.cancel();
        _showLockWhenResumed();
      }
      _applyExternalPower();
    } else {
      _aodTimer?.cancel();
      _setAod(false);
      unawaited(SystemIntegration.setKeepScreenOn(false));
    }
  }

  void _onPowerEvent(dynamic event) {
    if (event is Map) {
      final plugged = event['plugged'];
      if (plugged is bool) {
        ref.read(externalPowerProvider.notifier).update(plugged);
      }
      final level = event['level'];
      if (level is int) {
        ref.read(batteryLevelProvider.notifier).update(level);
      }
      return;
    }
    // Older payloads carried only the plug state.
    ref.read(externalPowerProvider.notifier).update(event == 'plugged');
  }

  void _applyExternalPower() {
    if (!mounted) {
      return;
    }
    final plugged = ref.read(externalPowerProvider);
    final resumed = _lifecycleState == AppLifecycleState.resumed;
    unawaited(SystemIntegration.setKeepScreenOn(plugged && resumed));
    if (!plugged || !resumed) {
      _aodTimer?.cancel();
      _setAod(false);
      return;
    }
    if (ref.read(aodActiveProvider)) {
      return;
    }
    _restartAodTimer();
  }

  void _restartAodTimer() {
    _aodTimer?.cancel();
    if (!mounted) {
      return;
    }
    if (!ref.read(externalPowerProvider)) {
      return;
    }
    if (_lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _aodTimer = Timer(_aodIdleDelay, _enterAod);
  }

  void _enterAod() {
    if (!mounted) {
      return;
    }
    if (_lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    if (!ref.read(externalPowerProvider)) {
      return;
    }
    if (!ref.read(lockScreenVisibleProvider)) {
      ref.read(lockScreenVisibleProvider.notifier).show();
    }
    _setAod(true);
  }

  void _setAod(bool active) {
    ref.read(aodActiveProvider.notifier).set(active);
    unawaited(SystemIntegration.setScreenDim(active));
  }

  void _onInteraction() {
    if (ref.read(aodActiveProvider)) {
      _setAod(false);
    }
    if (ref.read(externalPowerProvider) &&
        _lifecycleState == AppLifecycleState.resumed) {
      _restartAodTimer();
    }
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'back':
        _handleBack();
        break;
      case 'volumeKey':
        await _handleVolumeKey(call.arguments as int? ?? 0);
        break;
    }
  }

  void _handleBack() {
    if (ref.read(lockScreenVisibleProvider)) {
      _onInteraction();
      return;
    }
    _onInteraction();
    unawaited(
      ref
          .read(deviceButtonsServiceProvider.notifier)
          .setDeviceAction(DeviceAction.menu),
    );
  }

  Future<void> _handleVolumeKey(int direction) async {
    final settings = ref.read(settingsPreferencesControllerProvider.notifier);
    if (direction > 0) {
      await settings.increaseVolume();
    } else if (direction < 0) {
      await settings.decreaseVolume();
    }
    if (mounted) {
      await ref.read(volumeHudProvider.notifier).showCurrent();
      _onInteraction();
    }
  }

  void _onScreenEvent(dynamic event) {
    if (event == 'screen_off') {
      _screenWasOff = true;
      _lockPending = false;
      _screenOnTimer?.cancel();
      _aodTimer?.cancel();
      _setAod(false);
      return;
    }
    if (event != 'screen_on') {
      return;
    }
    final bool wasOff = _screenWasOff;
    _screenWasOff = false;
    if (!wasOff) {
      return;
    }
    _lockPending = true;
    _screenOnTimer?.cancel();
    _screenOnTimer = Timer(
      const Duration(milliseconds: 350),
      _showLockWhenResumed,
    );
  }

  /// The screen can turn on before Android resumes the activity. Keep the
  /// request pending and let [didChangeAppLifecycleState] retry on resume,
  /// otherwise a fast power cycle can wake straight into the player.
  void _showLockWhenResumed() {
    if (!mounted || !_lockPending) {
      return;
    }
    if (_lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _lockPending = false;
    ref.read(lockScreenVisibleProvider.notifier).show();
    _restartAodTimer();
  }

  @override
  Widget build(BuildContext context) {
    final bool locked = ref.watch(lockScreenVisibleProvider);
    ref.listen(lockScreenVisibleProvider, (_, next) {
      if (next) {
        _aodTimer?.cancel();
        if (ref.read(externalPowerProvider) &&
            _lifecycleState == AppLifecycleState.resumed) {
          _restartAodTimer();
        }
      } else {
        _setAod(false);
        _restartAodTimer();
      }
    });
    ref.listen(externalPowerProvider, (_, _) => _applyExternalPower());
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onInteraction(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (locked) const LockScreen(),
          const VolumeHud(),
        ],
      ),
    );
  }
}
