import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../utils/app_assets.dart';

/// Colour shown before the first video frame. Make it match the video's first
/// frame, and keep it in sync with android/.../values/splash_colors.xml and
/// web/index.html so there is no flash of another colour at launch.
const kSplashBackground = Color(0xFF0B1730);

/// Where the video goes: `assets/video/splash.mp4` (or .webm / .mov).
const _splashVideoBase = 'assets/video/splash';

/// Plays the launch video full screen the first time the app opens, over the
/// app itself (which keeps starting up underneath), then fades away.
///
/// If no video has been supplied, or it can't be played, this does nothing and
/// the app simply appears.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  /// True after the splash has been started once in this process, so it never
  /// replays on hot restart-free rebuilds or route changes.
  static bool _startedThisLaunch = false;

  VideoPlayerController? _controller;
  bool _visible = false;
  bool _fading = false;

  @override
  void initState() {
    super.initState();
    final asset = AppAssets.findVideo(_splashVideoBase);
    if (!_startedThisLaunch && asset != null) {
      _startedThisLaunch = true;
      _visible = true;
      _start(asset);
    }
  }

  Future<void> _start(String asset) async {
    if (!kIsWeb) {
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
    }
    try {
      final controller = VideoPlayerController.asset(
        asset,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = controller;
      await controller.initialize().timeout(const Duration(seconds: 8));
      if (!mounted) return;
      await controller.setLooping(false);
      // Browsers block autoplay with sound, so the web splash is silent.
      await controller.setVolume(kIsWeb ? 0 : 1);
      controller.addListener(_onVideoTick);
      setState(() {});
      await controller.play();
    } catch (_) {
      _finish();
    }
  }

  void _onVideoTick() {
    final value = _controller?.value;
    if (value == null) return;
    if (value.hasError) {
      _finish();
    } else if (value.isInitialized &&
        value.duration > Duration.zero &&
        value.position >= value.duration - const Duration(milliseconds: 80)) {
      _finish();
    }
  }

  void _finish() {
    if (_fading || !mounted) return;
    if (!kIsWeb) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    setState(() => _fading = true);
  }

  void _onFadeEnd() {
    if (!_fading || !mounted) return;
    _controller?.removeListener(_onVideoTick);
    _controller?.dispose();
    _controller = null;
    setState(() => _visible = false);
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        if (_visible)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: _fading,
              child: AnimatedOpacity(
                opacity: _fading ? 0 : 1,
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOut,
                onEnd: _onFadeEnd,
                child: ColoredBox(
                  color: kSplashBackground,
                  child: ready
                      ? SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            clipBehavior: Clip.hardEdge,
                            child: SizedBox(
                              width: controller.value.size.width,
                              height: controller.value.size.height,
                              child: VideoPlayer(controller),
                            ),
                          ),
                        )
                      : const SizedBox.expand(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
