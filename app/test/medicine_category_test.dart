import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/data/models/medicine_category.dart';

void main() {
  test('every form currently in the database lands on a sensible shelf', () {
    const expected = {
      'tablet': MedicineCategory.tablets,
      'tablet (low-dose)': MedicineCategory.tablets,
      'capsule': MedicineCategory.capsules,
      'syrup': MedicineCategory.syrups,
      'sachet': MedicineCategory.syrups,
      'topical cream': MedicineCategory.creams,
      'topical lotion': MedicineCategory.creams,
      'topical gel': MedicineCategory.creams,
      'eye drops': MedicineCategory.drops,
      'eye ointment': MedicineCategory.drops,
      'nasal spray': MedicineCategory.drops,
      'nasal drops': MedicineCategory.drops,
      'inhaler': MedicineCategory.drops,
      'injection': MedicineCategory.injections,
      'IV infusion': MedicineCategory.injections,
    };
    expected.forEach((form, category) {
      expect(MedicineCategory.fromForm(form), category, reason: form);
    });
  });

  test('missing or unknown forms go to Other', () {
    expect(MedicineCategory.fromForm(null), MedicineCategory.other);
    expect(MedicineCategory.fromForm(''), MedicineCategory.other);
    expect(MedicineCategory.fromForm('lozenge'), MedicineCategory.other);
  });

  test('medicineSlug makes safe file names', () {
    expect(medicineSlug('Paracetamol'), 'paracetamol');
    expect(
      medicineSlug('Amoxicillin + Clavulanic acid'),
      'amoxicillin-clavulanic-acid',
    );
    expect(
      medicineSlug('  Oral Rehydration Salts (ORS) '),
      'oral-rehydration-salts-ors',
    );
  });
}
