import 'package:classipod/features/lock_screen/lock_screen_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lockScreenVisibleProvider', () {
    test('show and unlock toggle the lock screen', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(lockScreenVisibleProvider), isFalse);
      container.read(lockScreenVisibleProvider.notifier).show();
      expect(container.read(lockScreenVisibleProvider), isTrue);

      container.read(lockScreenVisibleProvider.notifier).unlock();
      expect(container.read(lockScreenVisibleProvider), isFalse);
    });

    test('showing or unlocking twice is idempotent', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(lockScreenVisibleProvider.notifier).show();
      container.read(lockScreenVisibleProvider.notifier).show();
      expect(container.read(lockScreenVisibleProvider), isTrue);

      container.read(lockScreenVisibleProvider.notifier).unlock();
      container.read(lockScreenVisibleProvider.notifier).unlock();
      expect(container.read(lockScreenVisibleProvider), isFalse);
    });
  });

  group('aodActiveProvider', () {
    test('starts inactive and tracks explicit state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(aodActiveProvider), isFalse);
      container.read(aodActiveProvider.notifier).set(true);
      expect(container.read(aodActiveProvider), isTrue);

      container.read(aodActiveProvider.notifier).set(false);
      expect(container.read(aodActiveProvider), isFalse);
    });

    test('duplicate updates do not change the state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(aodActiveProvider.notifier).set(true);
      container.read(aodActiveProvider.notifier).set(true);
      expect(container.read(aodActiveProvider), isTrue);

      container.read(aodActiveProvider.notifier).set(false);
      container.read(aodActiveProvider.notifier).set(false);
      expect(container.read(aodActiveProvider), isFalse);
    });
  });
}
