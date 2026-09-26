import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../data/models/prescription.dart';
import '../patient/widgets/medicine_image.dart';

/// A prescription laid out like the paper one: header, doctor and patient,
/// the medicines with dose and quantity, and a signature line.
///
/// The doctor sees it as a live draft while prescribing ([issuedAt] null,
/// with remove/edit buttons); the patient sees the issued copy.
class DigitalPrescription extends StatelessWidget {
  const DigitalPrescription({
    super.key,
    required this.doctorName,
    required this.patientName,
    required this.items,
    this.doctorDetail,
    this.issuedAt,
    this.validUntil,
    this.reference,
    this.onEditItem,
    this.onRemoveItem,
  });

  final String doctorName;

  /// e.g. the doctor's specialty.
  final String? doctorDetail;
  final String patientName;
  final List<PrescriptionItem> items;

  /// Null while it is still a draft.
  final DateTime? issuedAt;
  final DateTime? validUntil;

  /// Prescription id; the first 8 characters are shown as the reference.
  final String? reference;
  final ValueChanged<int>? onEditItem;
  final ValueChanged<int>? onRemoveItem;

  bool get _draft => issuedAt == null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final ref = reference
        ?.substring(0, reference!.length.clamp(0, 8))
        .toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header band.
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            child: Row(
              children: [
                const Text(
                  'Rx',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GoDoctor',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Digital prescription',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: _draft ? 0.18 : 1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _draft ? 'Draft' : 'Issued',
                    style: TextStyle(
                      color: _draft ? Colors.white : AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Wrap(
              spacing: 24,
              runSpacing: 10,
              children: [
                _Field(
                  label: 'Prescriber',
                  value: doctorName,
                  detail: doctorDetail,
                ),
                _Field(label: 'Patient', value: patientName),
                _Field(
                  label: 'Date',
                  value: formatDate(issuedAt ?? DateTime.now()),
                ),
                if (ref != null) _Field(label: 'Reference', value: ref),
              ],
            ),
          ),
          const Divider(height: 22, indent: 16, endIndent: 16),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.pill,
                    size: 18,
                    color: AppColors.inkFaint,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No medicines yet. Choose one from the medicines list and tap Prescribe.',
                      style: theme.bodyMedium,
                    ),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < items.length; i++)
              _ItemRow(
                index: i + 1,
                item: items[i],
                onEdit: onEditItem == null ? null : () => onEditItem!(i),
                onRemove: onRemoveItem == null ? null : () => onRemoveItem!(i),
              ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            color: AppColors.primarySofter,
            child: Row(
              children: [
                Icon(
                  _draft ? LucideIcons.penLine : LucideIcons.fileSignature,
                  size: 16,
                  color: _draft ? AppColors.inkFaint : AppColors.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _draft
                        ? 'Not sent yet. The patient sees it once you send it.'
                        : 'Digitally signed by $doctorName'
                              '${validUntil == null ? '' : ' · valid until ${formatDate(validUntil!)}'}',
                    style: theme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 90, maxWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: theme.labelSmall),
          const SizedBox(height: 2),
          Text(value, style: theme.titleSmall),
          if (detail != null) Text(detail!, style: theme.bodySmall),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.index,
    required this.item,
    this.onEdit,
    this.onRemove,
  });

  final int index;
  final PrescriptionItem item;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.drug != null)
              MedicineImage(drug: item.drug!, size: 48, radius: 12)
            else
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.pill,
                  size: 20,
                  color: AppColors.ink,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$index. ${item.displayName}', style: theme.titleSmall),
                  if (item.dosage != null)
                    Text(item.dosage!, style: theme.bodyMedium),
                  Text(
                    [
                      'Qty ${item.quantity}',
                      if (item.drug?.form != null) item.drug!.form!,
                      if (!item.isStructured) 'not in catalogue',
                    ].join(' · '),
                    style: theme.bodySmall,
                  ),
                  if (item.instructions != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.instructions!,
                        style: theme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(LucideIcons.x, size: 18),
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}
