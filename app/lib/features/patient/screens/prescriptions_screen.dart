import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
            icon: const Icon(Icons.upload_file),
            tooltip: 'Upload an external prescription',
            onPressed: () => context.push('/patient/prescriptions/upload'),
          ),
        ],
      ),
      body: prescriptions.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyView(
              message: 'No prescriptions yet.',
              icon: Icons.description_outlined,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
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
                Icon(
                  isExternal ? Icons.image_outlined : Icons.verified_outlined,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  isExternal ? 'Uploaded prescription' : 'Issued via GoDoctor',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  prescription.issuedAt.toLocal().toString().split(' ').first,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (!prescription.isValid)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Expired',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (prescription.items.isNotEmpty) ...[
              const Divider(height: 20),
              ...prescription.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '• ${item.displayName} '
                    '${item.dosage != null ? '(${item.dosage})' : ''} x${item.quantity}',
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
