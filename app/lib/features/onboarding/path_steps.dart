import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/chemist_profile.dart';
import '../../data/models/doctor_profile.dart' show DoctorProfile;
import '../../data/models/patient_profile.dart';
import '../../data/models/doctor_profile.dart' show kSpecialties;
import 'path_inputs.dart';

/// Answers so far, by key. Keys starting with "_" stay in the app (picked
/// photo, "other" text); the rest go to the server as they are.
typedef Answers = Map<String, Object?>;
typedef SetAnswer = void Function(String key, Object? value);

/// One stop on the welcome path: one or two questions.
class PathStep {
  const PathStep({
    required this.id,
    required this.title,
    required this.keys,
    required this.build,
    this.subtitle,
    this.optional = false,
    this.isReady,
  });

  final String id;
  final String title;
  final String? subtitle;

  /// Optional steps can be skipped ("Skip for now").
  final bool optional;

  /// The answers this step writes (put back as they were when skipped).
  final List<String> keys;
  final Widget Function(BuildContext context, Answers a, SetAnswer set) build;

  /// Whether "Continue" is enabled (always, when null).
  final bool Function(Answers a)? isReady;
}

Set<String> _set(Object? v) => v is Set<String> ? v : <String>{};
String _str(Object? v) => v is String ? v : '';

/// "Asthma, Diabetes, my own" <-> chips + "other" text, for multi-choice
/// answers stored as one line of text.
({Set<String> picked, String other}) splitChoices(
  String? stored,
  List<String> known, {
  String? noneLabel,
}) {
  final picked = <String>{};
  final other = <String>[];
  for (final part in (stored ?? '').split(RegExp(r'[,;\n]'))) {
    final p = part.trim();
    if (p.isEmpty) continue;
    if (noneLabel != null &&
        RegExp(
          r'^(none|no|nil|no known.*)$',
          caseSensitive: false,
        ).hasMatch(p)) {
      picked.add('none');
      continue;
    }
    final hit = known.where((k) => k.toLowerCase() == p.toLowerCase());
    if (hit.isNotEmpty) {
      picked.add(hit.first);
    } else {
      other.add(p);
    }
  }
  if (other.isNotEmpty) picked.add('other');
  return (picked: picked, other: other.join(', '));
}

/// The chips + "other" back to one line ("None" when none).
String? joinChoices(Set<String> picked, String other, {String none = 'None'}) {
  if (picked.contains('none')) return none;
  final parts = [
    for (final p in picked)
      if (p != 'other') p,
    if (picked.contains('other') && other.trim().isNotEmpty) other.trim(),
  ];
  return parts.isEmpty ? null : parts.join(', ');
}

Widget _multiWithOther(
  Answers a,
  SetAnswer set, {
  required String key,
  required List<String> options,
  required String noneLabel,
  required String otherHint,
}) {
  final picked = _set(a['_${key}_set']);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ChoiceAnswer(
        compact: true,
        multi: true,
        exclusive: const {'none'},
        selected: picked,
        options: [
          ('none', noneLabel, LucideIcons.check),
          for (final o in options) (o, o, null),
          ('other', 'Something else', LucideIcons.plus),
        ],
        onChanged: (s) => set('_${key}_set', s),
      ),
      if (picked.contains('other')) ...[
        const SizedBox(height: 16),
        TextAnswer(
          value: _str(a['_${key}_other']),
          hint: otherHint,
          autofocus: true,
          onChanged: (v) => set('_${key}_other', v),
        ),
      ],
    ],
  );
}

const _conditionOptions = [
  'High blood pressure',
  'Diabetes',
  'Asthma',
  'Heart disease',
  'HIV',
  'Epilepsy',
  'Sickle cell',
  'Arthritis',
  'Kidney disease',
  'Depression or anxiety',
];

const _allergyOptions = [
  'Penicillin',
  'Sulfa drugs',
  'Aspirin or ibuprofen',
  'Peanuts',
  'Seafood',
  'Eggs',
  'Latex',
];

const kBloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

const _languages = [
  'English',
  'Kiswahili',
  'Kikuyu',
  'Dholuo',
  'Luhya',
  'Kalenjin',
  'Kamba',
  'Kisii',
  'Meru',
  'Somali',
  'French',
  'Arabic',
];

