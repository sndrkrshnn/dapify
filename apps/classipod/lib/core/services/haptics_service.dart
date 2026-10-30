import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final hapticsServiceProvider = Provider<HapticsService>((ref) {
  return HapticsService();
});

/// Plays the two haptic voices used by the player through the native
/// [MethodChannel]. Keeping this out of `HapticFeedback` lets the Android
/// side use a single, short, low-amplitude pulse instead of the platform's
/// multi-pulse "light impact" pattern.
class HapticsService {
  static const MethodChannel _channel = MethodChannel(
    'com.sundara.classipod/haptics',
  );

  // Minimum gap between detents. The 14 ms pulse needs ~35 ms for the ERM
  // coil to wind down before the next pulse reads as a distinct "thud".
  // 35 ms is also fast enough that even a quick flick doesn't drop a tick.
  static const Duration _minimumDetentInterval = Duration(milliseconds: 35);

  final Stopwatch _detentClock = Stopwatch()..start();
  Duration _lastDetent = Duration.zero;
  bool _available = true;

  Future<void> tap() => _play('tap');

  Future<void> detent() {
    final Duration now = _detentClock.elapsed;
    if (now - _lastDetent < _minimumDetentInterval) {
      return Future.value();
    }
    _lastDetent = now;
    return _play('detent');
  }

  Future<void> _play(String kind) async {
    if (!_available ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(kind);
    } on PlatformException catch (error) {
      _available = false;
      debugPrint('Haptics unavailable: $error');
    } on MissingPluginException {
      _available = false;
    }
  }
}
