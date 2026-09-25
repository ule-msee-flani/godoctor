import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/data/models/drug.dart';

void main() {
  const drug = Drug(
    id: 'd1',
    genericName: 'Paracetamol',
    brandNames: ['Panadol'],
    form: 'tablet',
    requiresPrescription: false,
  );

  test('withChemistPhoto keeps every other field', () {
    final withPhoto = drug.withChemistPhoto('chem/d1_1.jpg');
    expect(withPhoto.chemistPhotoPath, 'chem/d1_1.jpg');
    expect(withPhoto.id, drug.id);
    expect(withPhoto.genericName, drug.genericName);
    expect(withPhoto.brandNames, drug.brandNames);
    expect(withPhoto.form, drug.form);
    expect(withPhoto.requiresPrescription, drug.requiresPrescription);
  });

  test('inventory rows carry the chemist pack photo', () {
    final item = ChemistInventoryItem.fromMap({
      'chemist_id': 'c1',
      'drug_id': 'd1',
      'quantity': 5,
      'price': 120,
      'last_updated_at': '2026-09-26T10:00:00Z',
      'image_path': 'c1/d1_1.jpg',
      'chemist_profiles': {'business_name': 'Afya Chemist'},
    });
    expect(item.imagePath, 'c1/d1_1.jpg');
    expect(item.chemistName, 'Afya Chemist');
  });

  test('rows without a photo parse to null', () {
    final item = ChemistInventoryItem.fromMap({
      'chemist_id': 'c1',
      'drug_id': 'd1',
      'quantity': 5,
      'price': 120,
      'last_updated_at': '2026-09-26T10:00:00Z',
    });
    expect(item.imagePath, isNull);
  });
}
