import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/prescription.dart';
import 'repository_providers.dart';

/// Prescriptions from one consultation, appearing live as the doctor sends
/// them (during the call or in the 24-hour chat afterwards).
final consultationPrescriptionsProvider = StreamProvider.autoDispose
    .family<List<Prescription>, String>(
      (ref, consultationId) => ref
          .watch(prescriptionRepositoryProvider)
          .watchForConsultation(consultationId),
    );

/// The signed-in doctor's most-prescribed medicines with their usual dose.
final usualPrescriptionsProvider =
    FutureProvider.autoDispose<List<PrescriptionItem>>(
      (ref) => ref.watch(prescriptionRepositoryProvider).usualPrescriptions(),
    );
