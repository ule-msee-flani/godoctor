import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import 'motion.dart';

/// The video call surface. For now this is a MOCK: it looks and behaves like
/// a live call (the other person full screen, your own self-view, a running
/// timer, the call buttons) but no camera or network is used.
///
/// Deliberately kept as its own isolated widget (per spec: "keep the video
/// call area... as a distinct component/panel so a video SDK can be dropped
/// in later without restructuring the surrounding UI"). When Agora/Daily.co
/// is wired up, swap [CallRemoteTile] and the self-view for the SDK's
/// remote/local video views and keep this constructor.
class VideoCallPanel extends StatefulWidget {
  const VideoCallPanel({
    super.key,
    required this.otherPartyName,
    this.otherPartyRole,
    this.onEndCall,
    this.startedAt,
    this.height,
    this.listeners = const [],
    this.remoteCameraOff = false,
    this.startWithCameraOff = false,
    this.otherPhotoUrl,
    this.selfPhotoUrl,
    this.onBack,
    this.topInset = 0,
    this.bottomInset = 0,
    this.radius = 26,
    this.muted,
    this.onToggleMute,
    this.cameraOff,
    this.onCameraChanged,
    this.speakerOn,
    this.onToggleSpeaker,
    this.onPanel,
    this.panelOpen = false,
    this.panelBadge = false,
    this.notice,
  });

  final String otherPartyName;

  /// Shown under the name, e.g. "Patient" or "Cardiologist".
  final String? otherPartyRole;
  final VoidCallback? onEndCall;

  /// When the call started (for the timer); defaults to when this opened.
  final DateTime? startedAt;

  /// Fixed height; otherwise it fills its box (or 16:10 when unbounded).
  final double? height;

  /// Family members listening in (family session), shown under the name.
  final List<String> listeners;

  /// The other person keeps their camera off (e.g. the patient asked the
  /// doctor to, to save data): their tile shows their initials only.
  final bool remoteCameraOff;

  /// Start with my own camera off (data saver). Still switchable.
  final bool startWithCameraOff;

  /// The other person's photo: fills their tile until real video is wired
  /// in (then the SDK's view replaces it).
  final String? otherPhotoUrl;

  /// My photo for the self-view.
  final String? selfPhotoUrl;

  /// The "<" at the top left: leave the screen, keep the call going.
  final VoidCallback? onBack;

  /// Room for the status bar and the phone's own buttons when the video is
  /// full screen.
  final double topInset;
  final double bottomInset;

  /// Corner rounding (0 when full screen).
  final double radius;

  /// The buttons' state, when kept outside (so it survives leaving the
  /// screen). Null: this panel keeps it.
  final bool? muted;
  final VoidCallback? onToggleMute;
  final bool? cameraOff;
  final ValueChanged<bool>? onCameraChanged;
  final bool? speakerOn;
  final VoidCallback? onToggleSpeaker;

  /// The prescription & details panel under the video: open it, or (when
  /// [panelOpen]) go back to full-screen video.
  final VoidCallback? onPanel;
  final bool panelOpen;

  /// Something new in the panel (a prescription arrived).
  final bool panelBadge;

  /// A short message over the video, above the timer.
  final Widget? notice;

  @override
  State<VideoCallPanel> createState() => _VideoCallPanelState();
}

class _VideoCallPanelState extends State<VideoCallPanel> {
  bool _muted = false;
  late bool _cameraOff = widget.startWithCameraOff;
  bool _speaker = true;

  bool get muted => widget.muted ?? _muted;
  bool get cameraOff => widget.cameraOff ?? _cameraOff;
  bool get speakerOn => widget.speakerOn ?? _speaker;

