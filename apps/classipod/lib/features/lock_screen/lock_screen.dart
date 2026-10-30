import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:classipod/core/constants/assets.dart';
import 'package:classipod/core/models/music_metadata.dart';
import 'package:classipod/core/services/haptics_service.dart';
import 'package:classipod/features/lock_screen/lock_screen_controller.dart';
import 'package:classipod/features/music/album/providers/album_details_provider.dart';
import 'package:classipod/features/now_playing/provider/now_playing_details_provider.dart';
import 'package:classipod/features/settings/controller/settings_preferences_controller.dart';
import 'package:classipod/features/status_bar/widgets/battery_indicator.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// A splash-style lock panel that covers the complete player (screen and click
/// wheel) when the device wakes from sleep. It deliberately accepts only an
/// upward swipe, so pocket touches cannot change the selection or playback.
///
/// While [aodActiveProvider] is active, the same panel is rendered as an AOD:
/// a translucent black scrim dims the cover and clock, and the track metadata
/// and unlock hint are removed.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  double _dragDistance = 0;
  bool _unlocking = false;

  @override
  void initState() {
    super.initState();
    _scheduleClockTick();
  }

  void _scheduleClockTick() {
    final now = DateTime.now();
    _clockTimer = Timer(Duration(seconds: 61 - now.second), () {
      if (!mounted) {
        return;
      }
      setState(() => _now = DateTime.now());
      _scheduleClockTick();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_unlocking) {
      return;
    }
    _unlocking = true;
    if (ref.read(settingsPreferencesControllerProvider).vibrate) {
      unawaited(ref.read(hapticsServiceProvider).tap());
    }
    ref.read(lockScreenVisibleProvider.notifier).unlock();
  }

  Widget _artwork(String? path, {required BoxFit fit}) {
    final fallback = Image.asset(
      Assets.defaultAlbumCoverImage,
      fit: fit,
      gaplessPlayback: true,
    );
    if (path == null || path.isEmpty) {
      return fallback;
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return Image.file(
      File(path),
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nowPlaying = ref.watch(nowPlayingDetailsProvider);
    final metadata = nowPlaying.currentMetadata;
    final artworkPath = ref.watch(songAlbumArtworkProvider(metadata));
    final aod = ref.watch(aodActiveProvider);
    final time = DateFormat('HH:mm').format(_now);
    final date = DateFormat('EEEE d MMMM').format(_now);
    final size = MediaQuery.sizeOf(context);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final artworkSize = isLandscape
        ? (size.height - 120).clamp(160.0, 280.0)
        : (size.width - 48).clamp(200.0, 300.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => _dragDistance = 0,
      onVerticalDragUpdate: (details) {
        final next = (_dragDistance + details.delta.dy).clamp(-160.0, 40.0);
        if (next != _dragDistance) {
          setState(() => _dragDistance = next);
        }
      },
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (_dragDistance < -70 || velocity < -260) {
          unawaited(_unlock());
        } else if (_dragDistance != 0) {
          setState(() => _dragDistance = 0);
        }
      },
      child: ColoredBox(
        color: const Color(0xFF070709),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                child: _artwork(artworkPath, fit: BoxFit.cover),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xA6070709),
                      Color(0x4D070709),
                      Color(0xCC070709),
                      Color(0xFF070709),
                    ],
                    stops: [0, 0.32, 0.68, 1],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(0, _dragDistance * 0.35),
                child: SafeArea(
                  minimum: EdgeInsets.fromLTRB(
                    isLandscape ? 28 : 24,
                    isLandscape ? 20 : 24,
                    isLandscape ? 28 : 24,
                    isLandscape ? 16 : 18,
                  ),
                  child: isLandscape
                      ? _landscapeLayout(
                          time: time,
                          date: date,
                          artworkPath: artworkPath,
                          artworkSize: artworkSize,
                          metadata: metadata,
                          isPlaying: nowPlaying.isPlaying,
                          aod: aod,
                        )
                      : _portraitLayout(
                          time: time,
                          date: date,
                          artworkPath: artworkPath,
                          artworkSize: artworkSize,
                          metadata: metadata,
                          isPlaying: nowPlaying.isPlaying,
                          aod: aod,
                        ),
                ),
              ),
            ),
            if (aod)
              const Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(color: Color(0x4D000000)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _portraitLayout({
    required String time,
    required String date,
    required String? artworkPath,
    required double artworkSize,
    required MusicMetadata? metadata,
    required bool isPlaying,
    required bool aod,
  }) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _clock(time: time, date: date),
            ),
            const _BatteryPill(),
          ],
        ),
        const Spacer(flex: 3),
        _artworkPanel(artworkPath: artworkPath, size: artworkSize),
        const SizedBox(height: 26),
        if (!aod) _trackInfo(metadata: metadata, isPlaying: isPlaying),
        const Spacer(flex: 4),
        if (!aod) _unlockHint(),
      ],
    );
  }

  Widget _landscapeLayout({
    required String time,
    required String date,
    required String? artworkPath,
    required double artworkSize,
    required MusicMetadata? metadata,
    required bool isPlaying,
    required bool aod,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _clock(time: time, date: date),
                  ),
                  const _BatteryPill(),
                ],
              ),
              const Spacer(flex: 2),
              if (!aod)
                _trackInfo(
                  metadata: metadata,
                  isPlaying: isPlaying,
                  centered: false,
                ),
              const Spacer(flex: 2),
              if (!aod) _unlockHint(centered: false),
            ],
          ),
        ),
        const SizedBox(width: 28),
        Center(
          child: _artworkPanel(artworkPath: artworkPath, size: artworkSize),
        ),
      ],
    );
  }

  Widget _clock({required String time, required String date}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          time,
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 46,
            height: 0.96,
            fontWeight: FontWeight.w300,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          date.toUpperCase(),
          style: const TextStyle(
            color: Color(0xB8FFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _artworkPanel({required String? artworkPath, required double size}) {
    return SizedBox(
      width: size,
      height: size,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const RadialGradient(
          radius: 0.72,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xE6FFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: [0, 0.68, 1],
        ).createShader(bounds),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x00FFFFFF),
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: [0, 0.26, 0.74, 1],
          ).createShader(bounds),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0x00FFFFFF),
                Color(0xFFFFFFFF),
                Color(0xFFFFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: [0, 0.26, 0.74, 1],
            ).createShader(bounds),
            child: _artwork(artworkPath, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }

  Widget _trackInfo({
    required MusicMetadata? metadata,
    required bool isPlaying,
    bool centered = true,
  }) {
    final crossAxisAlignment = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final textAlign = centered ? TextAlign.center : TextAlign.left;
    final mainAxisAlignment = centered
        ? MainAxisAlignment.center
        : MainAxisAlignment.start;

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          metadata?.trackName ?? 'Nothing playing',
          textAlign: textAlign,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 20,
            height: 1.15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          metadata?.getTrackArtistNames ?? 'Your music stays ready',
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xCCFFFFFF),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        if ((metadata?.albumName ?? '').isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            metadata!.albumName!,
            textAlign: textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0x8FFFFFFF), fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: mainAxisAlignment,
          children: [
            Icon(
              isPlaying ? CupertinoIcons.play_fill : CupertinoIcons.pause_fill,
              size: 13,
              color: const Color(0xAAFFFFFF),
            ),
            const SizedBox(width: 7),
            Text(
              isPlaying ? 'Playing' : 'Paused',
              style: const TextStyle(
                color: Color(0xAAFFFFFF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _unlockHint({bool centered = true}) {
    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: const [
        Icon(CupertinoIcons.chevron_up, size: 18, color: Color(0xCCFFFFFF)),
        SizedBox(height: 6),
        Text(
          'Swipe up to unlock',
          style: TextStyle(
            color: Color(0xB3FFFFFF),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _BatteryPill extends StatelessWidget {
  const _BatteryPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x40000000),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BatteryIndicator(trackHeight: 12),
          SizedBox(width: 7),
          BatteryPercentageText(
            fontSize: 13,
            color: Color(0xFFFFFFFF),
            fontWeight: FontWeight.w700,
          ),
        ],
      ),
    );
  }
}