const _focusAreas = [
  'Fever, colds and flu',
  'Stomach problems',
  'Skin conditions',
  'Diabetes',
  'High blood pressure',
  'Mental health',
  'Women\'s health',
  'Children\'s health',
  'Sexual and reproductive health',
  'Chronic disease follow-up',
  'Allergies',
  'Travel health',
];

const _pharmacyServices = [
  'Blood pressure checks',
  'Blood sugar tests',
  'Family planning',
  'Vaccinations',
  'Pregnancy tests',
  'HIV self-test kits',
  'First aid',
  'Nutrition advice',
];

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

List<(String, String, IconData?)> _plain(List<String> xs) => [
  for (final x in xs) (x, x, null),
];

Widget _gender(Answers a, SetAnswer set) => ChoiceAnswer(
  compact: true,
  selected: {if (a['gender'] is String) a['gender'] as String},
  options: const [
    ('female', 'Female', null),
    ('male', 'Male', null),
    ('other', 'Prefer not to say', null),
  ],
  onChanged: (s) => set('gender', s.first),
);

// ---------------------------------------------------------------------------
// Patients: what doctors and pharmacists most need to know, most of it
// optional.
// ---------------------------------------------------------------------------
List<PathStep> patientSteps() => [
  PathStep(
    id: 'name',
    title: 'Welcome to GoDoctor! What\'s your name?',
    subtitle: 'This is how your doctor will greet you.',
    keys: const ['name'],
    isReady: (a) => _str(a['name']).trim().length >= 2,
    build: (context, a, set) => TextAnswer(
      value: _str(a['name']),
      hint: 'Your full name',
      capitalization: TextCapitalization.words,
      autofocus: _str(a['name']).isEmpty,
      onChanged: (v) => set('name', v),
    ),
  ),
  PathStep(
    id: 'basics',
    title: 'When were you born?',
    subtitle: 'Doctors use your age to give you the right advice.',
    optional: true,
    keys: const ['date_of_birth', 'gender'],
    build: (context, a, set) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DateAnswer(
          value: a['date_of_birth'] as DateTime?,
          onChanged: (d) => set('date_of_birth', d),
        ),
        const SubQuestion('And you are…'),
        _gender(a, set),
      ],
    ),
  ),
  PathStep(
    id: 'place',
    title: 'Where are you based?',
    subtitle: 'So we can find pharmacies and care near you.',
    optional: true,
    keys: const ['location_lat', 'location_lng', 'location_name', 'county'],
    build: (context, a, set) => LocationAnswer(
      name: a['location_name'] as String?,
      lat: a['location_lat'] as double?,
      lng: a['location_lng'] as double?,
      onChanged: (p) {
        set('location_lat', p.lat);
        set('location_lng', p.lng);
        set('location_name', p.name);
        set('county', countyFromPlace(p.name));
      },
    ),
  ),
  PathStep(
    id: 'conditions',
    title: 'Do you live with any long-term conditions?',
    subtitle: 'Your doctor sees this before your visit.',
    optional: true,
    keys: const ['_conditions_set', '_conditions_other'],
    build: (context, a, set) => _multiWithOther(
      a,
      set,
      key: 'conditions',
      options: _conditionOptions,
      noneLabel: 'None',
      otherHint: 'Which condition?',
    ),
  ),
  PathStep(
    id: 'allergies',
    title: 'Are you allergic to any medicines or foods?',
    subtitle: 'Doctors and pharmacists check this before giving you medicine.',
    optional: true,
    keys: const ['_allergies_set', '_allergies_other'],
    build: (context, a, set) => _multiWithOther(
      a,
      set,
      key: 'allergies',
      options: _allergyOptions,
      noneLabel: 'No known allergies',
      otherHint: 'What are you allergic to?',
    ),
  ),
  PathStep(
    id: 'medicines',
    title: 'Do you take any medicines regularly?',
    optional: true,
    keys: const ['_meds_yes', 'medications'],
    build: (context, a, set) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChoiceAnswer(
          selected: {if (a['_meds_yes'] is bool) '${a['_meds_yes']}'},
          options: const [
            ('true', 'Yes', LucideIcons.pill),
            ('false', 'No', LucideIcons.x),
          ],
          onChanged: (s) => set('_meds_yes', s.first == 'true'),
        ),
        if (a['_meds_yes'] == true) ...[
          const SubQuestion('Which ones?'),
          TextAnswer(
            value: _str(a['medications']),
            hint: 'e.g. Metformin 500 mg twice a day',
            maxLines: 3,
            maxLength: 500,
            autofocus: _str(a['medications']).isEmpty,
            onChanged: (v) => set('medications', v),
          ),
        ],
      ],
    ),
  ),
  PathStep(
    id: 'blood',
    title: 'Do you know your blood group?',
    subtitle: 'Useful in an emergency.',
    optional: true,
    keys: const ['blood_group'],
    build: (context, a, set) => ChoiceAnswer(
      compact: true,
      selected: {
        if (a['blood_group'] is String) a['blood_group'] as String,
        if (a['blood_group'] == '') 'unknown',
      },
      options: [
        for (final g in kBloodGroups) (g, g, null),
        ('unknown', 'I don\'t know', LucideIcons.circleHelp),
      ],
      onChanged: (s) => set('blood_group', s.first == 'unknown' ? '' : s.first),
    ),
  ),
  PathStep(
    id: 'emergency',
    title: 'Who should we call in an emergency?',
    subtitle: 'Only used if something serious comes up during a visit.',
    optional: true,
    keys: const ['emergency_name', 'emergency_phone'],
    build: (context, a, set) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextAnswer(
          value: _str(a['emergency_name']),
          hint: 'Their name',
          capitalization: TextCapitalization.words,
          onChanged: (v) => set('emergency_name', v),
        ),
        const SizedBox(height: 12),
        TextAnswer(
          value: _str(a['emergency_phone']),
          hint: 'Their phone number',
          keyboard: TextInputType.phone,
          maxLength: 15,
          onChanged: (v) => set('emergency_phone', v),
        ),
      ],
    ),
  ),
  PathStep(
    id: 'cover',
    title: 'How do you usually pay for health care?',
    optional: true,
    keys: const ['health_cover'],
    build: (context, a, set) => ChoiceAnswer(
      selected: {if (a['health_cover'] is String) a['health_cover'] as String},
      options: const [
        ('sha', 'SHA (Social Health Authority)', LucideIcons.shieldCheck),
        ('private', 'Private insurance', LucideIcons.briefcaseMedical),
        ('both', 'Both', LucideIcons.layers),
        ('none', 'I pay myself', LucideIcons.wallet),
      ],
      onChanged: (s) => set('health_cover', s.first),
    ),
  ),
  PathStep(
    id: 'heard',
    title: 'How did you hear about GoDoctor?',
    optional: true,
    keys: const ['heard_from'],
    build: (context, a, set) => ChoiceAnswer(
      compact: true,
      selected: {if (a['heard_from'] is String) a['heard_from'] as String},
      options: _plain(const [
        'Friend or family',
        'Social media',
        'Google or web search',
        'A health worker',
        'A pharmacy',
        'An advert',
        'Somewhere else',
      ]),
      onChanged: (s) => set('heard_from', s.first),
    ),
  ),
];

