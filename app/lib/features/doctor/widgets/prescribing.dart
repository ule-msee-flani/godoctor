import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/drug.dart';
import '../../../data/models/prescription.dart';
import '../../../data/providers/prescription_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../medicine/medicine_gallery.dart';
import '../../prescription/digital_prescription.dart';
import 'dose_sheet.dart';

/// The prescription a doctor is putting together (not sent yet), and the
/// actions on it. Shared by the call screen and the chat's "new
/// prescription" screen.
mixin PrescriptionDrafting<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  final List<PrescriptionItem> draft = [];
  bool sending = false;

  String get draftConsultationId;

  void toast(String m, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m), action: action));
  }

  /// Called after a medicine is added or changed (e.g. to offer "View").
  void onDraftChanged(PrescriptionItem item, {required bool updated}) {
    toast(
      updated
          ? 'Updated ${item.displayName}'
          : 'Added ${item.displayName} to the prescription',
    );
  }

  /// Choose the dose for [drug] (or a medicine by name when null). With
  /// [template] (one of "your usual"), the sheet opens filled in.
  Future<void> prescribe(
    Drug? drug, {
    int? editIndex,
    PrescriptionItem? template,
  }) async {
    final index =
        editIndex ??
        (drug == null ? -1 : draft.indexWhere((i) => i.drugId == drug.id));
    final item = await showDoseSheet(
      context,
      drug: drug ?? (index >= 0 ? draft[index].drug : null),
      existing: index >= 0 ? draft[index] : null,
      template: index >= 0 ? null : template,
    );
    if (item == null || !mounted) return;
    setState(() {
      if (index >= 0) {
        draft[index] = item;
      } else {
        draft.add(item);
      }
    });
    onDraftChanged(item, updated: index >= 0);
  }

  Future<bool> sendDraft(String patientName) async {
    setState(() => sending = true);
    try {
      await ref
          .read(prescriptionRepositoryProvider)
          .issueForConsultation(
            consultationId: draftConsultationId,
            items: List.of(draft),
          );
      if (!mounted) return true;
      setState(draft.clear);
      toast('Prescription sent to $patientName');
      return true;
    } catch (e) {
      if (mounted) toast(friendlyError(e));
      return false;
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }
}

/// The medicine gallery to prescribe from, with the doctor's usual
/// prescriptions as one-tap chips on top.
class PrescribeMedicinesPanel extends ConsumerWidget {
  const PrescribeMedicinesPanel({
    super.key,
    required this.searchCtrl,
    required this.onSearch,
    required this.draft,
    required this.onPrescribe,
  });

  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  final List<PrescriptionItem> draft;
  final Future<void> Function(Drug? drug, {PrescriptionItem? template})
  onPrescribe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(medicineCatalogProvider);
    final usual = ref.watch(usualPrescriptionsProvider).valueOrNull ?? const [];
    final prescribedIds = {
      for (final i in draft)
        if (i.drugId != null) i.drugId!,
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: MedicineSearchField(
                  controller: searchCtrl,
                  onChanged: onSearch,
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Prescribe a medicine that is not in the list',
                child: OutlinedButton.icon(
                  onPressed: () => onPrescribe(null),
                  icon: const Icon(LucideIcons.pencilLine, size: 16),
                  label: const Text('By name'),
                ),
              ),
            ],
          ),
        ),
        if (usual.isNotEmpty && searchCtrl.text.isEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
              children: [
                Center(
                  child: Text(
                    'Your usual',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                const SizedBox(width: 8),
                for (final u in usual) ...[
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      [
                        u.displayName,
                        if (u.dosage?.isNotEmpty ?? false) u.dosage!,
                      ].join(' · '),
                    ),
                    onPressed: () {
                      final drug = catalog.valueOrNull
                          ?.where((d) => d.id == u.drugId)
                          .firstOrNull;
                      onPrescribe(drug, template: u);
                    },
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        Expanded(
          child: catalog.when(
            loading: () => const MedicineGallerySkeleton(showcaseHeight: 220),
            error: (e, _) => ErrorView(
              message: friendlyError(e),
              onRetry: () => ref.invalidate(medicineCatalogProvider),
            ),
            data: (drugs) => LayoutBuilder(
              builder: (context, c) => MedicineGallery(
                drugs: drugs,
                query: searchCtrl.text,
                markedIds: prescribedIds,
                markIcon: LucideIcons.clipboardCheck,
                markColor: AppColors.primary,
                showcaseHeight: (c.maxHeight * 0.5).clamp(200.0, 290.0),
                emptyMessage: 'The medicine catalogue is empty.',
                footerBuilder: (context, drug) {
                  final line = draft
                      .where((i) => i.drugId == drug.id)
                      .firstOrNull;
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          line == null
                              ? 'Tap Prescribe to choose the dose.'
                              : 'On prescription: ${line.dosage ?? ''} · Qty ${line.quantity}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: line == null
                                    ? AppColors.inkSoft
                                    : AppColors.primaryDark,
                                fontWeight: line == null
                                    ? null
                                    : FontWeight.w600,
                              ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onPressed: () => onPrescribe(drug),
                        icon: Icon(
                          line == null
                              ? LucideIcons.clipboardPlus
                              : LucideIcons.pencil,
                          size: 17,
                        ),
                        label: Text(line == null ? 'Prescribe' : 'Edit dose'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The prescription being written (editable) with Send, and the ones
/// already sent from this consultation.
class PrescriptionDraftPanel extends ConsumerWidget {
  const PrescriptionDraftPanel({
    super.key,
    required this.consultationId,
    required this.doctorName,
    required this.doctorDetail,
    required this.patientName,
    this.patientAge,
    this.patientGender,
    required this.draft,
    required this.sending,
    required this.onEdit,
    required this.onRemove,
    required this.onSend,
    required this.onBrowse,
  });

  final String consultationId;
  final String doctorName;
  final String? doctorDetail;
  final String patientName;
  final int? patientAge;
  final String? patientGender;
  final List<PrescriptionItem> draft;
  final bool sending;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onRemove;
  final VoidCallback onSend;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final sent =
        ref
            .watch(consultationPrescriptionsProvider(consultationId))
            .valueOrNull ??
        [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        DigitalPrescription(
          doctorName: doctorName,
          doctorDetail: doctorDetail,
          patientName: patientName,
          patientAge: patientAge,
          patientGender: patientGender,
          items: draft,
          onEditItem: onEdit,
          onRemoveItem: onRemove,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: onBrowse,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add medicine'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: draft.isEmpty || sending ? null : onSend,
                icon: sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(LucideIcons.send, size: 16),
                label: Text(
                  sending ? 'Sending…' : 'Send to $patientName',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        if (sent.isNotEmpty) ...[
          const SizedBox(height: 28),
          Row(
            children: [
              const Icon(
                LucideIcons.circleCheck,
                size: 18,
                color: AppColors.success,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sent to the patient (${sent.length})',
                  style: theme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'They can see it now and order the medicines from a chemist.',
            style: theme.bodySmall,
          ),
          const SizedBox(height: 12),
          for (final p in sent.reversed) ...[
            DigitalPrescription(
              doctorName: doctorName,
              doctorDetail: doctorDetail,
              patientName: patientName,
              patientAge: patientAge,
              patientGender: patientGender,
              items: p.items,
              issuedAt: p.issuedAt.toLocal(),
              validUntil: p.validUntil,
              reference: p.id,
            ),
            const SizedBox(height: 14),
          ],
        ],
      ],
    );
  }
}
