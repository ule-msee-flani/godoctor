import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_client.dart';
import '../models/prescription.dart';

class PrescriptionRepository {
  SupabaseClient get _client => SupabaseService.client;

  /// Doctor issues a prescription with one or more items during/after a
  /// consultation. Each item is either a structured `drug_id` match or a
  /// `free_text_name` fallback (see PrescriptionItem.isStructured).
  Future<String> issuePrescription({
    required String patientId,
    String? consultationId,
    required List<PrescriptionItem> items,
    DateTime? validUntil,
  }) async {
    final doctorId = _client.auth.currentUser!.id;
    final row = await _client
        .from('prescriptions')
        .insert({
          'patient_id': patientId,
          'doctor_id': doctorId,
          'consultation_id': consultationId,
          'source': 'app',
          'valid_until': validUntil?.toIso8601String().split('T').first,
        })
        .select()
        .single();
    final prescriptionId = row['id'] as String;

    if (items.isNotEmpty) {
      await _client
          .from('prescription_items')
          .insert(
            items
                .map(
                  (i) => PrescriptionItem(
                    prescriptionId: prescriptionId,
                    drugId: i.drugId,
                    freeTextName: i.freeTextName,
                    dosage: i.dosage,
                    quantity: i.quantity,
                    instructions: i.instructions,
                  ).toInsertMap(),
                )
                .toList(),
          );
    }
    return prescriptionId;
  }

  /// Doctor sends a prescription for [consultationId] (during the call or
  /// shortly after). Header and items are written in one transaction by the
  /// `issue_prescription` function, which also notifies the patient.
  Future<String> issueForConsultation({
    required String consultationId,
    required List<PrescriptionItem> items,
    int validDays = 30,
  }) async {
    final id = await _client.rpc(
      'issue_prescription',
      params: {
        'p_consultation_id': consultationId,
        'p_items': [
          for (final i in items)
            {
              'drug_id': i.drugId,
              'free_text_name': i.freeTextName,
              'dosage': i.dosage,
              'quantity': i.quantity,
              'instructions': i.instructions,
            },
        ],
        'p_valid_days': validDays,
      },
    );
    return id as String;
  }

  /// Prescriptions for one consultation, updating live as the doctor sends
  /// them (the stream carries headers only; items are fetched per change).
  Stream<List<Prescription>> watchForConsultation(String consultationId) =>
      _client
          .from('prescriptions')
          .stream(primaryKey: ['id'])
          .eq('consultation_id', consultationId)
          .order('issued_at')
          .asyncMap((_) => fetchForConsultation(consultationId));

  Future<List<Prescription>> fetchForConsultation(String consultationId) async {
    final rows = await _client
        .from('prescriptions')
        .select(_withItems)
        .eq('consultation_id', consultationId)
        .order('issued_at');
    return rows.map((r) => Prescription.fromMap(r)).toList();
  }

  static const _withItems = '*, prescription_items(*, drugs(*))';

  /// Patient uploads a photo of an external (non-app) prescription. Chemist
  /// manually verifies the photo before allowing the order to proceed.
  Future<String> uploadExternalPrescription({
    required Uint8List fileBytes,
    required String fileExt,
  }) async {
    final patientId = _client.auth.currentUser!.id;
    final path = '$patientId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

    await _client.storage
        .from('prescription-uploads')
        .uploadBinary(path, fileBytes);

    final row = await _client
        .from('prescriptions')
        .insert({
          'patient_id': patientId,
          'source': 'external_upload',
          'image_url': path,
        })
        .select()
        .single();
    return row['id'] as String;
  }

  String publicUrlForUpload(String path) =>
      _client.storage.from('prescription-uploads').getPublicUrl(path);

  Future<List<Prescription>> fetchForPatient(String patientId) async {
    final rows = await _client
        .from('prescriptions')
        .select(_withItems)
        .eq('patient_id', patientId)
        .order('issued_at', ascending: false);
    return rows.map((r) => Prescription.fromMap(r)).toList();
  }

  Future<Prescription?> fetchById(String id) async {
    final row = await _client
        .from('prescriptions')
        .select(_withItems)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Prescription.fromMap(row);
  }
}
