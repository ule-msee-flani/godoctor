import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_client.dart';
import '../models/order.dart';

class CartLine {
  const CartLine({
    required this.drugId,
    required this.quantity,
    required this.unitPrice,
  });

  final String drugId;
  final int quantity;
  final double unitPrice;

  double get subtotal => quantity * unitPrice;
}

class OrderRepository {
  SupabaseClient get _client => SupabaseService.client;

  /// Creates an order + its line items, then immediately writes a
  /// `payments` row with `is_simulated = true` and flips escrow to `held`.
  ///
  /// The real M-Pesa Daraja integration (STK push, callback handling,
  /// actual escrow hold/release timing) is deferred per spec -- this is the
  /// documented seam: swap this method's payment half for a call to an Edge
  /// Function that talks to Daraja, keep everything else the same.
  Future<String> placeOrder({
    required String chemistId,
    String? prescriptionId,
    required List<CartLine> lines,
    required String fulfillmentType, // 'pickup' | 'delivery'
  }) async {
    final patientId = _client.auth.currentUser!.id;
    final total = lines.fold<double>(0, (sum, l) => sum + l.subtotal);

    final orderRow = await _client
        .from('orders')
        .insert({
          'patient_id': patientId,
          'chemist_id': chemistId,
          'prescription_id': prescriptionId,
          'total_amount': total,
          'escrow_status': 'held',
          'fulfillment_type': fulfillmentType,
        })
        .select()
        .single();
    final orderId = orderRow['id'] as String;

    await _client
        .from('order_items')
        .insert(
          lines
              .map(
                (l) => OrderItem(
                  orderId: orderId,
                  drugId: l.drugId,
                  quantity: l.quantity,
                  unitPrice: l.unitPrice,
                ).toInsertMap(),
              )
              .toList(),
        );

    // --- Mock payment step (M-Pesa STK push simulated) ---
    await _client.from('payments').insert({
      'order_id': orderId,
      'amount': total,
      'provider': 'mpesa',
      'status': 'succeeded',
      'is_simulated': true,
    });

    return orderId;
  }

  Future<List<Order>> fetchForPatient(String patientId) async {
    final rows = await _client
        .from('orders')
        .select(
          '*, order_items(*, drugs(generic_name)), chemist_profiles(business_name)',
        )
        .eq('patient_id', patientId)
        .order('created_at', ascending: false);
    return rows.map((r) => Order.fromMap(r)).toList();
  }

  Future<List<Order>> fetchForChemist(String chemistId) async {
    final rows = await _client
        .from('orders')
        .select('*, order_items(*, drugs(generic_name))')
        .eq('chemist_id', chemistId)
        .order('created_at', ascending: false);
    return rows.map((r) => Order.fromMap(r)).toList();
  }

  Stream<List<Order>> watchForChemist(String chemistId) {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('chemist_id', chemistId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((r) => Order.fromMap(r)).toList());
  }

  Future<void> chemistConfirm(String orderId) async {
    await _client
        .from('orders')
        .update({
          'status': 'confirmed',
          'confirmed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId);
  }

  Future<void> chemistMarkReady(String orderId) async {
    await _client
        .from('orders')
        .update({
          'status': 'ready',
          'ready_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId);
  }

  /// Patient confirms receipt: order -> fulfilled, escrow -> released.
  Future<void> patientConfirmReceipt(String orderId) async {
    await _client
        .from('orders')
        .update({
          'status': 'fulfilled',
          'escrow_status': 'released',
          'fulfilled_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId);
    await _client
        .from('payments')
        .update({
          'status': 'succeeded',
          'escrow_release_at': DateTime.now().toIso8601String(),
        })
        .eq('order_id', orderId);
  }

  /// Dispute/timeout path: exact auto-resolution policy is still TBD per
  /// spec -- for now this just flags the order for manual follow-up.
  Future<void> flagDisputed(String orderId) async {
    await _client
        .from('orders')
        .update({'status': 'disputed'})
        .eq('id', orderId);
  }
}
