import 'dart:math' as math;

import 'package:classipod/core/constants/assets.dart';
import 'package:classipod/core/constants/keys.dart';
import 'package:classipod/core/services/system_integration.dart';
import 'package:classipod/features/device/widgets/device_controls.dart';
import 'package:classipod/features/device/widgets/device_screen.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:classipod/features/settings/models/device_color.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeviceFrame extends ConsumerWidget {
  final Widget child;

  const DeviceFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.sizeOf(context);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final DeviceColor deviceColor = ref.watch(
      settingsPreferencesControllerProvider.select((e) => e.deviceColor),
    );
    final deviceColorStyle = deviceColor.style;
    final solidFrameColor = deviceColorStyle.solidFrameColor;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: solidFrameColor,
        image: solidFrameColor == null
            ? DecorationImage(
                image: const AssetImage(Assets.noiseImage),
                fit: BoxFit.cover,
                opacity: deviceColorStyle.noiseOpacity,
              )
            : null,
        gradient: solidFrameColor == null
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: deviceColorStyle.frameGradientColors,
              )
            : null,
      ),
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            child: SizedBox(
              height: 20,
              width: size.width,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [BoxShadow(blurRadius: 100, spreadRadius: 1)],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            child: SizedBox(
              height: 20,
              width: size.width,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [BoxShadow(blurRadius: 100, spreadRadius: 1)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            child: SizedBox(
              height: size.height,
              width: 20,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [BoxShadow(blurRadius: 100, spreadRadius: 1)],
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            child: SizedBox(
              height: size.height,
              width: 20,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [BoxShadow(blurRadius: 100, spreadRadius: 1)],
                ),
              ),
            ),
          ),
          SafeArea(
            minimum: isLandscape
                ? const EdgeInsets.fromLTRB(20, 20, 20, 16)
                : const EdgeInsets.fromLTRB(20, 30, 20, 20),
            child: isLandscape
                ? _landscapeLayout(deviceColorStyle: deviceColorStyle)
                : _portraitLayout(),
          ),
          if (!isLandscape)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 2),
                child: Center(
                  child: _DapSettingsKey(
                    color: deviceColorStyle.buttonIconColor,
                    isDark: deviceColorStyle.isDark,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _portraitLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 960, maxWidth: 450),
        child: Column(
          children: [
            DeviceScreen(key: deviceScreenGlobalKey, child: child),
            const Spacer(flex: 2),
            DeviceControls(key: deviceControlsGlobalKey),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _landscapeLayout({required DeviceColorStyle deviceColorStyle}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 960, maxWidth: 960),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const double gap = 18;
            final double wheelDiameter = math
                .min(
                  math.min(224.0, constraints.maxHeight - 44),
                  constraints.maxWidth * 0.42,
                )
                .clamp(120.0, 224.0);
            final double screenWidth =
                constraints.maxWidth - wheelDiameter - gap;

            return Row(
              children: [
                SizedBox(
                  width: screenWidth,
                  child: DeviceScreen(
                    key: deviceScreenGlobalKey,
                    height: constraints.maxHeight,
                    child: child,
                  ),
                ),
                const SizedBox(width: gap),
                SizedBox(
                  width: wheelDiameter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DeviceControls(
                        key: deviceControlsGlobalKey,
                        diameter: wheelDiameter,
                      ),
                      const SizedBox(height: 2),
                      _DapSettingsKey(
                        color: deviceColorStyle.buttonIconColor,
                        isDark: deviceColorStyle.isDark,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A tiny silk-screened key on the lower bezel rather than a floating
/// Android-style button. It reads as part of the device, but still gives the
/// settings page a fast touch target.
class _DapSettingsKey extends StatefulWidget {
  const _DapSettingsKey({required this.color, required this.isDark});

  final Color color;
  final bool isDark;

  @override
  State<_DapSettingsKey> createState() => _DapSettingsKeyState();
}

class _DapSettingsKeyState extends State<_DapSettingsKey> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final double opacity = _pressed
        ? 0.95
        : widget.isDark
        ? 0.44
        : 0.68;
    final color = widget.color.withValues(alpha: opacity);

    return Semantics(
      button: true,
      label: 'DAP Settings',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: SystemIntegration.openDapSettings,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: SizedBox(
          width: 156,
          height: 34,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.gear, size: 12, color: color),
                const SizedBox(width: 7),
                Text(
                  'SETTINGS',
                  style: TextStyle(
                    fontFamily: Assets.uiFont,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.1,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
