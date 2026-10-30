import 'package:classipod/core/services/power_status_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('externalPowerProvider', () {
    test('starts unplugged and ignores duplicate updates', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(externalPowerProvider), isFalse);
      container.read(externalPowerProvider.notifier).update(false);
      expect(container.read(externalPowerProvider), isFalse);
    });

    test('toggles when the plugged state changes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(externalPowerProvider.notifier).update(true);
      expect(container.read(externalPowerProvider), isTrue);

      container.read(externalPowerProvider.notifier).update(false);
      expect(container.read(externalPowerProvider), isFalse);
    });
  });

  group('batteryLevelProvider', () {
    test('starts unknown and accepts the first native level', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(batteryLevelProvider), isNull);
      container.read(batteryLevelProvider.notifier).update(82);
      expect(container.read(batteryLevelProvider), 82);
    });

    test('updates when the level changes and ignores nulls', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(batteryLevelProvider.notifier).update(82);
      container.read(batteryLevelProvider.notifier).update(81);
      expect(container.read(batteryLevelProvider), 81);

      container.read(batteryLevelProvider.notifier).update(null);
      expect(container.read(batteryLevelProvider), 81);
    });
  });
}