// ---------------------------------------------------------------------------
// Doctors: what patients look for when choosing a doctor.
// ---------------------------------------------------------------------------
List<PathStep> doctorSteps({
  required Future<void> Function(SetAnswer) pickPhoto,
}) => [
  PathStep(
    id: 'name',
    title: 'Welcome, Doctor. What name should patients see?',
    keys: const ['name', 'gender'],
    isReady: (a) => _str(a['name']).trim().length >= 3,
    build: (context, a, set) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextAnswer(
          value: _str(a['name']),
          hint: 'e.g. Dr Jane Wanjiru',
          capitalization: TextCapitalization.words,
          autofocus: _str(a['name']).isEmpty,
          onChanged: (v) => set('name', v),
        ),
        const SubQuestion('You are…'),
        _gender(a, set),
      ],
    ),
  ),
  PathStep(
    id: 'specialties',
    title: 'What\'s your speciality?',
    subtitle: 'Pick all that apply.',
    keys: const ['specialties'],
    isReady: (a) => _set(a['specialties']).isNotEmpty,
    build: (context, a, set) => ChoiceAnswer(
      compact: true,
      multi: true,
      selected: _set(a['specialties']),
      options: _plain(kSpecialties),
      onChanged: (s) => set('specialties', s),
    ),
  ),
  PathStep(
    id: 'experience',
    title: 'How many years have you practised?',
    keys: const ['years_experience'],
    build: (context, a, set) => NumberAnswer(
      value: (a['years_experience'] as int?) ?? 1,
      unit: ('year', 'years'),
      onChanged: (v) => set('years_experience', v),
    ),
  ),
  PathStep(
    id: 'languages',
    title: 'Which languages do you consult in?',
    keys: const ['languages'],
    isReady: (a) => _set(a['languages']).isNotEmpty,
    build: (context, a, set) => ChoiceAnswer(
      compact: true,
      multi: true,
      selected: _set(a['languages']),
      options: _plain(_languages),
      onChanged: (s) => set('languages', s),
    ),
  ),
  PathStep(
    id: 'practice',
    title: 'Where do you practise?',
    subtitle: 'Your hospital or clinic, and the county.',
    optional: true,
    keys: const ['practice_facility', 'practice_county'],
    build: (context, a, set) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextAnswer(
          value: _str(a['practice_facility']),
          hint: 'e.g. Kenyatta National Hospital',
          capitalization: TextCapitalization.words,
          onChanged: (v) => set('practice_facility', v),
        ),
        const SubQuestion('County'),
        DropdownMenu<String>(
          initialSelection: a['practice_county'] as String?,
          expandedInsets: EdgeInsets.zero,
          enableFilter: true,
          requestFocusOnTap: true,
          hintText: 'Choose a county',
          menuHeight: 320,
          dropdownMenuEntries: [
            for (final c in kCounties) DropdownMenuEntry(value: c, label: c),
          ],
          onSelected: (c) => set('practice_county', c),
        ),
      ],
    ),
  ),
  PathStep(
    id: 'focus',
    title: 'What do patients most often see you for?',
    subtitle: 'Helps patients with those problems find you.',
    optional: true,
    keys: const ['focus_areas'],
    build: (context, a, set) => ChoiceAnswer(
      compact: true,
      multi: true,
      selected: _set(a['focus_areas']),
      options: _plain(_focusAreas),
      onChanged: (s) => set('focus_areas', s),
    ),
  ),
  PathStep(
    id: 'fee',
    title: 'What do you charge per consultation?',
    subtitle: 'In Kenya shillings. You can change it any time.',
    keys: const ['consultation_fee'],
    isReady: (a) => ((a['consultation_fee'] as num?) ?? 0) > 0,
    build: (context, a, set) {
      final fee = (a['consultation_fee'] as num?)?.toInt();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChoiceAnswer(
            compact: true,
            selected: {if (fee != null) '$fee'},
            options: [
              for (final f in const [500, 800, 1000, 1500, 2000, 3000])
                ('$f', 'KES $f', null),
            ],
            onChanged: (s) => set('consultation_fee', int.parse(s.first)),
          ),
          const SubQuestion('Or type an amount'),
          TextAnswer(
            key: ValueKey('fee-$fee'),
            value: fee == null ? '' : '$fee',
            prefix: 'KES ',
            keyboard: TextInputType.number,
            digitsOnly: true,
            maxLength: 6,
            onChanged: (v) => set('consultation_fee', int.tryParse(v)),
          ),
        ],
      );
    },
  ),
  PathStep(
    id: 'times',
    title: 'When do you usually consult?',
    subtitle: 'Patients like to know when you\'re likely to be online.',
    optional: true,
    keys: const ['consult_times'],
    build: (context, a, set) => ChoiceAnswer(
      compact: true,
      multi: true,
      selected: _set(a['consult_times']),
      options: const [
        ('Early mornings', 'Early mornings', LucideIcons.sunrise),
        ('Daytime', 'Daytime', LucideIcons.sun),
        ('Evenings', 'Evenings', LucideIcons.sunset),
        ('Weekends', 'Weekends', LucideIcons.calendarDays),
        ('Overnight', 'Overnight', LucideIcons.moon),
      ],
      onChanged: (s) => set('consult_times', s),
    ),
  ),
  PathStep(
    id: 'about',
    title: 'Say hello to your patients',
    subtitle: 'A friendly photo and a line about you build trust.',
    optional: true,
    keys: const ['bio', '_photo', '_photo_ext'],
    build: (context, a, set) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PhotoAnswer(
          preview: a['_photo'] is Uint8List
              ? MemoryImage(a['_photo'] as Uint8List)
              : null,
          onPick: () => pickPhoto(set),
        ),
        const SizedBox(height: 22),
        TextAnswer(
          value: _str(a['bio']),
          hint:
              'e.g. I\'m a family doctor with 8 years\' experience. I enjoy '
              'helping people manage diabetes and blood pressure.',
          maxLines: 4,
          maxLength: 600,
          onChanged: (v) => set('bio', v),
        ),
      ],
    ),
  ),
];

