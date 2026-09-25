import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/services/specialty_search.dart';

void main() {
  test('empty or whitespace query suggests nothing', () {
    expect(suggestSpecialties(''), isEmpty);
    expect(suggestSpecialties('   '), isEmpty);
  });

  test('matches a specialty by name', () {
    final result = suggestSpecialties('derma');
    expect(result.first.specialty, 'Dermatology');
    expect(result.first.matchedOn, isNull);
  });

  test('maps plain-language symptoms to a specialty', () {
    expect(
      suggestSpecialties('I have a rash on my arm').first.specialty,
      'Dermatology',
    );
    expect(
      suggestSpecialties('my baby has a fever').map((s) => s.specialty),
      containsAll(['Pediatrics', 'General Practice']),
    );
    expect(
      suggestSpecialties('feeling very anxious').first.specialty,
      'Psychiatry/Mental Health',
    );
  });

  test('records which keyword triggered the suggestion', () {
    expect(suggestSpecialties('bad knee pain').first.matchedOn, 'knee');
  });

  test('falls back to General Practice for unrecognised text', () {
    final result = suggestSpecialties('strange tingling');
    expect(result.single.specialty, 'General Practice');
  });

  test('very short unrecognised text gets no fallback', () {
    expect(suggestSpecialties('zz'), isEmpty);
  });

  test('never returns duplicates and respects max', () {
    final result = suggestSpecialties(
      'fever cough headache child rash',
      max: 3,
    );
    expect(result.length, lessThanOrEqualTo(3));
    expect(result.map((s) => s.specialty).toSet().length, result.length);
  });
}
