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
///  1. a product picture bundled in the app:
///     `assets/images/medicine/products/NAME-FORM.png` or `NAME.png`
///     (exact names are listed in that folder's NAMES.txt)
///  2. the photo set on the drug (`drugs.image_path` in the `drug-images` bucket)
///  3. the picture for its category: `assets/images/medicine/categories/<slug>.png`
///  4. a tinted illustration
class MedicineImage extends ConsumerWidget {
  const MedicineImage({
    super.key,
    required this.drug,
    required this.size,
    this.radius = 18,
  });

  final Drug drug;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = MedicineCategory.fromForm(drug.form);

    Widget illustration() => ColoredBox(
      color: category.soft,
      child: Center(
        child: Icon(category.icon, size: size * 0.44, color: category.accent),
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
    final url = bundled == null
        ? ref.watch(drugRepositoryProvider).imageUrl(drug.imagePath)
        : null;

    final Widget picture;
    if (bundled != null) {
      picture = Image.asset(
        bundled,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => categoryPicture(),
      );
    } else if (url != null) {
      picture = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => categoryPicture(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : illustration(),
      );
    } else {
      picture = categoryPicture();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: size, height: size, child: picture),
    );
  }
}
