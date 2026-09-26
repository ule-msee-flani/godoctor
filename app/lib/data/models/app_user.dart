import 'enums.dart';

class AppUser {
  const AppUser({
    required this.id,
    this.phone,
    this.email,
    required this.role,
    required this.status,
    required this.createdAt,
    this.avatarUrl,
    this.contactPhone,
  });

  final String id;
  final String? phone;
  final String? email;
  final UserRole role;
  final UserStatus status;
  final DateTime createdAt;

  /// Profile photo: path in the public `avatars` bucket.
  final String? avatarUrl;

  /// A number people can reach them on (separate from the login phone).
  final String? contactPhone;

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
    id: map['id'] as String,
    phone: map['phone'] as String?,
    email: map['email'] as String?,
    role: enumFromDb(UserRole.values, map['role'] as String?, UserRole.patient),
    status: enumFromDb(
      UserStatus.values,
      map['status'] as String?,
      UserStatus.active,
    ),
    createdAt: DateTime.parse(map['created_at'] as String),
    avatarUrl: map['avatar_url'] as String?,
    contactPhone: map['contact_phone'] as String?,
  );
}
