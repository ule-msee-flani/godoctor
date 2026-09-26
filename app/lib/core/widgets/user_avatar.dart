import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/providers/auth_providers.dart';
import '../../data/providers/repository_providers.dart';
import '../../data/repositories/repository_errors.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';

/// A person's profile photo, or their initials when they have none.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.path,
    this.radius = 22,
    this.online = false,
  });

  final String name;

  /// Path in the `avatars` bucket.
  final String? path;
  final double radius;

  /// Draws a green "online" dot.
  final bool online;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(profileRepositoryProvider).avatarUrl(path);
    Widget initials() => Center(
      child: Text(
        initialsOf(name),
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.7,
        ),
      ),
    );

    final circle = ClipOval(
      child: Container(
        width: radius * 2,
        height: radius * 2,
        color: AppColors.primarySoft,
        child: url == null
            ? initials()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => initials(),
              ),
      ),
    );
    if (!online) return circle;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        circle,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: radius * 0.5,
            height: radius * 0.5,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// The signed-in user's own photo with a camera button to change it. Works
/// for patients, doctors and chemists; the photo is saved to Supabase.
class EditableAvatar extends ConsumerStatefulWidget {
  const EditableAvatar({super.key, required this.name, this.radius = 40});

  final String name;
  final double radius;

  @override
  ConsumerState<EditableAvatar> createState() => _EditableAvatarState();
}

class _EditableAvatarState extends ConsumerState<EditableAvatar> {
  bool _uploading = false;

  Future<void> _change() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );
    final userId = ref.read(currentUserIdProvider);
    if (file == null || userId == null) return;

    setState(() => _uploading = true);
    try {
      final name = file.name.toLowerCase();
      await ref
          .read(profileRepositoryProvider)
          .changeAvatar(
            userId: userId,
            bytes: await file.readAsBytes(),
            fileExt: name.endsWith('.png')
                ? 'png'
                : name.endsWith('.webp')
                ? 'webp'
                : 'jpeg',
          );
      ref.invalidate(currentAppUserProvider);
      ref.invalidate(currentDoctorProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not upload photo: ${friendlyError(e)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = ref.watch(currentAppUserProvider).valueOrNull?.avatarUrl;
    return Semantics(
      button: true,
      label: 'Change profile photo',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _uploading ? null : _change,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            UserAvatar(name: widget.name, path: path, radius: widget.radius),
            if (_uploading)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  LucideIcons.camera,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
