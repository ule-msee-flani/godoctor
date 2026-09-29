import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'motion.dart';

/// One tab of a [FloatingNavBar].
class FloatingNavItem {
  const FloatingNavItem(this.icon, this.label, {this.badge = 0});

  final IconData icon;
  final String label;

  /// Count on the icon (0 hides it).
  final int badge;
}

/// The bottom bar as a rounded pill floating above the page: the chosen
/// tab grows into a coloured capsule with its name, the others are icons.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<FloatingNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: Container(
        height: 64,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A0B1730),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final n = items.length;
            // The chosen tab takes a bigger share for its label.
            final selectedWidth = (c.maxWidth * (n <= 4 ? 0.4 : 0.34)).clamp(
              96.0,
              170.0,
            );
            final otherWidth = (c.maxWidth - selectedWidth) / (n - 1);
            return Row(
              children: [
                for (var i = 0; i < n; i++)
                  _Tab(
                    item: items[i],
                    selected: i == currentIndex,
                    width: i == currentIndex ? selectedWidth : otherWidth,
                    onTap: () => onTap(i),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.item,
    required this.selected,
    required this.width,
    required this.onTap,
  });

  final FloatingNavItem item;
  final bool selected;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = PopBadge(
      count: item.badge,
      child: Icon(
        item.icon,
        size: 22,
        color: selected ? Colors.white : AppColors.inkSoft,
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        width: width,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: onTap,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  selected
                      ? TabPop(child: icon)
                      : Bobbing(active: item.badge > 0, child: icon),
                  if (selected) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
