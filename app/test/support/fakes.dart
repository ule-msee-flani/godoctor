// Shared in-memory fakes for repositories that would otherwise talk to
// Supabase (or the internet) during widget tests.
import 'package:godoctor_app/data/models/billing.dart';
import 'package:godoctor_app/data/models/family.dart';
import 'package:godoctor_app/data/models/support.dart';
import 'package:godoctor_app/data/repositories/auth_repository.dart';
import 'package:godoctor_app/data/repositories/billing_repository.dart';
import 'package:godoctor_app/data/repositories/family_repository.dart';
import 'package:godoctor_app/data/repositories/support_repository.dart';
import 'package:godoctor_app/services/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeAuth extends AuthRepository {
  FakeAuth({this.email = 'amina@example.com'});

  final String email;
  String? changedPassword;

  @override
  User? get currentAuthUser => User(
    id: 'p1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime(2026).toIso8601String(),
    email: email,
  );

  @override
  Future<void> signOut() async {}

  @override
  Future<void> changePassword(String newPassword) async =>
      changedPassword = newPassword;
}

class FakeFamily extends FamilyRepository {
  FakeFamily({
    List<FamilyMember>? members,
    this.info,
    this.sessionPeople = const [],
  }) : members = members ?? defaultMembers;

  static const defaultMembers = [
    FamilyMember(
      linkId: 'l1',
      userId: 'u-baraka',
      name: 'Baraka Otieno',
      relationship: 'Sibling',
      status: 'accepted',
      invitedByMe: true,
      online: true,
    ),
    FamilyMember(
      linkId: 'l2',
      userId: 'u-mama',
      name: 'Grace Wanjiku',
      relationship: 'Parent',
      status: 'accepted',
      invitedByMe: false,
      online: false,
    ),
    FamilyMember(
      linkId: 'l3',
      userId: 'u-chege',
      name: 'Chege Kamau',
      relationship: 'Family',
      status: 'pending',
      invitedByMe: false,
      online: false,
    ),
    FamilyMember(
      linkId: 'l4',
      userId: 'u-njeri',
      name: 'Njeri Kamau',
      relationship: 'Child',
      status: 'pending',
      invitedByMe: true,
      online: false,
    ),
  ];

  final List<FamilyMember> members;
  final FamilySessionInfo? info;
  final List<SessionPerson> sessionPeople;

  ({String contact, String relationship})? invited;
  final List<String> invitedToSession = [];
  bool? joined;

  @override
  Future<List<FamilyMember>> myFamily() async => members;

  @override
  Future<void> invite({
    required String contact,
    required String relationship,
  }) async => invited = (contact: contact, relationship: relationship);

  @override
  Future<void> respond(String linkId, {required bool accept}) async {}

  @override
  Future<void> remove(String linkId) async {}

  @override
  Future<void> inviteToConsultation(
    String consultationId,
    String memberId,
  ) async => invitedToSession.add(memberId);

  @override
  Future<void> removeFromConsultation(
    String consultationId,
    String userId,
  ) async {}

  @override
  Future<void> respondToSession(
    String consultationId, {
    required bool join,
  }) async => joined = join;

  @override
  Future<List<SessionPerson>> people(String consultationId) async =>
      sessionPeople;

  @override
  Stream<List<SessionPerson>> watchPeople(String consultationId) =>
      Stream.value(sessionPeople);

  @override
  Future<FamilySessionInfo?> sessionInfo(String consultationId) async => info;

  @override
  Stream<List<String>> watchMyInvites(String userId) =>
      Stream.value(info == null ? const [] : [info!.consultationId]);
}

class FakeBilling extends BillingRepository {
  final List<Map<String, Object?>> added = [];

  @override
  Future<List<PaymentMethod>> methods() async => const [
    PaymentMethod(
      id: 'm1',
      kind: 'mpesa',
      mpesaPhone: '254712345678',
      label: 'My line',
      isDefault: true,
    ),
    PaymentMethod(
      id: 'm2',
      kind: 'card',
      cardBrand: 'visa',
      cardLast4: '4242',
      cardExpMonth: 8,
      cardExpYear: 2029,
      isDefault: false,
    ),
  ];

  @override
  Future<void> addMpesa({required String phone, String? label}) async =>
      added.add({'kind': 'mpesa', 'phone': phone});

  @override
  Future<void> addCard({
    required String brand,
    required String last4,
    required int expMonth,
    required int expYear,
    String? label,
  }) async => added.add({
    'kind': 'card',
    'brand': brand,
    'last4': last4,
    'month': expMonth,
    'year': expYear,
  });

  @override
  Future<BillingSettings> settings() async => const BillingSettings();

  @override
  Future<List<PaymentRecord>> history({int limit = 30}) async => [
    PaymentRecord(
      id: 'pay1',
      amount: 800,
      provider: 'mpesa',
      status: 'succeeded',
      createdAt: DateTime(2026, 9, 20, 10),
      isSimulated: true,
      consultationId: 'c1',
    ),
  ];
}

class FakeSupport extends SupportRepository {
  ({SupportKind kind, String subject, String message})? created;
  final List<String> sent = [];

  static final sample = SupportTicket(
    id: 't1',
    userId: 'p1',
    kind: SupportKind.complaint,
    subject: 'My order was late',
    status: 'answered',
    createdAt: DateTime(2026, 9, 20, 9),
    lastMessageAt: DateTime(2026, 9, 20, 11),
  );

  @override
  Future<List<SupportTicket>> myTickets() async => [sample];

  @override
  Future<List<SupportTicket>> allTickets() async => [sample];

  @override
  Future<({double average, int count})> ratingSummary() async =>
      (average: 4.5, count: 12);

  @override
  Future<SupportTicket?> ticket(String id) async => sample;

  @override
  Future<String> create({
    required SupportKind kind,
    required String subject,
    required String message,
    String? consultationId,
    String? orderId,
  }) async {
    created = (kind: kind, subject: subject, message: message);
    return 't-new';
  }

  @override
  Stream<List<SupportMessage>> watchMessages(String ticketId) => Stream.value([
    SupportMessage(
      id: 'm1',
      ticketId: 't1',
      senderId: 'p1',
      fromStaff: false,
      body: 'My order arrived two hours late.',
      createdAt: DateTime(2026, 9, 20, 9),
    ),
    SupportMessage(
      id: 'm2',
      ticketId: 't1',
      senderId: 'admin',
      fromStaff: true,
      body: 'Sorry about that. We have spoken to the chemist.',
      createdAt: DateTime(2026, 9, 20, 11),
    ),
  ]);

  @override
  Future<void> send(
    String ticketId,
    String body, {
    bool asStaff = false,
  }) async => sent.add(body);

  @override
  Future<AppRating?> myRating() async => null;
}

class FakeGeocoder extends Geocoder {
  @override
  Future<List<Place>> search(String query) async => const [
    Place(name: 'Ruiru, Kiambu, Kenya', lat: -1.1466, lng: 36.9609),
  ];

  @override
  Future<Place?> reverse(double lat, double lng) async =>
      Place(name: 'Ruiru, Kiambu, Kenya', lat: lat, lng: lng);
}
