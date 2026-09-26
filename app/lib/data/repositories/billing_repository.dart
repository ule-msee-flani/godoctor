import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_client.dart';
import '../models/billing.dart';

/// Saved payment methods, billing preferences and payment history.
class BillingRepository {
  SupabaseClient get _client => SupabaseService.client;

  Future<List<PaymentMethod>> methods() async {
    final rows = await _client
        .from('payment_methods')
        .select()
        .order('is_default', ascending: false)
        .order('created_at');
    return rows.map(PaymentMethod.fromMap).toList();
  }

  /// [phone] must already be normalised (2547XXXXXXXX).
  Future<void> addMpesa({required String phone, String? label}) => _client
      .from('payment_methods')
      .insert({'kind': 'mpesa', 'mpesa_phone': phone, 'label': label});

  /// Only brand, last 4 and expiry are sent -- never the full number.
  Future<void> addCard({
    required String brand,
    required String last4,
    required int expMonth,
    required int expYear,
    String? label,
  }) => _client.from('payment_methods').insert({
    'kind': 'card',
    'card_brand': brand,
    'card_last4': last4,
    'card_exp_month': expMonth,
    'card_exp_year': expYear,
    'label': label,
  });

  Future<void> setDefault(String id) =>
      _client.from('payment_methods').update({'is_default': true}).eq('id', id);

  Future<void> remove(String id) =>
      _client.from('payment_methods').delete().eq('id', id);

  Future<BillingSettings> settings() async {
    final row = await _client.from('user_settings').select().maybeSingle();
    return row == null ? const BillingSettings() : BillingSettings.fromMap(row);
  }

  Future<void> saveSettings({
    required bool payWithDefault,
    required bool emailReceipts,
  }) => _client.from('user_settings').upsert({
    'user_id': _client.auth.currentUser!.id,
    'pay_with_default': payWithDefault,
    'email_receipts': emailReceipts,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  });

  /// Payments for my consultations and orders (newest first).
  Future<List<PaymentRecord>> history({int limit = 30}) async {
    final rows = await _client
        .from('payments')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(PaymentRecord.fromMap).toList();
  }
}
