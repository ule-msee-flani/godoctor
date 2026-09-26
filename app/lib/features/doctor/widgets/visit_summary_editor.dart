import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../data/models/consultation.dart';

/// Warning signs a doctor commonly gives ("come back urgently if...").
const kRedFlagOptions = [
  'Fever above 39°C, or lasting more than 3 days',
  'Difficulty breathing or chest pain',
  'Vomiting and can\'t keep fluids down',
  'Severe or worsening pain',
  'Rash, or swelling of the face or lips',
  'Blood in stool, urine or vomit',
  'No improvement after 48 hours',
];

/// One-tap starters for the plain-language summary.
const kSummaryTemplates = {
  'Viral infection':
      'This looks like a viral infection. Rest, drink plenty of fluids and '
      'take the medicines as prescribed. It should settle in a few days.',
  'Antibiotics':
      'Take the full course of antibiotics, even if you feel better before '
      'it\'s finished.',
  'Allergy':
      'Your symptoms suggest an allergy. Avoid the trigger where you can and '
      'take the antihistamine as prescribed.',
  'Blood pressure':
      'Keep a daily blood pressure log and bring it to your next visit. Cut '
      'down on salt.',
  'Tests needed':
      'Please get the tests we discussed done at a lab and share the results '
      'in your next consultation.',
};

/// The visit summary a doctor is writing, kept by the call screen so "End"
/// can save it.
class VisitSummaryDraft extends ChangeNotifier {
  final summary = TextEditingController();
  final otherFlags = TextEditingController();
  final Set<String> flags = {};
  DateTime? followUpOn;
  String _saved = '';

  VisitSummaryDraft() {
    summary.addListener(notifyListeners);
    otherFlags.addListener(notifyListeners);
  }

  void load(Consultation c) {
    summary.text = c.summaryForPatient ?? '';
    for (final line in (c.redFlags ?? '').split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      if (kRedFlagOptions.contains(t)) {
        flags.add(t);
      } else {
        otherFlags.text = otherFlags.text.isEmpty
            ? t
            : '${otherFlags.text}\n$t';
      }
    }
    followUpOn = c.followUpOn;
    _saved = _fingerprint;
  }

  String? get summaryText =>
      summary.text.trim().isEmpty ? null : summary.text.trim();

  String? get redFlagsText {
    final lines = [
      ...kRedFlagOptions.where(flags.contains),
      ...otherFlags.text
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty),
    ];
    return lines.isEmpty ? null : lines.join('\n');
  }

  bool get hasContent =>
      summaryText != null || redFlagsText != null || followUpOn != null;

  String get _fingerprint => '$summaryText|$redFlagsText|$followUpOn';

  bool get dirty => _fingerprint != _saved;

  void markSaved() {
    _saved = _fingerprint;
    notifyListeners();
  }

  void toggleFlag(String f) {
    flags.contains(f) ? flags.remove(f) : flags.add(f);
    notifyListeners();
  }

  void setFollowUp(DateTime? d) {
    followUpOn = d;
    notifyListeners();
  }

  void addTemplate(String text) {
    final cur = summary.text.trim();
    summary.text = cur.isEmpty ? text : '$cur\n\n$text';
  }

  @override
  void dispose() {
    summary.dispose();
    otherFlags.dispose();
    super.dispose();
  }
}

/// The Summary tab: what the patient takes home (plain language), warning
/// signs, and when to come back. It becomes the patient's visit summary card.
class VisitSummaryEditor extends StatelessWidget {
  const VisitSummaryEditor({
    super.key,
    required this.draft,
    required this.patientName,
    required this.onSave,
  });

  final VisitSummaryDraft draft;
  final String patientName;
  final Future<bool> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        final today = DateTime.now();
        DateTime inDays(int n) =>
            DateTime(today.year, today.month, today.day + n);
        final follow = draft.followUpOn;
        final presets = {'In 3 days': 3, 'In 1 week': 7, 'In 2 weeks': 14};
        final presetMatch = presets.entries
            .where((e) => follow != null && isSameDay(follow, inDays(e.value)))
            .firstOrNull
            ?.key;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text('For $patientName to keep', style: theme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Write it the way you\'d say it. The patient sees this on their '
              'visit summary and can share it.',
              style: theme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: draft.summary,
              minLines: 4,
              maxLines: 8,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: 'What you found and what to do next',
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in kSummaryTemplates.entries)
                  ActionChip(
                    avatar: const Icon(LucideIcons.plus, size: 14),
                    label: Text(t.key),
                    onPressed: () => draft.addTemplate(t.value),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Come back urgently if...', style: theme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in kRedFlagOptions)
                  FilterChip(
                    label: Text(f),
                    selected: draft.flags.contains(f),
                    onSelected: (_) => draft.toggleFlag(f),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: draft.otherFlags,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                hintText: 'Other warning signs (one per line)',
              ),
            ),
            const SizedBox(height: 24),
            Text('Follow-up', style: theme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('None'),
                  selected: follow == null,
                  onSelected: (_) => draft.setFollowUp(null),
                ),
                for (final p in presets.entries)
                  ChoiceChip(
                    label: Text(p.key),
                    selected: presetMatch == p.key,
                    onSelected: (_) => draft.setFollowUp(inDays(p.value)),
                  ),
                ChoiceChip(
                  avatar: const Icon(LucideIcons.calendarDays, size: 14),
                  label: Text(
                    follow != null && presetMatch == null
                        ? formatDayShort(follow)
                        : 'Pick a date',
                  ),
                  selected: follow != null && presetMatch == null,
                  onSelected: (_) async {
                    final d = await showDatePicker(
                      context: context,
                      firstDate: inDays(1),
                      lastDate: inDays(365),
                      initialDate: follow ?? inDays(7),
                    );
                    if (d != null) draft.setFollowUp(d);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: draft.hasContent && draft.dirty ? onSave : null,
              icon: Icon(
                draft.dirty ? LucideIcons.save : LucideIcons.check,
                size: 18,
              ),
              label: Text(
                !draft.hasContent
                    ? 'Save summary'
                    : draft.dirty
                    ? 'Save summary'
                    : 'Saved',
              ),
            ),
            if (draft.dirty && draft.hasContent)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'It\'s also saved when you end the consultation.',
                  textAlign: TextAlign.center,
                  style: theme.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
              ),
          ],
        );
      },
    );
  }
}
