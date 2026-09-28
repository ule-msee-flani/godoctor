import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/local_touch.dart';
import 'motion.dart';
import 'user_avatar.dart';

/// "Good morning, / Dr Jane (handshake)" with a line about their day, the
/// bell and their photo -- the same welcome the patient gets, for every
/// dashboard.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({
    super.key,
    required this.name,
    this.subtitle,
    this.avatarName,
    this.avatarPath,
    this.onAvatarTap,
    this.actions = const [],
  });

  final String name;
  final String? subtitle;

  /// For the initials when there's no photo (defaults to [name]).
  final String? avatarName;
  final String? avatarPath;
  final VoidCallback? onAvatarTap;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 0, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocalTouch.greeting(DateTime.now()),
                  style: theme.bodyMedium,
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const HandshakeWave(),
                  ],
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodySmall?.copyWith(
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ...actions,
          const SizedBox(width: 4),
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onAvatarTap,
            child: UserAvatar(
              name: avatarName ?? name,
              path: avatarPath,
              radius: 22,
            ),
          ),
        ],
      ),
    );
  }
}
