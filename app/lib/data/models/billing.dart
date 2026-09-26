/// A saved way to pay. Cards keep only brand, last 4 digits and expiry --
/// never the full number or CVV.
class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.kind,
    required this.isDefault,
    this.label,
    this.mpesaPhone,
    this.cardBrand,
    this.cardLast4,
    this.cardExpMonth,
    this.cardExpYear,
  });

  final String id;

  /// mpesa | card
  final String kind;
  final String? label;

  /// 2547XXXXXXXX
  final String? mpesaPhone;
  final String? cardBrand;
  final String? cardLast4;
  final int? cardExpMonth;
  final int? cardExpYear;
  final bool isDefault;

  bool get isMpesa => kind == 'mpesa';

  /// "M-Pesa 0712 345 678" / "Visa •••• 4242"
  String get title {
    if (isMpesa) return 'M-Pesa ${formatKenyanPhone(mpesaPhone ?? '')}';
    final brand = switch (cardBrand) {
      'visa' => 'Visa',
      'mastercard' => 'Mastercard',
      'amex' => 'American Express',
      _ => 'Card',
    };
    return '$brand •••• $cardLast4';
  }

  String? get subtitle {
    final parts = [
      if ((label ?? '').isNotEmpty) label!,
      if (!isMpesa && cardExpMonth != null && cardExpYear != null)
        'Expires ${cardExpMonth.toString().padLeft(2, '0')}/${cardExpYear! % 100}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  factory PaymentMethod.fromMap(Map<String, dynamic> m) => PaymentMethod(
    id: m['id'] as String,
    kind: m['kind'] as String,
    label: m['label'] as String?,
    mpesaPhone: m['mpesa_phone'] as String?,
    cardBrand: m['card_brand'] as String?,
    cardLast4: m['card_last4'] as String?,
    cardExpMonth: (m['card_exp_month'] as num?)?.toInt(),
    cardExpYear: (m['card_exp_year'] as num?)?.toInt(),
    isDefault: (m['is_default'] as bool?) ?? false,
  );
}

class BillingSettings {
  const BillingSettings({
    this.payWithDefault = true,
    this.emailReceipts = true,
  });

  /// Use the default method at checkout without asking.
  final bool payWithDefault;
  final bool emailReceipts;

  factory BillingSettings.fromMap(Map<String, dynamic> m) => BillingSettings(
    payWithDefault: (m['pay_with_default'] as bool?) ?? true,
    emailReceipts: (m['email_receipts'] as bool?) ?? true,
  );
}

/// One past payment (a consultation or a medicine order).
class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.amount,
    required this.provider,
    required this.status,
    required this.createdAt,
    required this.isSimulated,
    this.consultationId,
    this.orderId,
  });

  final String id;
  final double amount;
  final String provider;
  final String status;
  final DateTime createdAt;
  final bool isSimulated;
  final String? consultationId;
  final String? orderId;

  String get what => consultationId != null ? 'Consultation' : 'Medicine order';

  factory PaymentRecord.fromMap(Map<String, dynamic> m) => PaymentRecord(
    id: m['id'] as String,
    amount: (m['amount'] as num?)?.toDouble() ?? 0,
    provider: (m['provider'] as String?) ?? 'mpesa',
    status: (m['status'] as String?) ?? 'pending',
    createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
    isSimulated: (m['is_simulated'] as bool?) ?? false,
    consultationId: m['consultation_id'] as String?,
    orderId: m['order_id'] as String?,
  );
}

/// Accepts 07XX/01XX, +2547XX, 2547XX (spaces/dashes allowed) and returns
/// 2547XXXXXXXX / 2541XXXXXXXX, or null if it isn't a Kenyan mobile number.
String? normalizeKenyanPhone(String input) {
  var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (RegExp(r'^0[17]\d{8}$').hasMatch(digits)) {
    digits = '254${digits.substring(1)}';
  } else if (RegExp(r'^[17]\d{8}$').hasMatch(digits)) {
    digits = '254$digits';
  }
  return RegExp(r'^254[17]\d{8}$').hasMatch(digits) ? digits : null;
}

/// 254712345678 -> "0712 345 678"
String formatKenyanPhone(String normalized) {
  if (!RegExp(r'^254\d{9}$').hasMatch(normalized)) return normalized;
  final local = '0${normalized.substring(3)}';
  return '${local.substring(0, 4)} ${local.substring(4, 7)} ${local.substring(7)}';
}

/// Card brand from the first digits (for display only).
String cardBrandOf(String number) {
  final d = number.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('4')) return 'visa';
  if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(d)) return 'mastercard';
  if (RegExp(r'^3[47]').hasMatch(d)) return 'amex';
  return 'other';
}

/// Luhn checksum: catches typos in a card number.
bool isValidCardNumber(String number) {
  final d = number.replaceAll(RegExp(r'\D'), '');
  if (d.length < 12 || d.length > 19) return false;
  var sum = 0;
  var alt = false;
  for (var i = d.length - 1; i >= 0; i--) {
    var n = int.parse(d[i]);
    if (alt) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
    alt = !alt;
  }
  return sum % 10 == 0;
}
