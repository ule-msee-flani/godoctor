import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/auth_repository.dart';
import '../repositories/consultation_repository.dart';
import '../repositories/drug_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/prescription_repository.dart';
import '../repositories/profile_repository.dart';

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
