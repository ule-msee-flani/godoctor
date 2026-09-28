import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_client.dart';
import '../models/order.dart';
import '../models/chemist_dashboard.dart';

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

  static const _patientSelect =
      '*, order_items(*, drugs(generic_name)), chemist_profiles(business_name), '
      'reviews(rating)';

  /// Places an order in one step on the server: prices come from the
  /// chemist's stock list, stock is checked and set aside, a prescription is
  /// required where the medicine needs one, and the (simulated) M-Pesa
  /// payment is held until the patient confirms they got their medicine.
  ///
  /// The real M-Pesa Daraja integration (STK push, callback handling) is the
  /// documented seam: `place_order` records a simulated payment today.
  Future<String> placeOrder({
    required String chemistId,
    String? prescriptionId,
    required List<CartLine> lines,
    required String fulfillmentType, // 'pickup' | 'delivery'
  }) async {
    final id = await _client.rpc(
      'place_order',
      params: {
        'p_chemist': chemistId,
        'p_prescription': prescriptionId,
        'p_fulfillment': fulfillmentType,
        'p_lines': [
          for (final l in lines) {'drug_id': l.drugId, 'quantity': l.quantity},
        ],
      },
    );
    return id as String;
  }

  Future<List<Order>> fetchForPatient(String patientId) async {
    final rows = await _client
        .from('orders')
        .select(_patientSelect)
        .eq('patient_id', patientId)
        .order('created_at', ascending: false);
    return rows.map((r) => Order.fromMap(r)).toList();
  }

  Future<List<Order>> fetchForChemist(String chemistId) async {
    final rows = await _client
        .from('orders')
        .select('*, order_items(*, drugs(*))')
        .eq('chemist_id', chemistId)
        .order('created_at', ascending: false);
    return rows.map((r) => Order.fromMap(r)).toList();
  }

  /// Live orders for a chemist. Realtime rows carry no joins, so each change
  /// re-fetches the orders with their items.
  Stream<List<Order>> watchForChemist(String chemistId) {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('chemist_id', chemistId)
        .asyncMap((_) => fetchForChemist(chemistId));
  }

  /// One order with its items and pharmacy, or null if it isn't visible.
  Future<Order?> fetchOne(String orderId) async {
    final row = await _client
        .from('orders')
        .select(_patientSelect)
        .eq('id', orderId)
        .maybeSingle();
    return row == null ? null : Order.fromMap(row);
  }

  /// One order, kept up to date as the pharmacy moves it along.
  Stream<Order?> watchOrder(String orderId) {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .asyncMap((_) => fetchOne(orderId));
  }

  /// Rate the pharmacy after a completed order (once).
  Future<void> reviewPharmacy({
    required String orderId,
    required int rating,
    String? comment,
  }) => _client.rpc(
    'submit_order_review',
    params: {'p_order': orderId, 'p_rating': rating, 'p_comment': comment},
  );

  /// The signed-in pharmacy's dashboard numbers.
  Future<ChemistDashboard> chemistDashboard() async {
    final res = await _client.rpc('chemist_dashboard');
    return ChemistDashboard.fromJson((res as Map).cast<String, dynamic>());
  }

  Future<void> chemistConfirm(String orderId) => _advance(orderId, 'confirmed');

  Future<void> chemistMarkReady(String orderId) => _advance(orderId, 'ready');

  Future<void> _advance(String orderId, String status) => _client.rpc(
    'chemist_advance_order',
    params: {'p_order': orderId, 'p_status': status},
  );

  /// Patient confirms receipt: order -> fulfilled, payment released to the
  /// pharmacy. Only once the pharmacy has confirmed the order.
  Future<void> patientConfirmReceipt(String orderId) =>
      _client.rpc('confirm_order_received', params: {'p_order': orderId});

  /// Something went wrong: the order is flagged and our team follows up with
  /// the payment still held. [note] is what the patient tells us.
  Future<void> flagDisputed(String orderId, {String? note}) => _client.rpc(
    'dispute_order',
    params: {'p_order': orderId, 'p_note': note},
  );
}
