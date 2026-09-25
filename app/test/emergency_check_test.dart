import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/services/emergency_check.dart';

void main() {
  group('checkForEmergency', () {
    test('flags chest pain', () {
      final result = checkForEmergency(['I have chest pain and feel dizzy']);
      expect(result.flagged, isTrue);
      expect(result.matchedKeyword, 'chest pain');
    });

    test('flags suicidal ideation', () {
      final result = checkForEmergency(['I want to kill myself']);
      expect(result.flagged, isTrue);
    });

    test('is case-insensitive', () {
      final result = checkForEmergency([
        'DIFFICULTY BREATHING since this morning',
      ]);
      expect(result.flagged, isTrue);
    });

    test('does not flag ordinary symptoms', () {
      final result = checkForEmergency([
        'mild headache and runny nose for two days',
      ]);
      expect(result.flagged, isFalse);
      expect(result.matchedKeyword, isNull);
    });

    test('checks across multiple text fields', () {
      final result = checkForEmergency([
        'feeling unwell',
        null,
        'severe bleeding from a cut',
      ]);
      expect(result.flagged, isTrue);
    });

    test('handles empty input', () {
      final result = checkForEmergency(['', null]);
      expect(result.flagged, isFalse);
    });
  });
}
