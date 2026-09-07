import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/prescription.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';

final _patientPrescriptionsProvider = FutureProvider<List<Prescription>>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return ref.watch(prescriptionRepositoryProvider).fetchForPatient(userId);
});

class PrescriptionsScreen extends ConsumerWidget {
  const PrescriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescriptions = ref.watch(_patientPrescriptionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My prescriptions'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.upload),
            tooltip: 'Upload an external prescription',
            onPressed: () => context.push('/patient/prescriptions/upload'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: prescriptions.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (list) {
          if (list.isEmpty) {
            return EmptyView(
              message: 'No prescriptions yet.',
              icon: LucideIcons.fileText,
              action: OutlinedButton.icon(
                icon: const Icon(LucideIcons.upload, size: 18),
                label: const Text('Upload one'),
                onPressed: () => context.push('/patient/prescriptions/upload'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _PrescriptionCard(prescription: list[i]),
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
                    color: isExternal ? AppColors.warningSoft : AppColors.successSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      isExternal
                          ? LucideIcons.image
                          : LucideIcons.badgeCheck,
                      size: 20,
                      color: isExternal ? AppColors.warning : AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isExternal ? 'Uploaded prescription' : 'Issued via GoDoctor',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  prescription.issuedAt.toLocal().toString().split(' ').first,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (!prescription.isValid)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
            ],
          ],
        ),
      ),
    );
  }
}
