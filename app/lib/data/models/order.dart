import 'drug.dart';
import 'enums.dart';

class Order {
  const Order({
    required this.id,
    required this.patientId,
    required this.chemistId,
    this.prescriptionId,
    required this.status,
    required this.totalAmount,
    required this.escrowStatus,
    required this.fulfillmentType,
    required this.createdAt,
    this.items = const [],
    this.chemistName,
    this.problemNote,
    this.confirmedAt,
    this.readyAt,
    this.fulfilledAt,
    this.myRating,
  });

  final String id;
  final String patientId;
  final String chemistId;
  final String? prescriptionId;
  final OrderStatus status;
  final double totalAmount;
  final EscrowStatus escrowStatus;
  final FulfillmentType fulfillmentType;
  final DateTime createdAt;
  final List<OrderItem> items;
  final String? chemistName;

  /// What the patient said went wrong, when they reported a problem.
  final String? problemNote;
  final DateTime? confirmedAt;
  final DateTime? readyAt;
  final DateTime? fulfilledAt;

  /// The stars the patient gave the pharmacy for this order, if any.
  final int? myRating;

  bool get canRate => status == OrderStatus.fulfilled && myRating == null;

  factory Order.fromMap(Map<String, dynamic> map) => Order(
    id: map['id'] as String,
    patientId: map['patient_id'] as String,
    chemistId: map['chemist_id'] as String,
    prescriptionId: map['prescription_id'] as String?,
    status: enumFromDb(
      OrderStatus.values,
      map['status'] as String?,
      OrderStatus.placed,
    ),
    totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
    escrowStatus: enumFromDb(
      EscrowStatus.values,
      map['escrow_status'] as String?,
      EscrowStatus.held,
    ),
    fulfillmentType: enumFromDb(
      FulfillmentType.values,
      map['fulfillment_type'] as String?,
      FulfillmentType.pickup,
    ),
    createdAt: DateTime.parse(map['created_at'] as String),
    items:
        (map['order_items'] as List<dynamic>?)
            ?.map((e) => OrderItem.fromMap(e as Map<String, dynamic>))
            .toList() ??
        const [],
    chemistName:
        (map['chemist_profiles'] as Map<String, dynamic>?)?['business_name']
            as String?,
    problemNote: map['problem_note'] as String?,
    confirmedAt: _date(map['confirmed_at']),
    readyAt: _date(map['ready_at']),
    fulfilledAt: _date(map['fulfilled_at']),
    myRating: switch (map['reviews']) {
      [final Map<String, dynamic> r, ...] => (r['rating'] as num?)?.toInt(),
      final Map<String, dynamic> r => (r['rating'] as num?)?.toInt(),
      _ => null,
    },
  );
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

class OrderItem {
  const OrderItem({
    this.id,
    required this.orderId,
    required this.drugId,
    required this.quantity,
    required this.unitPrice,
    this.drugName,
    this.drug,
  });

  final String? id;
  final String orderId;
  final String drugId;
  final int quantity;
  final double unitPrice;
  final String? drugName;

  /// The catalogue entry (for pictures), when joined with `drugs(*)`.
  final Drug? drug;

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
    id: map['id'] as String?,
    orderId: map['order_id'] as String,
    drugId: map['drug_id'] as String,
    quantity: (map['quantity'] as num?)?.toInt() ?? 1,
    unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
    drugName:
        (map['drugs'] as Map<String, dynamic>?)?['generic_name'] as String?,
    drug: switch (map['drugs']) {
      final Map<String, dynamic> d when d['id'] != null => Drug.fromMap(d),
      _ => null,
    },
  );

  Map<String, dynamic> toInsertMap() => {
    'order_id': orderId,
    'drug_id': drugId,
    'quantity': quantity,
    'unit_price': unitPrice,
  };
}
