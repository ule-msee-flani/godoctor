import '../data/models/doctor_profile.dart';

/// A specialty suggested for what the patient typed, plus the word that
/// triggered it (null when the query matched the specialty name itself).
class SpecialtySuggestion {
  const SpecialtySuggestion(this.specialty, {this.matchedOn});

  final String specialty;
  final String? matchedOn;
}

/// Plain-language symptom words -> the specialty a patient would most likely
/// want. This is signposting to a starting point, NOT triage or diagnosis:
/// every path still goes through the emergency keyword check and a doctor.
const _symptomKeywords = <String, List<String>>{
  'General Practice': [
    'fever',
    'cough',
    'cold',
    'flu',
    'headache',
    'sore throat',
    'fatigue',
    'tired',
    'malaria',
    'diarrhoea',
    'diarrhea',
    'vomit',
    'stomach',
    'nausea',
    'body ache',
    'weak',
  ],
  'Pediatrics': [
    'baby',
    'child',
    'infant',
    'toddler',
    'my son',
    'my daughter',
    'kid',
  ],
  'Obstetrics & Gynaecology': [
    'pregnan',
    'period',
    'menstrua',
    'contracept',
    'family planning',
    'breastfeed',
    'pcos',
    'vaginal',
  ],
  'Internal Medicine': [
    'diabetes',
    'sugar',
    'hypertension',
    'blood pressure',
    'cholesterol',
    'thyroid',
    'kidney',
    'ulcer',
  ],
  'Dermatology': [
    'rash',
    'acne',
    'skin',
    'itch',
    'eczema',
    'pimple',
    'hair loss',
    'fungal',
  ],
  'Psychiatry/Mental Health': [
    'anxiety',
    'anxious',
    'depress',
    'stress',
    'insomnia',
    'sleep',
    'panic',
    'mental',
  ],
  'Cardiology': ['palpitation', 'heart', 'irregular heartbeat'],
  'ENT': ['ear', 'sinus', 'nose', 'hearing', 'tonsil', 'throat'],
  'Orthopedics': [
    'back pain',
    'joint',
    'knee',
    'bone',
    'sprain',
    'shoulder',
    'neck pain',
    'muscle',
  ],
};

/// Suggests up to [max] specialties for free-text [query]: specialty-name
/// matches first, then symptom-keyword matches, falling back to General
/// Practice for any non-trivial text that matched nothing.
List<SpecialtySuggestion> suggestSpecialties(String query, {int max = 4}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];

  final results = <SpecialtySuggestion>[];
  void add(SpecialtySuggestion s) {
    if (results.length < max &&
        !results.any((r) => r.specialty == s.specialty)) {
      results.add(s);
    }
  }

  for (final name in kSpecialties) {
    if (name.toLowerCase().contains(q)) add(SpecialtySuggestion(name));
  }
  for (final entry in _symptomKeywords.entries) {
    for (final keyword in entry.value) {
      if (q.contains(keyword)) {
        add(SpecialtySuggestion(entry.key, matchedOn: keyword));
        break;
      }
    }
  }

  if (results.isEmpty && q.length >= 3) {
    add(const SpecialtySuggestion('General Practice'));
  }
  return results;
}
