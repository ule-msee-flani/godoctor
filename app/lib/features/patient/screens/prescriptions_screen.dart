import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/prescription.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../medications/dose_reminder_sheet.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../../services/live_updates.dart';
import '../visits/visit_widgets.dart' show MonthHeader, groupByMonth;

final _patientPrescriptionsProvider = FutureProvider<List<Prescription>>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  ref.watch(liveTick(LiveTable.prescriptions));
  if (userId == null) return [];
  return ref.watch(prescriptionRepositoryProvider).fetchForPatient(userId);
});

class PrescriptionsScreen extends StatelessWidget {
  const PrescriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My prescriptions')),
    body: const PrescriptionsList(),
  );
}

/// The list itself (with an upload action on top), reused by the Health tab:
/// prescriptions you can still use first, then older ones by month.
class PrescriptionsList extends ConsumerWidget {
  const PrescriptionsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescriptions = ref.watch(_patientPrescriptionsProvider);
    final upload = OutlinedButton.icon(
      icon: const Icon(LucideIcons.upload, size: 18),
      label: const Text('Upload an external prescription'),
      onPressed: () => context.push('/patient/prescriptions/upload'),
    );

    return LiveRefresh(
      onRefresh: () => ref.refresh(_patientPrescriptionsProvider.future),
      child: prescriptions.when(
        loading: () => const SkeletonList(),
        error: (e, _) =>
            PullableFill(child: ErrorView(message: friendlyError(e))),
        data: (list) {
          if (list.isEmpty) {
            return PullableFill(
              child: EmptyView(
                message:
                    'No prescriptions yet.\nPrescriptions from your visits '
                    'appear here. You can also upload a paper one.',
                icon: LucideIcons.fileText,
                action: upload,
              ),
            );
          }
          final valid = [
            for (final p in list)
              if (p.isValid) p,
          ];
          final older = [
            for (final p in list)
              if (!p.isValid) p,
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              upload,
              if (valid.isNotEmpty) ...[
                MonthHeader('Valid now', count: valid.length),
                for (final p in valid)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PrescriptionCard(prescription: p),
                  ),
              ],
              for (final (label, group) in groupByMonth(
                older,
                (p) => p.issuedAt.toLocal(),
              )) ...[
                MonthHeader(label, count: group.length),
                for (final p in group)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PrescriptionCard(prescription: p),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PrescriptionCard extends StatelessWidget {
  const _PrescriptionCard({required this.prescription});

  final Prescription prescription;

  @override
  Widget build(BuildContext context) {
    final isExternal = prescription.source.name == 'externalUpload';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // The full prescription, to read or save as a PDF.
        onTap: () => context.push('/patient/prescription/${prescription.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isExternal
                          ? AppColors.warningSoft
                          : AppColors.successSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        isExternal ? LucideIcons.image : LucideIcons.badgeCheck,
                        size: 20,
                        color: isExternal
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isExternal
                          ? 'Uploaded prescription'
                          : 'Issued via GoDoctor',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    formatDate(prescription.issuedAt.toLocal()),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: AppColors.inkFaint,
                  ),
                ],
              ),
              if (!prescription.isValid)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Expired',
                      style: TextStyle(color: AppColors.danger, fontSize: 12),
                    ),
                  ),
                ),
              if (prescription.items.isNotEmpty) ...[
                const Divider(height: 24),
                ...prescription.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Icon(
                            LucideIcons.pill,
                            size: 15,
                            color: AppColors.inkFaint,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${item.displayName}'
                            '${item.dosage != null ? ' (${item.dosage})' : ''} '
                            '· x${item.quantity}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (prescription.isValid &&
                    prescription.items.any((i) => i.isStructured)) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => context.push(
                          '/patient/prescription/${prescription.id}/order',
                        ),
                        icon: const Icon(LucideIcons.shoppingBag, size: 16),
                        label: const Text('Order these medicines'),
                      ),
                      TextButton.icon(
                        onPressed: () => showDoseReminderSheet(
                          context,
                          items: prescription.items,
                        ),
                        icon: const Icon(LucideIcons.alarmClock, size: 16),
                        label: const Text('Remind me'),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
