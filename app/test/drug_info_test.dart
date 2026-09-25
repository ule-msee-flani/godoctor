import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/data/models/drug_info.dart';

void main() {
  test('parses a drug_info row', () {
    final info = DrugInfo.fromMap({
      'drug_id': 'd1',
      'matched_name': 'acetaminophen',
      'uses': 'Relieves minor aches and pains.',
      'warnings': null,
      'side_effects': 'Rash',
      'interactions': null,
      'source': 'openFDA',
      'source_url': 'https://dailymed.nlm.nih.gov/x',
    });
    expect(info.matchedName, 'acetaminophen');
    expect(info.uses, startsWith('Relieves'));
    expect(info.isEmpty, isFalse);
  });

  test('a row with no sections counts as empty', () {
    final info = DrugInfo.fromMap({'drug_id': 'd2'});
    expect(info.isEmpty, isTrue);
    expect(info.source, 'openFDA');
  });
}
