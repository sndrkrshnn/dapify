import 'package:classipod/core/constants/constants.dart';
import 'package:classipod/core/extensions/build_context_extensions.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeviceScreen extends ConsumerWidget {
  final Widget child;
  final double height;

  const DeviceScreen({
    super.key,
    required this.child,
    this.height = Constants.screenHeight + 10,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTouchScreenEnabled = ref.watch(
      settingsPreferencesControllerProvider.select(
        (e) => e.isTouchScreenEnabled,
      ),
    );

    return AbsorbPointer(
      absorbing: !isTouchScreenEnabled,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double width = constraints.maxWidth;
          return Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: context.appDeviceScreenBackgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: context.appDeviceScreenBorderColor,
                width: 5,
              ),
            ),
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(size: Size(width - 10, height - 10)),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