/// Picks a photo into the answers (for the doctor's "about" step).
Future<void> pickPhotoInto(SetAnswer set) async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1200,
    imageQuality: 85,
  );
  if (file == null) return;
  set('_photo', await file.readAsBytes());
  set('_photo_ext', file.name.split('.').last);
}

// ---------------------------------------------------------------------------
// Pharmacies: what patients need to choose and reach them.
// ---------------------------------------------------------------------------
List<PathStep> chemistSteps() => [
  PathStep(
    id: 'name',
    title: 'Welcome! What\'s your pharmacy called?',
    keys: const ['business_name', 'phone'],
    isReady: (a) => _str(a['business_name']).trim().length >= 2,
    build: (context, a, set) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextAnswer(
          value: _str(a['business_name']),
          hint: 'e.g. Afya Chemist',
          capitalization: TextCapitalization.words,
          autofocus: _str(a['business_name']).isEmpty,
          onChanged: (v) => set('business_name', v),
        ),
        const SubQuestion('A number customers can call'),
        TextAnswer(
          value: _str(a['phone']),
          hint: '07XX XXX XXX',
          keyboard: TextInputType.phone,
          maxLength: 15,
          onChanged: (v) => set('phone', v),
        ),
      ],
    ),
  ),
  PathStep(
    id: 'place',
    title: 'Where is it?',
    subtitle: 'Patients nearby see you first.',
    optional: true,
    keys: const ['location_lat', 'location_lng', 'location_name'],
    build: (context, a, set) => LocationAnswer(
      name: a['location_name'] as String?,
      lat: a['location_lat'] as double?,
      lng: a['location_lng'] as double?,
      onChanged: (p) {
        set('location_lat', p.lat);
        set('location_lng', p.lng);
        set('location_name', p.name);
      },
    ),
  ),
  PathStep(
    id: 'pharmacist',
    title: 'Who\'s the pharmacist in charge?',
    optional: true,
    keys: const ['pharmacist_name'],
    build: (context, a, set) => TextAnswer(
      value: _str(a['pharmacist_name']),
      hint: 'Their full name',
      capitalization: TextCapitalization.words,
      onChanged: (v) => set('pharmacist_name', v),
    ),
  ),
  PathStep(
    id: 'hours',
    title: 'When are you open?',
    optional: true,
    keys: const ['open_days', 'opening_hours'],
    build: (context, a, set) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChoiceAnswer(
          compact: true,
          multi: true,
          selected: _set(a['open_days']),
          options: _plain(_days),
          onChanged: (s) => set('open_days', {
            for (final d in _days)
              if (s.contains(d)) d,
          }),
        ),
        const SubQuestion('Hours'),
        HoursAnswer(
          value: a['opening_hours'] as String?,
          onChanged: (v) => set('opening_hours', v),
        ),
      ],
    ),
  ),
  PathStep(
    id: 'delivery',
    title: 'Do you deliver?',
    optional: true,
    keys: const ['offers_delivery', 'delivery_radius_km'],
    build: (context, a, set) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChoiceAnswer(
          selected: {
            if (a['offers_delivery'] is bool) '${a['offers_delivery']}',
          },
          options: const [
            ('true', 'Yes, we deliver', LucideIcons.bike),
            ('false', 'Pickup only', LucideIcons.store),
          ],
          onChanged: (s) => set('offers_delivery', s.first == 'true'),
        ),
        if (a['offers_delivery'] == true) ...[
          const SubQuestion('How far?'),
          ChoiceAnswer(
            compact: true,
            selected: {
              if (a['delivery_radius_km'] is int) '${a['delivery_radius_km']}',
            },
            options: [
              for (final km in const [2, 5, 10, 20])
                ('$km', 'Up to $km km', null),
            ],
            onChanged: (s) => set('delivery_radius_km', int.parse(s.first)),
          ),
        ],
      ],
    ),
  ),
  PathStep(
    id: 'services',
    title: 'What else do you offer?',
    subtitle: 'Patients looking for these will find you.',
    optional: true,
    keys: const ['services'],
    build: (context, a, set) => ChoiceAnswer(
      compact: true,
      multi: true,
      selected: _set(a['services']),
      options: _plain(_pharmacyServices),
      onChanged: (s) => set('services', s),
    ),
  ),
  PathStep(
    id: 'till',
    title: 'Your M-Pesa till or paybill number',
    subtitle: 'For when patients pay you directly. Optional.',
    optional: true,
    keys: const ['mpesa_till'],
    build: (context, a, set) => TextAnswer(
      value: _str(a['mpesa_till']),
      hint: 'e.g. 123456',
      keyboard: TextInputType.number,
      digitsOnly: true,
      maxLength: 10,
      onChanged: (v) => set('mpesa_till', v),
    ),
  ),
];

