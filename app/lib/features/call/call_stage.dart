import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';

/// Builds the video for [CallStage]: [panelOpen] and [togglePanel] drive the
/// "details / full screen" button; [topInset] keeps the name clear of the
/// status bar.
typedef CallVideoBuilder =
    Widget Function(
      BuildContext context, {
      required bool panelOpen,
      required VoidCallback togglePanel,
      required double topInset,
    });

/// A call laid out like a video app: the video full screen, and under it a
/// panel (prescription, notes...) that is dragged up from the bottom. As it
/// comes up the video eases up to half the screen; drag it back down (or tap
/// full screen) for the video alone.
class CallStage extends StatefulWidget {
  const CallStage({
    super.key,
    required this.video,
    required this.panelTitle,
    required this.panel,
    this.panelIcon = LucideIcons.clipboardList,
    this.panelBadge,
    this.initiallyOpen = false,
    this.onOpenChanged,
  });

  final CallVideoBuilder video;
  final String panelTitle;
  final IconData panelIcon;

  /// A small count or word next to the title ("1 new").
  final String? panelBadge;
  final Widget panel;
  final bool initiallyOpen;

  /// The panel came up (true) or went back down (false).
  final ValueChanged<bool>? onOpenChanged;

  @override
  State<CallStage> createState() => CallStageState();
}

class CallStageState extends State<CallStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    value: widget.initiallyOpen ? 1 : 0,
  )..addListener(_watchOpen);
  late bool _wasOpen = widget.initiallyOpen;

  void _watchOpen() {
    if (isOpen != _wasOpen) {
      _wasOpen = isOpen;
      widget.onOpenChanged?.call(_wasOpen);
    }
  }

  /// Height of the handle strip that shows while the video is full screen.
  static const peek = 64.0;

  double _travel = 1;

  bool get isOpen => _t.value > 0.5;

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    HapticFeedback.selectionClick();
    _t.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void open() => _animateTo(1);
  void close() => _animateTo(0);
  void toggle() => isOpen ? close() : open();

  void _drag(DragUpdateDetails d) {
    _t.value = (_t.value - d.primaryDelta! / _travel).clamp(0.0, 1.0);
  }

  void _release(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dy;
    if (v < -300) {
      open();
    } else if (v > 300) {
      close();
    } else {
      _animateTo(_t.value >= 0.5 ? 1 : 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        final closedVideo = h - peek - pad.bottom;
        final openVideo = h > 620 ? h * 0.46 : h * 0.4;
        _travel = (closedVideo - openVideo).clamp(1.0, double.infinity);
        final panelHeight = h - openVideo;

        return AnimatedBuilder(
          animation: _t,
          builder: (context, _) {
            final t = _t.value;
            final videoH = lerpDouble(closedVideo, openVideo, t)!;
            final radius = 26 * t;
            return Stack(
              children: [
                // The panel sits under the video; only its handle shows
                // until it's pulled up.
                Positioned(
                  left: 0,
                  right: 0,
                  top: videoH,
                  height: panelHeight,
                  child: _Sheet(
                    title: widget.panelTitle,
                    icon: widget.panelIcon,
                    badge: widget.panelBadge,
                    open: t > 0.5,
                    contentOpacity: Curves.easeIn.transform(t),
                    bottomInset: pad.bottom,
                    onTap: toggle,
                    onDrag: _drag,
                    onRelease: _release,
                    child: widget.panel,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: videoH,
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(radius),
                    ),
                    child: widget.video(
                      context,
                      panelOpen: t > 0.5,
                      togglePanel: toggle,
                      topInset: pad.top,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.title,
    required this.icon,
    required this.badge,
    required this.open,
    required this.contentOpacity,
    required this.bottomInset,
    required this.onTap,
    required this.onDrag,
    required this.onRelease,
    required this.child,
  });

  final String title;
  final IconData icon;
  final String? badge;
  final bool open;
  final double contentOpacity;
  final double bottomInset;
  final VoidCallback onTap;
  final GestureDragUpdateCallback onDrag;
  final GestureDragEndCallback onRelease;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The handle: drag it, or tap it.
          Semantics(
            container: true,
            button: true,
            label: open ? 'Close $title' : 'Open $title',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              onVerticalDragUpdate: onDrag,
              onVerticalDragEnd: onRelease,
              child: SizedBox(
                height: CallStageState.peek,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.borderStrong,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          Icon(icon, size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleSmall,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.successSoft,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                badge!,
                                style: text.labelSmall?.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          AnimatedRotation(
                            turns: open ? 0.5 : 0,
                            duration: const Duration(milliseconds: 250),
                            child: const Icon(
                              LucideIcons.chevronUp,
                              size: 20,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: IgnorePointer(
              ignoring: contentOpacity < 0.2,
              child: Opacity(
                opacity: contentOpacity,
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
