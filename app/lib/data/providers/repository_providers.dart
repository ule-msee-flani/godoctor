import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/appointment_repository.dart';
import '../repositories/billing_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/consultation_repository.dart';
import '../repositories/doctor_directory_repository.dart';
import '../repositories/doctor_schedule_repository.dart';
import '../repositories/drug_repository.dart';
import '../repositories/family_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/prescription_repository.dart';
import '../repositories/profile_repository.dart';
import '../repositories/support_repository.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());
final profileRepositoryProvider = Provider((ref) => ProfileRepository());
final consultationRepositoryProvider = Provider(
  (ref) => ConsultationRepository(),
);
final drugRepositoryProvider = Provider((ref) => DrugRepository());
final prescriptionRepositoryProvider = Provider(
  (ref) => PrescriptionRepository(),
);
final orderRepositoryProvider = Provider((ref) => OrderRepository());
final doctorDirectoryRepositoryProvider = Provider(
  (ref) => DoctorDirectoryRepository(),
);
final appointmentRepositoryProvider = Provider(
  (ref) => AppointmentRepository(),
);
final doctorScheduleRepositoryProvider = Provider(
  (ref) => DoctorScheduleRepository(),
);
final notificationRepositoryProvider = Provider(
  (ref) => NotificationRepository(),
);
final familyRepositoryProvider = Provider((ref) => FamilyRepository());
final billingRepositoryProvider = Provider((ref) => BillingRepository());
final supportRepositoryProvider = Provider((ref) => SupportRepository());