  @override
  Widget build(BuildContext context) {
    final body = ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: LayoutBuilder(
        builder: (context, c) {
          final small = c.maxHeight < 420;
          final button = small ? 44.0 : 54.0;
          return Stack(
            fit: StackFit.expand,
            children: [
              CallRemoteTile(
                name: widget.otherPartyName,
                photoUrl: widget.otherPhotoUrl,
                cameraOff: widget.remoteCameraOff,
                avatar: small ? 30 : 44,
              ),
              // Top: back, who you're talking to.
              Positioned(
                left: 12,
                right: 12,
                top: widget.topInset + 10,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.onBack != null)
                      _GlassButton(
                        icon: LucideIcons.chevronLeft,
                        tooltip: 'Minimize',
                        onTap: widget.onBack!,
                        size: small ? 38 : 42,
                      )
                    else
                      const SizedBox(width: 42),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            widget.otherPartyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: small ? 15 : 17,
                              shadows: const [
                                Shadow(color: Color(0x66000000), blurRadius: 8),
                              ],
                            ),
                          ),
                          if (widget.otherPartyRole != null)
                            Text(
                              widget.otherPartyRole!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                                shadows: [
                                  Shadow(
                                    color: Color(0x66000000),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          if (widget.listeners.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _ListenersChip(names: widget.listeners),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 42),
                  ],
                ),
              ),
              // Self view, top right, under the name.
              Positioned(
                right: 14,
                top: widget.topInset + (small ? 56 : 64),
                child: _SelfView(
                  cameraOff: cameraOff,
                  small: small,
                  photoUrl: widget.selfPhotoUrl,
                ),
              ),
              // Bottom: a notice, the timer, the buttons.
              Positioned(
                left: 12,
                right: 12,
                bottom: widget.bottomInset + (small ? 12 : 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.notice != null) ...[
                      widget.notice!,
                      const SizedBox(height: 10),
                    ],
                    _TimerPill(startedAt: widget.startedAt),
                    SizedBox(height: small ? 10 : 16),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _CallButton(
                            icon: speakerOn
                                ? LucideIcons.volume2
                                : LucideIcons.volumeOff,
                            tooltip: speakerOn ? 'Speaker off' : 'Speaker on',
                            active: !speakerOn,
                            size: button,
                            onTap: () {
                              if (widget.onToggleSpeaker != null) {
                                widget.onToggleSpeaker!();
                              } else {
                                setState(() => _speaker = !_speaker);
                              }
                            },
                          ),
                          _CallButton(
                            icon: cameraOff
                                ? LucideIcons.videoOff
                                : LucideIcons.video,
                            tooltip: cameraOff
                                ? 'Turn camera on'
                                : 'Turn camera off',
                            active: cameraOff,
                            size: button,
                            onTap: () {
                              final next = !cameraOff;
                              if (widget.onCameraChanged != null) {
                                widget.onCameraChanged!(next);
                              } else {
                                setState(() => _cameraOff = next);
                              }
                            },
                          ),
                          _CallButton(
                            icon: muted ? LucideIcons.micOff : LucideIcons.mic,
                            tooltip: muted ? 'Unmute' : 'Mute',
                            active: muted,
                            size: button,
                            onTap: () {
                              if (widget.onToggleMute != null) {
                                widget.onToggleMute!();
                              } else {
                                setState(() => _muted = !_muted);
                              }
                            },
                          ),
                          if (widget.onPanel != null)
                            _CallButton(
                              icon: widget.panelOpen
                                  ? LucideIcons.maximize2
                                  : LucideIcons.clipboardList,
                              tooltip: widget.panelOpen
                                  ? 'Full screen'
                                  : 'Prescription & details',
                              badge: widget.panelBadge && !widget.panelOpen,
                              size: button,
                              onTap: widget.onPanel!,
                            ),
                          if (widget.onEndCall != null)
                            _CallButton(
                              icon: LucideIcons.phoneOff,
                              tooltip: 'End call',
                              color: AppColors.danger,
                              size: button,
                              onTap: widget.onEndCall!,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    if (widget.height != null) {
      return SizedBox(height: widget.height, child: body);
    }
    return LayoutBuilder(
      builder: (context, c) => c.hasBoundedHeight
          ? body
          : AspectRatio(aspectRatio: 10 / 13, child: body),
    );
  }
}

/// The other person: their video (for now their photo) filling the tile,
/// or their initials breathing gently when there's no picture.
class CallRemoteTile extends StatefulWidget {
  const CallRemoteTile({
    super.key,
    required this.name,
    this.photoUrl,
    this.cameraOff = false,
    this.avatar = 40,
  });

  final String name;
  final String? photoUrl;
  final bool cameraOff;
  final double avatar;

  @override
  State<CallRemoteTile> createState() => _CallRemoteTileState();
}

class _CallRemoteTileState extends State<CallRemoteTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String get _initials => callInitials(widget.name);

  @override
  Widget build(BuildContext context) {
    final photo = widget.photoUrl;
    if (photo != null && !widget.cameraOff) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            photo,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.35),
            errorBuilder: (_, _, _) => _initialsTile(),
          ),
          // Darker at the top and bottom so the name and buttons read.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x73000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xA6000000),
                ],
                stops: [0, 0.22, 0.58, 1],
              ),
            ),
          ),
        ],
      );
    }
    return _initialsTile();
  }

  Widget _initialsTile() {
    final avatar = widget.avatar;
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
            if (widget.cameraOff && avatar > 26) ...[
              const SizedBox(height: 8),
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
}

/// "Dr. Jane Wanjiru" -> "JW".
String callInitials(String name) {
  final parts = name
      .replaceFirst(RegExp(r'^Dr\.?\s+', caseSensitive: false), '')
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}

/// "12:32" since the call started, ticking every second.
class CallTimer extends StatefulWidget {
  const CallTimer({super.key, this.startedAt, this.style});

  final DateTime? startedAt;
  final TextStyle? style;

  @override
  State<CallTimer> createState() => _CallTimerState();
}

class _CallTimerState extends State<CallTimer> {
  late final DateTime _opened = DateTime.now();
  Timer? _ticker;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = DateTime.now().difference(widget.startedAt ?? _opened);
    final s = d.isNegative ? 0 : d.inSeconds;
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return Text(
      s >= 3600 ? '${s ~/ 3600}:$mm:$ss' : '$mm:$ss',
      style: (widget.style ?? const TextStyle()).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _TimerPill extends StatelessWidget {
  const _TimerPill({this.startedAt});

  final DateTime? startedAt;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Colors.black.withValues(alpha: 0.32),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PulseDot(color: Color(0xFFFF4D4F), size: 7),
              const SizedBox(width: 6),
              CallTimer(
                startedAt: startedAt,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              const _MockLabel(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListenersChip extends StatelessWidget {
  const _ListenersChip({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.headphones, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              'Listening: ${names.join(', ')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 11),
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
    return const Tooltip(
      message: 'Video calling is not connected yet. This is a preview.',
      child: Text(
        'Demo',
        style: TextStyle(color: Colors.white60, fontSize: 10.5),
      ),
    );
  }
}

class _SelfView extends StatelessWidget {
  const _SelfView({
    required this.cameraOff,
    required this.small,
    this.photoUrl,
  });

  final bool cameraOff;
  final bool small;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final icon = Center(
      child: Icon(
        cameraOff ? LucideIcons.videoOff : LucideIcons.userRound,
        color: Colors.white70,
        size: small ? 20 : 26,
      ),
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: small ? 68 : 96,
      height: small ? 90 : 128,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF2A3A63),
        borderRadius: BorderRadius.circular(small ? 14 : 18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 1.5,
        ),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 12)],
      ),
      child: cameraOff || photoUrl == null
          ? icon
          : Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => icon,
            ),
    );
  }
}

/// A frosted round button at the top of the call ("<").
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 42,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.white.withValues(alpha: 0.22),
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(icon, color: Colors.white, size: size * 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the round call buttons along the bottom.
class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.size,
    this.color,
    this.active = false,
    this.badge = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;
  final Color? color;

  /// On (muted, camera off...): white with a dark icon.
  final bool active;

  /// A dot: something new behind this button.
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final bg =
        color ?? (active ? Colors.white : Colors.black.withValues(alpha: 0.38));
    final fg = color != null
        ? Colors.white
        : (active ? AppColors.ink : Colors.white);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: size * 0.12),
      child: Tooltip(
        message: tooltip,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Material(
                  color: bg,
                  child: InkWell(
                    onTap: onTap,
                    child: SizedBox(
                      width: size,
                      height: size,
                      child: Icon(icon, color: fg, size: size * 0.42),
                    ),
                  ),
                ),
              ),
            ),
            if (badge)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
