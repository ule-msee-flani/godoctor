import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/video_call_panel.dart';
import '../../data/models/enums.dart';
import '../../data/providers/appointment_providers.dart';
import '../patient/screens/patient_call_screen.dart' show showVisitEnded;
import 'active_call.dart';

/// The call carrying on over the rest of the app: a floating window that can
/// be dragged anywhere (it settles against the nearest side), tapped to go
/// back to the call, or tucked away into a small tab at the edge of the
/// screen when it's in the way.
class CallOverlay extends ConsumerStatefulWidget {
  const CallOverlay({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends ConsumerState<CallOverlay> {
  static const _w = 116.0;
  static const _h = 164.0;

  /// Which side it rests on, and how far down.
  bool _onLeft = false;
  double? _top;

  /// Where it is while being dragged.
  Offset? _dragging;

  void _expand(ActiveCall call) {
    HapticFeedback.selectionClick();
    ref.read(activeCallProvider.notifier).expand();
    widget.router.push(call.route);
  }

  /// The call ended while it was out of sight: tidy up, and for the patient
  /// go Home and ask how it went.
  void _ended(ActiveCall call, ConsultationStatus status) {
    ref.read(activeCallProvider.notifier).end(call.consultationId);
    if (!call.isDoctor && status == ConsultationStatus.completed) {
      showVisitEnded(
        widget.router,
        consultationId: call.consultationId,
        doctorName: call.otherName,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final call = ref.watch(activeCallProvider);
    if (call != null) {
      ref.listen(appointmentProvider(call.consultationId), (prev, next) {
        final c = next.valueOrNull;
        final now = ref.read(activeCallProvider);
        if (c == null || now == null || now.view == CallView.full) return;
        final over = switch (c.status) {
          ConsultationStatus.inProgress ||
          ConsultationStatus.matched ||
          ConsultationStatus.scheduled => false,
          _ => true,
        };
        if (over) {
          _ended(now, c.status);
        } else if (!now.joined && c.doctorJoinedAt != null) {
          // The doctor opened the call while the patient was elsewhere.
          HapticFeedback.heavyImpact();
          ref.read(activeCallProvider.notifier).markJoined();
        }
      });
    }
    final show = call != null && call.view != CallView.full;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (show)
          LayoutBuilder(
            builder: (context, c) => Stack(
              fit: StackFit.expand,
              children: [_placed(call, c.biggest)],
            ),
          ),
      ],
    );
  }

  Widget _placed(ActiveCall call, Size screen) {
    final pad = MediaQuery.paddingOf(context);
    final minTop = pad.top + 8;
    // Clear of the floating tab bar.
    final maxTop = (screen.height - pad.bottom - _h - 100).clamp(
      minTop,
      double.infinity,
    );
    final top = (_top ?? screen.height * 0.18).clamp(minTop, maxTop);

    if (call.view == CallView.tucked) {
      return AnimatedPositioned(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        left: _onLeft ? 0 : null,
        right: _onLeft ? null : 0,
        top: top + (_h - 88) / 2,
        child: _TuckedTab(
          onLeft: _onLeft,
          joined: call.joined,
          onTap: () {
            HapticFeedback.selectionClick();
            ref.read(activeCallProvider.notifier).minimize();
          },
          onDrag: (dy) => setState(
            () => _top = (top + dy).clamp(minTop, maxTop).toDouble(),
          ),
        ),
      );
    }

    final rest = Offset(_onLeft ? 12 : screen.width - _w - 12, top);
    final at = _dragging ?? rest;
    return AnimatedPositioned(
      duration: _dragging == null
          ? const Duration(milliseconds: 280)
          : Duration.zero,
      curve: Curves.easeOutCubic,
      left: at.dx,
      top: at.dy,
      width: _w,
      height: _h,
      child: GestureDetector(
        onTap: () => _expand(call),
        onPanStart: (_) => setState(() => _dragging = rest),
        onPanUpdate: (d) =>
            setState(() => _dragging = (_dragging ?? rest) + d.delta),
        onPanEnd: (d) {
          final pos = _dragging ?? rest;
          final vx = d.velocity.pixelsPerSecond.dx;
          final centre = pos.dx + _w / 2;
          // Flung at an edge, or pushed half past it: tuck it away.
          final pastLeft =
              pos.dx < -_w * 0.35 ||
              (vx < -1400 && centre < screen.width * 0.35);
          final pastRight =
              pos.dx > screen.width - _w * 0.65 ||
              (vx > 1400 && centre > screen.width * 0.65);
          setState(() {
            _dragging = null;
            _top = pos.dy.clamp(minTop, maxTop).toDouble();
            _onLeft = pastLeft || (!pastRight && centre < screen.width / 2);
          });
          if (pastLeft || pastRight) {
            HapticFeedback.lightImpact();
            ref.read(activeCallProvider.notifier).tuck();
          }
        },
        child: _FloatingWindow(
          call: call,
          onLeft: _onLeft,
          onTuck: () {
            HapticFeedback.lightImpact();
            ref.read(activeCallProvider.notifier).tuck();
          },
          onMute: () => ref.read(activeCallProvider.notifier).toggleMute(),
        ),
      ),
    );
  }
}

class _FloatingWindow extends StatelessWidget {
  const _FloatingWindow({
    required this.call,
    required this.onLeft,
    required this.onTuck,
    required this.onMute,
  });

  final ActiveCall call;
  final bool onLeft;
  final VoidCallback onTuck;
  final VoidCallback onMute;

  @override
  Widget build(BuildContext context) {
    final waiting = !call.joined;
    return Semantics(
      container: true,
      button: true,
      label: waiting
          ? 'Waiting room for ${call.otherName}. Tap to go back.'
          : 'Your call with ${call.otherName}. Tap to go back to it.',
      child: Material(
        elevation: 14,
        shadowColor: Colors.black54,
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: waiting ? 0.55 : 1,
              child: CallRemoteTile(
                name: call.otherName,
                photoUrl: call.otherPhotoUrl,
                cameraOff: call.remoteCameraOff,
                avatar: 24,
              ),
            ),
            // Top: timer (or "Waiting") and the tuck-away arrow.
            Positioned(
              left: 8,
              right: 6,
              top: 8,
              child: Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PulseDot(
                            color: waiting
                                ? AppColors.warning
                                : const Color(0xFFFF4D4F),
                            size: 6,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: waiting
                                ? const Text(
                                    'Waiting',
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : CallTimer(
                                    startedAt: call.startedAt,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  _MiniButton(
                    icon: onLeft
                        ? LucideIcons.chevronLeft
                        : LucideIcons.chevronRight,
                    label: 'Tuck the call away',
                    onTap: onTuck,
                  ),
                ],
              ),
            ),
            // Bottom: who, and the mic.
            Positioned(
              left: 8,
              right: 6,
              bottom: 8,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      waiting ? 'Tap to wait here' : call.otherName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        shadows: [
                          Shadow(color: Color(0x99000000), blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                  if (!waiting)
                    _MiniButton(
                      icon: call.muted ? LucideIcons.micOff : LucideIcons.mic,
                      label: call.muted ? 'Unmute' : 'Mute',
                      active: call.muted,
                      onTap: onMute,
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

class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: active ? Colors.white : Colors.black.withValues(alpha: 0.4),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(
              icon,
              size: 15,
              color: active ? AppColors.ink : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// The call tucked into the edge of the screen: tap to bring it back.
class _TuckedTab extends StatelessWidget {
  const _TuckedTab({
    required this.onLeft,
    required this.joined,
    required this.onTap,
    required this.onDrag,
  });

  final bool onLeft;
  final bool joined;
  final VoidCallback onTap;
  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    const round = Radius.circular(18);
    return Semantics(
      container: true,
      button: true,
      label: 'Show your call',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        onVerticalDragUpdate: (d) => onDrag(d.delta.dy),
        onHorizontalDragEnd: (d) {
          final v = d.velocity.pixelsPerSecond.dx;
          // Pulled out from the edge.
          if ((onLeft && v > 200) || (!onLeft && v < -200)) onTap();
        },
        child: Material(
          elevation: 10,
          shadowColor: Colors.black54,
          color: AppColors.ink,
          borderRadius: onLeft
              ? const BorderRadius.only(topRight: round, bottomRight: round)
              : const BorderRadius.only(topLeft: round, bottomLeft: round),
          child: SizedBox(
            width: 32,
            height: 88,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PulseDot(
                  color: joined ? AppColors.success : AppColors.warning,
                  size: 8,
                ),
                const SizedBox(height: 8),
                Icon(
                  joined ? LucideIcons.video : LucideIcons.hourglass,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(height: 6),
                Icon(
                  onLeft ? LucideIcons.chevronRight : LucideIcons.chevronLeft,
                  size: 14,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
