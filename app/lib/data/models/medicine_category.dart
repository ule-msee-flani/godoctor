import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The rows of the "Order medicine" gallery. The database stores a free-text
/// `form` per drug (tablet, topical cream, IV infusion...); this groups those
/// into a handful of shelves a patient recognises.
enum MedicineCategory {
  tablets('Tablets', 'tablets', LucideIcons.tablets),
  capsules('Capsules', 'capsules', LucideIcons.pill),
  syrups('Syrups & Sachets', 'syrups', LucideIcons.flaskConical),
  creams('Creams & Topicals', 'creams', LucideIcons.pipette),
  drops('Drops, Sprays & Inhalers', 'drops', LucideIcons.droplets),
  injections('Injections & Infusions', 'injections', LucideIcons.syringe),
  other('Other', 'other', LucideIcons.package);

  const MedicineCategory(this.label, this.slug, this.icon);

  final String label;

  /// Category picture: `assets/images/medicine/categories/SLUG.png`.
  final String slug;
  final IconData icon;

  String get imageBase => 'assets/images/medicine/categories/$slug';

  /// Maps the free-text `drugs.form` value to a shelf.
  static MedicineCategory fromForm(String? form) {
    final f = (form ?? '').toLowerCase();
    if (f.isEmpty) return other;
    // Eye/ear/nose products first: "eye ointment" is a drop-type product, not
    // a skin cream, even though it contains "ointment".
    if (f.contains('eye') ||
        f.contains('ear') ||
        f.contains('nasal') ||
        f.contains('drop') ||
        f.contains('spray') ||
        f.contains('inhaler')) {
      return drops;
    }
    if (f.contains('tablet')) return tablets;
    if (f.contains('capsule')) return capsules;
    if (f.contains('syrup') ||
        f.contains('sachet') ||
        f.contains('suspension') ||
        f.contains('solution') ||
        f.contains('liquid')) {
      return syrups;
    }
    if (f.contains('cream') ||
        f.contains('lotion') ||
        f.contains('gel') ||
        f.contains('ointment') ||
        f.contains('topical')) {
      return creams;
    }
    if (f.contains('inject') || f.contains('infusion') || f.contains('iv')) {
      return injections;
    }
    return other;
  }
}

/// File-name friendly version of a medicine name, used to find a bundled
/// product picture: "Amoxicillin + Clavulanic acid" ->
/// "amoxicillin-clavulanic-acid".
String medicineSlug(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');
