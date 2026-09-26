import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/drug.dart';
import '../../../data/models/medicine_category.dart';
import '../../../data/models/prescription.dart';
import '../../patient/widgets/medicine_image.dart';

/// Asks the doctor for dose, quantity and instructions for [drug] (or, when
/// [drug] is null, for a medicine typed by name that is not in the
/// catalogue). Returns the prescription line, or null if dismissed.
Future<PrescriptionItem?> showDoseSheet(
  BuildContext context, {
  Drug? drug,
  PrescriptionItem? existing,
}) {
  return showModalBottomSheet<PrescriptionItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _DoseSheet(drug: drug, existing: existing),
  );
}

/// Common doses for a medicine's form, offered as one-tap chips.
List<String> doseSuggestions(String? form) =>
    switch (MedicineCategory.fromForm(form)) {
      MedicineCategory.tablets => const [
        '1 tablet once daily',
        '1 tablet twice daily',
        '1 tablet three times daily',
        '2 tablets at night',
      ],
      MedicineCategory.capsules => const [
        '1 capsule once daily',
        '1 capsule twice daily',
        '1 capsule three times daily',
      ],
      MedicineCategory.syrups => const [
        '5 ml three times daily',
        '10 ml twice daily',
        '2.5 ml twice daily (child)',
      ],
      MedicineCategory.creams => const [
        'Apply thinly twice daily',
        'Apply thinly once daily',
      ],
      MedicineCategory.drops => const [
        '1 drop three times daily',
        '2 drops twice daily',
      ],
      MedicineCategory.injections => const ['Single dose, given at clinic'],
      MedicineCategory.other => const ['As directed', '2 puffs when needed'],
    };

const _instructionChips = [
  'After food',
  'Before food',
  'At bedtime',
  'Complete the full course',
  'Avoid alcohol',
];

class _DoseSheet extends StatefulWidget {
  const _DoseSheet({this.drug, this.existing});

  final Drug? drug;
  final PrescriptionItem? existing;

  @override
  State<_DoseSheet> createState() => _DoseSheetState();
}

class _DoseSheetState extends State<_DoseSheet> {
  late final _nameCtrl = TextEditingController(
    text: widget.existing?.freeTextName ?? '',
  );
  late final _doseCtrl = TextEditingController(
    text: widget.existing?.dosage ?? '',
  );
  late final _instructionsCtrl = TextEditingController(
    text: widget.existing?.instructions ?? '',
  );
  late int _quantity = widget.existing?.quantity ?? 1;

  bool get _freeText => widget.drug == null;

  bool get _valid =>
      _doseCtrl.text.trim().isNotEmpty &&
      (!_freeText || _nameCtrl.text.trim().isNotEmpty);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _doseCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  void _addInstruction(String text) {
    final current = _instructionsCtrl.text.trim();
    if (current.toLowerCase().contains(text.toLowerCase())) return;
    _instructionsCtrl.text = current.isEmpty ? text : '$current. $text';
    setState(() {});
  }

  void _save() {
    final drug = widget.drug;
    String? clean(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    Navigator.of(context).pop(
      PrescriptionItem(
        prescriptionId: '',
        drugId: drug?.id,
        drug: drug,
        drugName: drug?.genericName,
        freeTextName: drug == null ? _nameCtrl.text.trim() : null,
        dosage: clean(_doseCtrl),
        quantity: _quantity,
        instructions: clean(_instructionsCtrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final drug = widget.drug;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (drug != null)
                  MedicineImage(drug: drug, size: 52, radius: 14)
                else
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      LucideIcons.pencilLine,
                      color: AppColors.ink,
                    ),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        drug?.genericName ?? 'Medicine not in the list',
                        style: theme.titleMedium,
                      ),
                      Text(
                        drug == null
                            ? 'Type the name; chemists will match it by hand.'
                            : [
                                if (drug.form != null) drug.form!,
                                if (drug.brandNames.isNotEmpty)
                                  drug.brandNames.take(2).join(', '),
                              ].join(' · '),
                        style: theme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_freeText) ...[
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Medicine name and strength',
                  hintText: 'e.g. Zinc sulphate 20 mg',
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text('Dose', style: theme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in doseSuggestions(drug?.form))
                  ChoiceChip(
                    label: Text(s),
                    selected: _doseCtrl.text == s,
                    onSelected: (_) => setState(() => _doseCtrl.text = s),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _doseCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Or type the dose',
                isDense: true,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Text('Quantity', style: theme.titleSmall)),
                _Stepper(
                  value: _quantity,
                  onChanged: (v) => setState(() => _quantity = v),
                ),
              ],
            ),
            Text(
              'Tablets, bottles, tubes... whatever the chemist hands over.',
              style: theme.bodySmall,
            ),
            const SizedBox(height: 18),
            Text('Instructions (optional)', style: theme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _instructionChips)
                  ActionChip(
                    label: Text(c),
                    onPressed: () => _addInstruction(c),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _instructionsCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'e.g. Take for 5 days',
                isDense: true,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _valid ? _save : null,
              icon: const Icon(LucideIcons.clipboardPlus, size: 18),
              label: Text(
                widget.existing == null
                    ? 'Add to prescription'
                    : 'Save changes',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, int? next) => IconButton.filledTonal(
      icon: Icon(icon, size: 16),
      onPressed: next == null ? null : () => onChanged(next),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(LucideIcons.minus, value > 1 ? value - 1 : null),
        SizedBox(
          width: 44,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        button(LucideIcons.plus, value < 1000 ? value + 1 : null),
      ],
    );
  }
}
