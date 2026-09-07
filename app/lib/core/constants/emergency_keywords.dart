/// Static, doctor-reviewed red-flag keyword list used by the emergency-detection
/// hard-stop on the intake form (see PROJECT_SPEC.md "Emergency detection").
///
/// This list is intentionally static and simple (substring match) rather than
/// ML-based -- it must be predictable and auditable. Review/extend with a
/// clinician before relying on it in production; false negatives are the
/// dangerous failure mode, so keep this list broad and err on the side of
/// flagging.
const List<String> kEmergencyKeywords = [
  // Cardiac / respiratory
  'chest pain',
  'crushing pain',
  'difficulty breathing',
  'can\'t breathe',
  'cannot breathe',
  'shortness of breath',
  'gasping',
  'turning blue',
  'lips blue',

  // Neurological
  'loss of consciousness',
  'unconscious',
  'unresponsive',
  'seizure',
  'convulsion',
  'stroke',
  'face drooping',
  'slurred speech',
  'sudden weakness',
  'sudden numbness',
  'can\'t speak',

  // Bleeding / trauma
  'severe bleeding',
  'heavy bleeding',
  'won\'t stop bleeding',
  'coughing blood',
  'vomiting blood',
  'blood in stool',
  'severe burn',
  'head injury',

  // Mental health
  'suicidal',
  'suicide',
  'want to die',
  'kill myself',
  'self harm',
  'self-harm',
  'ending my life',

  // Allergic / anaphylaxis
  'anaphylaxis',
  'throat closing',
  'swelling of the throat',
  'severe allergic reaction',
  'difficulty swallowing',

  // Pregnancy
  'pregnant and bleeding',
  'pregnancy bleeding',
  'severe abdominal pain pregnant',
  'reduced fetal movement',
  'water broke',

  // General severe
  'severe pain',
  'poisoning',
  'overdose',
  'not breathing',
];