/// Words between questions: warmer as the end gets closer.
String encouragement(int nextIndex, int total) {
  final left = total - nextIndex;
  if (left <= 1) return 'Last one!';
  if (left == 2) return 'Almost there.';
  const lines = [
    'Nice one.',
    'Got it, thanks.',
    'Great, keep going.',
    'You\'re doing great.',
    'Just a little more.',
  ];
  return lines[nextIndex % lines.length];
}

Answers _clean(Answers a) => {
  for (final e in a.entries)
    if (e.value != null && !(e.value is String && (e.value as String).isEmpty))
      e.key: e.value,
};

/// What we already know, so nobody types it twice.
Answers prefillPatient(PatientProfile? p) {
  final conditions = splitChoices(
    p?.chronicConditions,
    _conditionOptions,
    noneLabel: 'None',
  );
  final allergies = splitChoices(
    p?.allergies,
    _allergyOptions,
    noneLabel: 'No known allergies',
  );
  final meds = (p?.currentMedications ?? '').trim();
  return _clean({
    'name': p?.name,
    'date_of_birth': p?.dateOfBirth,
    'gender': p?.gender,
    'location_lat': p?.locationLat,
    'location_lng': p?.locationLng,
    'location_name': p?.locationName,
    if (conditions.picked.isNotEmpty) '_conditions_set': conditions.picked,
    '_conditions_other': conditions.other,
    if (allergies.picked.isNotEmpty) '_allergies_set': allergies.picked,
    '_allergies_other': allergies.other,
    if (meds.isNotEmpty) '_meds_yes': true,
    'medications': meds,
    'blood_group': p?.bloodGroup,
    'emergency_name': p?.emergencyContactName,
    'emergency_phone': p?.emergencyContactPhone,
  });
}

