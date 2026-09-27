import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import 'motion.dart';

/// The video call surface. For now this is a MOCK: it looks and behaves like
/// a live call (the other person's tile, your own self-view, a running
/// timer, mute/camera/end controls) but no camera or network is used.
///
/// Deliberately kept as its own isolated widget (per spec: "keep the video
/// call area... as a distinct component/panel so a video SDK can be dropped
/// in later without restructuring the surrounding UI"). When Agora/Daily.co
/// is wired up, swap the two tiles below for the SDK's remote/local video
/// views and keep this constructor, so the call screens don't change.
class VideoCallPanel extends StatefulWidget {
  const VideoCallPanel({
    super.key,
    required this.otherPartyName,
    this.otherPartyRole,
    this.onEndCall,
    this.startedAt,
    this.height,
    this.compact = false,
    this.onMinimize,
    this.onExpand,
    this.listeners = const [],
    this.remoteCameraOff = false,
    this.startWithCameraOff = false,
  });

  final String otherPartyName;

  /// Shown under the name, e.g. "Patient" or "ENT doctor".
  final String? otherPartyRole;
  final VoidCallback? onEndCall;

  /// When the call started (for the timer); defaults to when this opened.
  final DateTime? startedAt;

  /// Fixed height; otherwise a 16:10 box.
  final double? height;

  /// Small floating tile (picture-in-picture) instead of the full panel.
  final bool compact;
  final VoidCallback? onMinimize;
  final VoidCallback? onExpand;

  /// Family members listening in (family session), shown under the name.
  final List<String> listeners;

  /// The other person keeps their camera off (e.g. the patient asked the
  /// doctor to, to save data): their tile shows their initials only.
  final bool remoteCameraOff;

  /// Start with my own camera off (data saver). Still switchable.
  final bool startWithCameraOff;

  @override
  State<VideoCallPanel> createState() => _VideoCallPanelState();
}

