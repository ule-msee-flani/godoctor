import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/repository_providers.dart';

/// Lets a chemist take (or choose) a photo of the pack they sell. Returns the
/// bytes + extension, or null if cancelled. Camera on phones; on desktop web
/// the browser shows a file chooser instead.
Future<({Uint8List bytes, String ext})?> pickPackPhoto(
  BuildContext context,
) async {
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
            subtitle: const Text(
              'Photograph the pack you sell, front facing, good light',
            ),
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
  if (source == null) return null;
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1200,
    maxHeight: 1200,
    imageQuality: 82,
  );
  if (file == null) return null;
  final name = file.name.toLowerCase();
  final ext = name.endsWith('.png')
      ? 'png'
      : name.endsWith('.webp')
      ? 'webp'
      : 'jpg';
  return (bytes: await file.readAsBytes(), ext: ext);
}

/// Square thumbnail of a pack photo (network path, or freshly picked bytes),
/// with an "add photo" look when there is none.
class PackPhotoThumb extends ConsumerWidget {
  const PackPhotoThumb({
    super.key,
    this.path,
    this.bytes,
    this.size = 44,
    this.onTap,
  });

  final String? path;
  final Uint8List? bytes;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(drugRepositoryProvider).inventoryPhotoUrl(path);
    Widget empty() => Container(
      color: AppColors.primarySoft,
      child: Icon(
        LucideIcons.cameraOff,
        size: size * 0.4,
        color: AppColors.primary,
      ),
    );

    final Widget child;
    if (bytes != null) {
      child = Image.memory(bytes!, fit: BoxFit.cover);
    } else if (url != null) {
      child = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => empty(),
      );
    } else {
      child = empty();
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(width: size, height: size, child: child),
      ),
    );
  }
}
