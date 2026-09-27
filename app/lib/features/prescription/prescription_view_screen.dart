import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/widgets/loading_view.dart';
import '../../data/models/enums.dart';
import '../../data/models/prescription.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/repository_providers.dart';
import '../../data/repositories/repository_errors.dart';
import '../medications/dose_reminder_sheet.dart';
import '../patient/screens/doctor_profile_screen.dart'
    show publicDoctorProvider;
import 'digital_prescription.dart';

final _prescriptionProvider = FutureProvider.autoDispose
    .family<Prescription?, String>(
      (ref, id) => ref.watch(prescriptionRepositoryProvider).fetchById(id),
    );

/// One prescription on its own page: the paper copy (save or share as
/// PDF), and ordering / reminders.
class PrescriptionViewScreen extends ConsumerWidget {
  const PrescriptionViewScreen({super.key, required this.prescriptionId});

  final String prescriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_prescriptionProvider(prescriptionId));
    final patient = ref.watch(currentPatientProfileProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Prescription')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: friendlyError(e)),
        data: (p) {
          if (p == null) {
            return const ErrorView(message: 'Prescription not found');
          }
          if (p.source == PrescriptionSource.externalUpload) {
            final url = p.imageUrl == null
                ? null
                : ref
                      .read(prescriptionRepositoryProvider)
                      .publicUrlForUpload(p.imageUrl!);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (url != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
              ],
            );
          }
          final doctor = p.doctorId == null
              ? null
              : ref.watch(publicDoctorProvider(p.doctorId!)).valueOrNull;
          final canOrder = p.isValid && p.items.any((i) => i.isStructured);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              DigitalPrescription(
                doctorName: doctor?.name ?? 'Your doctor',
                doctorDetail: doctor?.primarySpecialty,
                patientName: patient?.name ?? '',
                patientAge: patient?.ageOn(p.issuedAt),
                patientGender: patient?.genderLabel,
                items: p.items,
                issuedAt: p.issuedAt.toLocal(),
                validUntil: p.validUntil,
                reference: p.id,
              ),
              const SizedBox(height: 16),
              if (canOrder)
                FilledButton.icon(
                  onPressed: () =>
                      context.push('/patient/prescription/${p.id}/order'),
                  icon: const Icon(LucideIcons.shoppingBag, size: 18),
                  label: const Text('Order these medicines'),
                ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => showDoseReminderSheet(context, items: p.items),
                icon: const Icon(LucideIcons.alarmClock, size: 18),
                label: const Text('Remind me to take them'),
              ),
            ],
          );
        },
      ),
    );
  }
}