Answers prefillDoctor(DoctorProfile? d) => _clean({
  'name': d?.name,
  'gender': d?.gender,
  if ((d?.specialties ?? const []).isNotEmpty)
    'specialties': d!.specialties.toSet(),
  // The slider starts here; Continue keeps it.
  'years_experience': d?.yearsExperience ?? 1,
  'languages': (d?.languages ?? const []).isEmpty
      ? {'English'}
      : d!.languages.toSet(),
  'consultation_fee': d?.consultationFee?.round(),
  'bio': d?.bio,
});

Answers prefillChemist(ChemistProfile? c, {String? phone}) => _clean({
  'business_name': c?.businessName,
  'phone': phone,
  'location_lat': c?.locationLat,
  'location_lng': c?.locationLng,
  'location_name': c?.locationName,
});

/// The answers as the server expects them.
Map<String, Object?> answersForServer(Answers a) {
  final out = <String, Object?>{};
  for (final e in a.entries) {
    if (e.key.startsWith('_') || e.value == null) continue;
    final v = e.value;
    out[e.key] = switch (v) {
      final Set<String> s => s.toList(),
      final DateTime d =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      _ => v,
    };
  }
  if (a['_conditions_set'] is Set<String>) {
    out['conditions'] =
        joinChoices(_set(a['_conditions_set']), _str(a['_conditions_other'])) ??
        '';
  }
  if (a['_allergies_set'] is Set<String>) {
    out['allergies'] =
        joinChoices(
          _set(a['_allergies_set']),
          _str(a['_allergies_other']),
          none: 'No known allergies',
        ) ??
        '';
  }
  if (a['_meds_yes'] == false) out['medications'] = '';
  return out;
}
