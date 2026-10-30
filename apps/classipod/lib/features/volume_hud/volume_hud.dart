import 'package:classipod/core/theme/ipod_gradients.dart';
import 'package:classipod/features/volume_hud/volume_hud_controller.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A self-contained, iPod-style volume panel shown on top of the whole app.
/// It never takes pointer input so it cannot get in the way of the click wheel.
class VolumeHud extends ConsumerWidget {
  const VolumeHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hud = ref.watch(volumeHudProvider);
    final icon = switch (hud.percent) {
      0 => CupertinoIcons.volume_off,
      < 50 => CupertinoIcons.volume_down,
      _ => CupertinoIcons.volume_up,
    };

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: hud.visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 66),
            child: Container(
              width: 292,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: const Color(0xF218191D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x38FFFFFF)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x99000000),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 21, color: const Color(0xFFE8EAED)),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Text(
                          'VOLUME',
                          style: TextStyle(
                            color: Color(0xFFB0B6C0),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ),
                      Text(
                        '${hud.percent}%',
                        style: const TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: SizedBox(
                      height: 10,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF3A3A3E), Color(0xFF242427)],
                              ),
                            ),
                          ),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: (hud.volume / 1).clamp(0.0, 1.0),
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: IpodGradients.progress,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Text(
                        hud.isAppVolume ? 'PLAYER' : 'SYSTEM',
                        style: const TextStyle(
                          color: Color(0xFF7F8794),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
