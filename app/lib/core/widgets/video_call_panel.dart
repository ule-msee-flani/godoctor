import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';

/// Placeholder for the video call surface.
///
/// Deliberately kept as its own isolated widget (per spec: "keep the video
/// call area... as a distinct component/panel so a video SDK can be dropped
/// in later without restructuring the surrounding UI"). When Agora/Daily.co
/// is wired up, only this file's `build()` should need to change -- swap the
/// placeholder body for the SDK's video view widget, keep the same
/// constructor signature so callers (in-call screens) don't change.
class VideoCallPanel extends StatelessWidget {
  const VideoCallPanel({
    super.key,
    required this.otherPartyName,
    this.onEndCall,
  });

  final String otherPartyName;
  final VoidCallback? onEndCall;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.heroGradient),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -30,
                child: _softCircle(140),
              ),
              Positioned(
                left: -40,
                bottom: -40,
                child: _softCircle(160),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.videoOff,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Video call with $otherPartyName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Video will appear here once connected',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (onEndCall != null)
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        minimumSize: const Size(140, 48),
                      ),
                      onPressed: onEndCall,
                      icon: const Icon(LucideIcons.phoneOff),
                      label: const Text('End call'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _softCircle(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: 0.08),
    ),
  );
}