class _VideoCallPanelState extends State<VideoCallPanel>
    with SingleTickerProviderStateMixin {
  late final DateTime _start = widget.startedAt ?? DateTime.now();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);
  Timer? _ticker;
  bool _muted = false;
  late bool _cameraOff = widget.startWithCameraOff;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  String get _elapsed {
    final d = DateTime.now().difference(_start);
    final s = d.isNegative ? 0 : d.inSeconds;
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return s >= 3600 ? '${s ~/ 3600}:$mm:$ss' : '$mm:$ss';
  }

  String get _initials {
    final parts = widget.otherPartyName
        .replaceFirst(RegExp(r'^Dr\.?\s+', caseSensitive: false), '')
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return widget.compact ? _buildCompact() : _buildFull();
  }

  Widget _remoteTile({required double avatar}) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16254A), Color(0xFF0B1730)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) => Container(
                padding: EdgeInsets.all(4 + 6 * _pulse.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(
                    alpha: 0.05 + 0.05 * _pulse.value,
                  ),
                ),
                child: child,
              ),
              child: CircleAvatar(
                radius: avatar,
                backgroundColor: AppColors.primary,
                child: Text(
                  _initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: avatar * 0.7,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (widget.remoteCameraOff && avatar > 26) ...[
              const SizedBox(height: 6),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.videoOff, size: 12, color: Colors.white70),
                  SizedBox(width: 4),
                  Text(
                    'Camera off',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFull() {
    final body = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: LayoutBuilder(
        builder: (context, c) {
          final small = c.maxHeight < 220;
          return Stack(
            fit: StackFit.expand,
            children: [
              _remoteTile(avatar: small ? 28 : 40),
              // Top: live indicator, name, timer; mock label.
              Positioned(
                left: 12,
                top: 12,
                right: 12,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LiveChip(elapsed: _elapsed),
                          const SizedBox(height: 6),
                          Text(
                            widget.otherPartyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          if (widget.otherPartyRole != null)
                            Text(
                              widget.otherPartyRole!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          if (widget.listeners.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.headphones,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      'Listening: ${widget.listeners.join(', ')}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.onMinimize != null)
                      _RoundButton(
                        icon: LucideIcons.minimize2,
                        tooltip: 'Shrink video',
                        size: 34,
                        onTap: widget.onMinimize!,
                      ),
                  ],
                ),
              ),
              // Self view.
              Positioned(
                right: 12,
                bottom: small ? 60 : 72,
                child: _SelfView(cameraOff: _cameraOff, small: small),
              ),
              // Controls.
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoundButton(
                      icon: _muted ? LucideIcons.micOff : LucideIcons.mic,
                      tooltip: _muted ? 'Unmute' : 'Mute',
                      active: _muted,
                      onTap: () => setState(() => _muted = !_muted),
                    ),
                    const SizedBox(width: 12),
                    _RoundButton(
                      icon: _cameraOff
                          ? LucideIcons.videoOff
                          : LucideIcons.video,
                      tooltip: _cameraOff
                          ? 'Turn camera on'
                          : 'Turn camera off',
                      active: _cameraOff,
                      onTap: () => setState(() => _cameraOff = !_cameraOff),
                    ),
                    if (widget.onEndCall != null) ...[
                      const SizedBox(width: 12),
                      _RoundButton(
                        icon: LucideIcons.phoneOff,
                        tooltip: 'End call',
                        color: AppColors.danger,
                        onTap: widget.onEndCall!,
                      ),
                    ],
                  ],
                ),
              ),
              const Positioned(left: 12, bottom: 18, child: _MockLabel()),
            ],
          );
        },
      ),
    );
    if (widget.height != null) {
      return SizedBox(height: widget.height, child: body);
    }
    return AspectRatio(aspectRatio: 16 / 10, child: body);
  }

  Widget _buildCompact() {
    return Material(
      elevation: 10,
      shadowColor: Colors.black54,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 132,
        height: 176,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _remoteTile(avatar: 26),
            Positioned(
              left: 8,
              top: 8,
              right: 8,
              child: _LiveChip(elapsed: _elapsed, dense: true),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.onExpand != null)
                    _RoundButton(
                      icon: LucideIcons.maximize2,
                      tooltip: 'Enlarge video',
                      size: 34,
                      onTap: widget.onExpand!,
                    ),
                  if (widget.onEndCall != null)
                    _RoundButton(
                      icon: LucideIcons.phoneOff,
                      tooltip: 'End call',
                      size: 34,
                      color: AppColors.danger,
                      onTap: widget.onEndCall!,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip({required this.elapsed, this.dense = false});

  final String elapsed;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PulseDot(color: Color(0xFFFF4D4F), size: 7),
          const SizedBox(width: 5),
          Text(
            dense ? elapsed : 'Live · $elapsed',
            style: TextStyle(
              color: Colors.white,
              fontSize: dense ? 10.5 : 11.5,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _MockLabel extends StatelessWidget {
  const _MockLabel();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Video calling is not connected yet. This is a preview.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Demo',
          style: TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ),
    );
  }
}

class _SelfView extends StatelessWidget {
  const _SelfView({required this.cameraOff, required this.small});

  final bool cameraOff;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: small ? 58 : 76,
      height: small ? 78 : 104,
      decoration: BoxDecoration(
        color: const Color(0xFF2A3A63),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Center(
        child: Icon(
          cameraOff ? LucideIcons.videoOff : LucideIcons.userRound,
          color: Colors.white70,
          size: small ? 20 : 26,
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
    this.active = false,
    this.size = 44,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bg =
        color ?? (active ? Colors.white : Colors.white.withValues(alpha: 0.18));
    final fg = color != null
        ? Colors.white
        : (active ? AppColors.ink : Colors.white);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: fg, size: size * 0.45),
          ),
        ),
      ),
    );
  }
}
