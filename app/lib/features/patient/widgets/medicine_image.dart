import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_assets.dart';
import '../../../data/models/drug.dart';
import '../../../data/models/medicine_category.dart';
import '../../../data/providers/repository_providers.dart';

/// Tint used for a category's shelf, thumbnails and placeholder art.
extension MedicineCategoryStyle on MedicineCategory {
  Color get soft => switch (this) {
    MedicineCategory.tablets => AppColors.primarySoft,
    MedicineCategory.capsules => AppColors.accentTealSoft,
    MedicineCategory.syrups => AppColors.warningSoft,
    MedicineCategory.creams => AppColors.successSoft,
    MedicineCategory.drops => AppColors.primarySoft,
    MedicineCategory.injections => AppColors.dangerSoft,
    MedicineCategory.other => AppColors.border,
  };

  Color get accent => switch (this) {
    MedicineCategory.tablets => AppColors.primary,
    MedicineCategory.capsules => AppColors.accentTeal,
    MedicineCategory.syrups => AppColors.warning,
    MedicineCategory.creams => AppColors.success,
    MedicineCategory.drops => AppColors.primaryDark,
    MedicineCategory.injections => AppColors.danger,
    MedicineCategory.other => AppColors.inkSoft,
  };
}

/// A medicine's picture. The first of these that exists wins:
///  1. the photo set on the drug by an admin (`drugs.image_path`)
///  2. a real pack photo uploaded by a verified chemist
///  3. a product picture bundled in the app:
///     `assets/images/medicine/products/NAME-FORM.png` or `NAME.png`
///     (exact names are listed in that folder's NAMES.txt)
///  4. the picture for its category: `assets/images/medicine/categories/SLUG.png`
///  4. a tinted illustration
class MedicineImage extends ConsumerWidget {
  const MedicineImage({
    super.key,
    required this.drug,
    required double this.size,
    this.radius = 18,
  }) : fill = false;

  /// Fills its parent edge to edge (e.g. the gallery showcase).
  const MedicineImage.fill({super.key, required this.drug, this.radius = 0})
    : size = null,
      fill = true;

  final Drug drug;
  final double? size;
  final double radius;
  final bool fill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = MedicineCategory.fromForm(drug.form);

    Widget illustration() => ColoredBox(
      color: const Color(0xFFF3F4F7),
      child: Center(
        child: Icon(
          category.icon,
          size: (size ?? 120) * 0.44,
          color: AppColors.ink,
        ),
      ),
    );

    Widget categoryPicture() {
      final asset = AppAssets.find(category.imageBase);
      return asset == null
          ? illustration()
          : Image.asset(
              asset,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => illustration(),
            );
    }

    final name = medicineSlug(drug.genericName);
    final bundled = AppAssets.findFirst([
      // Form-specific first (paracetamol-syrup), then one shared picture.
      if (drug.form != null)
        'assets/images/medicine/products/$name-${medicineSlug(drug.form!)}',
      'assets/images/medicine/products/$name',
    ]);
    final repo = ref.watch(drugRepositoryProvider);
    final url =
        repo.imageUrl(drug.imagePath) ??
        repo.inventoryPhotoUrl(drug.chemistPhotoPath);

    final Widget picture;
    if (url != null) {
      picture = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => bundled != null
            ? Image.asset(bundled, fit: BoxFit.cover)
            : categoryPicture(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : illustration(),
      );
    } else if (bundled != null) {
      picture = Image.asset(
        bundled,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => categoryPicture(),
      );
    } else {
      picture = categoryPicture();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: fill
          ? SizedBox.expand(child: picture)
          : SizedBox(width: size, height: size, child: picture),
    );
  }
}
