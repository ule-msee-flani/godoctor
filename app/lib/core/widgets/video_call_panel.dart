import 'package:flutter/material.dart';

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
        child: Container(
          color: const Color(0xFF1B1F23),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.videocam_off_outlined,
                      color: Colors.white54,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Video call with $otherPartyName',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Video SDK not yet integrated (see PROJECT_SPEC.md)',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
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
                        backgroundColor: Colors.red,
                      ),
                      onPressed: onEndCall,
                      icon: const Icon(Icons.call_end),
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
}
