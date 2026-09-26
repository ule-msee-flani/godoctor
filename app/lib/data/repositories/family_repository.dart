import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_client.dart';
import '../models/family.dart';

/// Family members and family sessions (family listening in on a
/// consultation). Linking and inviting go through SQL functions that check
/// who may do what; see the profile_family_billing_support migration.
class FamilyRepository {
  SupabaseClient get _client => SupabaseService.client;

  Future<List<FamilyMember>> myFamily() async {
    final rows = await _client.rpc('my_family') as List;
    return rows
        .map((r) => FamilyMember.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Invite an existing GoDoctor patient by email or phone number.
  Future<void> invite({
    required String contact,
    required String relationship,
  }) => _client.rpc(
    'invite_family_member',
    params: {'p_contact': contact, 'p_relationship': relationship},
  );

  Future<void> respond(String linkId, {required bool accept}) => _client.rpc(
    'respond_family_invite',
    params: {'p_link_id': linkId, 'p_accept': accept},
  );

  /// Unlink (either side), or cancel/decline a pending invitation.
  Future<void> remove(String linkId) =>
      _client.from('family_links').delete().eq('id', linkId);

  // --- Family sessions ---

  Future<void> inviteToConsultation(String consultationId, String memberId) =>
      _client.rpc(
        'invite_to_consultation',
        params: {'p_consultation_id': consultationId, 'p_member_id': memberId},
      );

  Future<void> removeFromConsultation(String consultationId, String userId) =>
      _client.rpc(
        'remove_consultation_participant',
        params: {'p_consultation_id': consultationId, 'p_user_id': userId},
      );

  /// Join (true) or decline/leave (false) a consultation I was invited to.
  Future<void> respondToSession(String consultationId, {required bool join}) =>
      _client.rpc(
        'respond_consultation_invite',
        params: {'p_consultation_id': consultationId, 'p_join': join},
      );

  Future<List<SessionPerson>> people(String consultationId) async {
    final rows =
        await _client.rpc(
              'consultation_people',
              params: {'p_consultation_id': consultationId},
            )
            as List;
    return rows
        .map((r) => SessionPerson.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Everyone in a consultation, refreshed whenever a family member is
  /// invited, joins or leaves.
  Stream<List<SessionPerson>> watchPeople(String consultationId) => _client
      .from('consultation_participants')
      .stream(primaryKey: ['id'])
      .eq('consultation_id', consultationId)
      .asyncMap((_) => people(consultationId));

  Future<FamilySessionInfo?> sessionInfo(String consultationId) async {
    final rows =
        await _client.rpc(
              'family_session_info',
              params: {'p_consultation_id': consultationId},
            )
            as List;
    return rows.isEmpty
        ? null
        : FamilySessionInfo.fromMap(rows.first as Map<String, dynamic>);
  }

  /// Consultations I've been invited to listen in on and haven't answered.
  Stream<List<String>> watchMyInvites(String userId) => _client
      .from('consultation_participants')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .map(
        (rows) => [
          for (final r in rows)
            if (r['status'] == 'invited' || r['status'] == 'joined')
              r['consultation_id'] as String,
        ],
      );
}
