import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../data/models/prescription.dart';
import '../auth/widgets/auth_hero.dart' show AppIconMark;
import 'prescription_pdf.dart';
import 'rx_line.dart';

const _rule = Color(0xFF7FA8D9); // the pale blue lines of a prescription pad
const _navy = Color(0xFF16305C);

/// A prescription drawn like the paper pad: the GoDoctor logo, patient /
/// date / age / gender on ruled lines, the Rx mark, each medicine with
/// "Take N times daily for N days", and the doctor's name as the signature.
///
/// The doctor sees it as a live draft while prescribing ([issuedAt] null,
/// with edit/remove); everyone else sees the issued copy, which can be
/// saved or shared as a PDF.
class DigitalPrescription extends StatelessWidget {
  const DigitalPrescription({
    super.key,
    required this.doctorName,
    required this.patientName,
    required this.items,
    this.doctorDetail,
    this.patientAge,
    this.patientGender,
    this.issuedAt,
    this.validUntil,
    this.reference,
    this.onEditItem,
    this.onRemoveItem,
    this.exportable = true,
  });

  final String doctorName;

  /// e.g. the doctor's specialty.
  final String? doctorDetail;
  final String patientName;
  final int? patientAge;
  final String? patientGender;
  final List<PrescriptionItem> items;

  /// Null while it is still a draft.
  final DateTime? issuedAt;
  final DateTime? validUntil;

  /// Prescription id; the first 8 characters are shown as the reference.
  final String? reference;
  final ValueChanged<int>? onEditItem;
  final ValueChanged<int>? onRemoveItem;

  /// Show "Save as PDF" / "Share" under an issued prescription.
  final bool exportable;

  bool get _draft => issuedAt == null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final ref = rxReference(reference);
    final date = issuedAt ?? DateTime.now();

    final paper = Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE6EAF0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0B1730),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Letterhead.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppIconMark(size: 46),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'GoDoctor',
                    style: theme.titleMedium?.copyWith(
                      color: _navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Digital prescription',
                    style: theme.bodySmall?.copyWith(color: _rule),
                  ),
                  if (ref.isNotEmpty)
                    Text(
                      'Ref $ref',
                      style: theme.bodySmall?.copyWith(color: _rule),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1.6, color: _rule),
          const SizedBox(height: 14),
          // Patient details on ruled lines.
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _Blank(label: 'Patient', value: patientName),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: _Blank(label: 'Date', value: formatDate(date)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _Blank(label: 'Age', value: patientAge?.toString()),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: _Blank(label: 'Gender', value: patientGender),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rx',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontFamilyFallback: const ['Times New Roman', 'Georgia'],
                  fontSize: 44,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
              const Spacer(),
              if (_draft)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.warning),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'DRAFT',
                    style: theme.labelSmall?.copyWith(
                      color: AppColors.warning,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No medicines yet. Choose one from the medicines list and tap Prescribe.',
                style: theme.bodyMedium?.copyWith(color: AppColors.inkSoft),
              ),
            )
          else
            for (var i = 0; i < items.length; i++)
              _RxItem(
                index: i + 1,
                line: RxLine.of(items[i]),
                onEdit: onEditItem == null ? null : () => onEditItem!(i),
                onRemove: onRemoveItem == null ? null : () => onRemoveItem!(i),
              ),
          const SizedBox(height: 18),
          Container(height: 1, color: _rule),
          const SizedBox(height: 14),
          // Validity on the left, the doctor's name as the signature.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _draft
                          ? 'Not sent yet'
                          : validUntil == null
                          ? 'Issued ${formatDate(date)}'
                          : 'Valid until ${formatDate(validUntil!)}',
                      style: theme.bodySmall?.copyWith(color: _navy),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Issued through GoDoctor',
                      style: theme.bodySmall?.copyWith(color: _rule),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      doctorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'cursive',
                        fontFamilyFallback: ['Brush Script MT', 'serif'],
                        fontStyle: FontStyle.italic,
                        fontSize: 22,
                        color: _navy,
                      ),
                    ),
                    Container(
                      width: 150,
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: _rule,
                    ),
                    Text(
                      [
                        doctorName,
                        if (doctorDetail != null && doctorDetail!.isNotEmpty)
                          doctorDetail!,
                      ].join(' · '),
                      maxLines: 2,
                      textAlign: TextAlign.end,
                      style: theme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (_draft || !exportable || items.isEmpty) return paper;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        paper,
        const SizedBox(height: 8),
        _ExportRow(
          data: PrescriptionPdfData(
            doctorName: doctorName,
            doctorDetail: doctorDetail,
            patientName: patientName,
            patientAge: patientAge,
            patientGender: patientGender,
            issuedAt: date,
            validUntil: validUntil,
            reference: reference,
            lines: [for (final i in items) RxLine.of(i)],
          ),
        ),
      ],
    );
  }
}

/// "Label: value" written on a ruled line.
class _Blank extends StatelessWidget {
  const _Blank({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('$label:', style: theme.bodySmall?.copyWith(color: _navy)),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            padding: const EdgeInsets.only(bottom: 2),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _rule)),
            ),
            child: Text(
              value ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.titleSmall?.copyWith(color: AppColors.ink),
            ),
          ),
        ),
      ],
    );
  }
}

class _RxItem extends StatelessWidget {
  const _RxItem({
    required this.index,
    required this.line,
    this.onEdit,
    this.onRemove,
  });

  final int index;
  final RxLine line;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final ink = theme.bodyMedium?.copyWith(color: AppColors.ink);
    final label = theme.bodySmall?.copyWith(color: _navy);

    Widget ruled(Widget child) => Container(
      padding: const EdgeInsets.only(bottom: 3),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _rule, width: 0.8)),
      ),
      child: child,
    );

    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              child: Text('$index.', style: theme.titleSmall),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ruled(
                    Text(
                      [
                        line.name,
                        if (line.form != null) '(${line.form})',
                      ].join(' '),
                      style: theme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (line.dose != null) ruled(Text(line.dose!, style: ink)),
                  if (line.timesDaily != null || line.days != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          if (line.timesDaily != null) ...[
                            Text('Take', style: label),
                            _Fill(line.timesLabel),
                            Text('daily', style: label),
                          ],
                          if (line.days != null) ...[
                            Text('for', style: label),
                            _Fill('${line.days}'),
                            Text(
                              line.days == 1 ? 'day.' : 'days.',
                              style: label,
                            ),
                          ],
                        ],
                      ),
                    ),
                  Text(
                    [
                      'Quantity: ${line.quantity}',
                      if (line.note != null) line.note!,
                    ].join('  ·  '),
                    style: theme.bodySmall,
                  ),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                tooltip: 'Remove',
                visualDensity: VisualDensity.compact,
                icon: const Icon(LucideIcons.x, size: 18),
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}

/// A filled-in blank ("Take [3 times] daily").
class _Fill extends StatelessWidget {
  const _Fill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 1),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _rule)),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(color: AppColors.ink),
      ),
    );
  }
}

class _ExportRow extends StatefulWidget {
  const _ExportRow({required this.data});

  final PrescriptionPdfData data;

  @override
  State<_ExportRow> createState() => _ExportRowState();
}

class _ExportRowState extends State<_ExportRow> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      await sharePrescriptionPdf(widget.data);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn\'t create the PDF. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: _busy ? null : _export,
        icon: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(LucideIcons.fileDown, size: 18),
        label: const Text('Save or share as PDF'),
      ),
    );
  }
}
