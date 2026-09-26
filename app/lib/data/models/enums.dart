/// Dart mirrors of the Postgres enum types from
/// supabase/migrations/0001_extensions_and_enums.sql.
/// Each enum stores its exact Postgres label so `.name` round-trips cleanly.
library;

enum UserRole { patient, doctor, chemist, admin }

enum UserStatus { active, suspended }

enum DoctorStatus { available, offered, busy, offline }

enum ConsultationStatus {
  requested,
  matched,
  inProgress,
  completed,
  cancelled,
  unmatched,
  scheduled,

  /// Patient chose a doctor and is paying; the doctor is reserved.
  awaitingPayment,
}

enum ConsultationMode { onDemand, scheduled }

enum OfferStatus { pending, accepted, declined, expired }

enum PrescriptionSource { app, externalUpload }

enum OrderStatus { placed, confirmed, ready, fulfilled, disputed, refunded }

enum EscrowStatus { held, released, refunded }

enum FulfillmentType { pickup, delivery }

enum PaymentProvider { mpesa, card }

enum PaymentStatus { pending, succeeded, failed, refunded }

/// Postgres uses snake_case labels (e.g. `in_progress`, `external_upload`);
/// Dart enum members are camelCase. These helpers bridge the two directions.
extension EnumDbCoding on Object {
  static const _snakeOverrides = {
    'inProgress': 'in_progress',
    'externalUpload': 'external_upload',
  };

  static String toDb(Enum value) {
    final name = value.name;
    return _snakeOverrides[name] ??
        name.replaceAllMapped(
          RegExp('([A-Z])'),
          (m) => '_${m.group(1)!.toLowerCase()}',
        );
  }
}

T enumFromDb<T extends Enum>(List<T> values, String? dbValue, T fallback) {
  if (dbValue == null) return fallback;
  for (final v in values) {
    if (EnumDbCoding.toDb(v) == dbValue) return v;
  }
  return fallback;
}
