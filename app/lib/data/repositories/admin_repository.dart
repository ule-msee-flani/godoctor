import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_client.dart';

/// One page of a list, with the total number of matching rows.
class AdminRows {
  const AdminRows(this.rows, this.total);

  final List<Map<String, dynamic>> rows;
  final int total;

  static AdminRows from(List rows) {
    final list = rows.cast<Map<String, dynamic>>();
    final total = list.isEmpty
        ? 0
        : ((list.first['total_count'] as num?)?.toInt() ?? list.length);
    return AdminRows(list, total);
  }
}

/// Super-admin data. Every call goes through a SECURITY DEFINER function
/// that refuses non-admins (see the admin_backend migration), so nothing
/// here widens what ordinary users can read.
class AdminRepository {
  SupabaseClient get _client => SupabaseService.client;

  Future<Map<String, dynamic>> overview({int days = 30}) async =>
      (await _client.rpc('admin_overview', params: {'p_days': days}))
          as Map<String, dynamic>;

  Future<AdminRows> users({
    String? search,
    String? role,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async => AdminRows.from(
    await _client.rpc(
          'admin_users',
          params: {
            'p_search': search,
            'p_role': role,
            'p_status': status,
            'p_limit': limit,
            'p_offset': offset,
          },
        )
        as List,
  );

  Future<Map<String, dynamic>?> userDetail(String userId) async =>
      (await _client.rpc('admin_user_detail', params: {'p_user': userId}))
          as Map<String, dynamic>?;

  Future<void> setUserStatus(String userId, String status) => _client.rpc(
    'admin_set_user_status',
    params: {'p_user': userId, 'p_status': status},
  );

  Future<AdminRows> consultations({
    String? search,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async => AdminRows.from(
    await _client.rpc(
          'admin_consultations',
          params: {
            'p_search': search,
            'p_status': status,
            'p_limit': limit,
            'p_offset': offset,
          },
        )
        as List,
  );

  Future<AdminRows> orders({
    String? search,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async => AdminRows.from(
    await _client.rpc(
          'admin_orders',
          params: {
            'p_search': search,
            'p_status': status,
            'p_limit': limit,
            'p_offset': offset,
          },
        )
        as List,
  );

  Future<AdminRows> payments({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async => AdminRows.from(
    await _client.rpc(
          'admin_payments',
          params: {'p_status': status, 'p_limit': limit, 'p_offset': offset},
        )
        as List,
  );

  Future<List<Map<String, dynamic>>> sessions({int limit = 100}) async =>
      ((await _client.rpc('admin_sessions', params: {'p_limit': limit}))
              as List)
          .cast<Map<String, dynamic>>();

  Future<List<Map<String, dynamic>>> activity({
    String? table,
    String? op,
    String? actorId,
    int limit = 100,
    int? before,
  }) async =>
      ((await _client.rpc(
                'admin_activity',
                params: {
                  'p_table': table,
                  'p_op': op,
                  'p_actor': actorId,
                  'p_limit': limit,
                  'p_before': before,
                },
              ))
              as List)
          .cast<Map<String, dynamic>>();

  /// New activity as it happens (ids only; enrich with [activity]).
  Stream<List<Map<String, dynamic>>> watchActivity() => _client
      .from('audit_log')
      .stream(primaryKey: ['id'])
      .order('id', ascending: false)
      .limit(1);

  Future<Map<String, dynamic>> dbStats() async =>
      (await _client.rpc('admin_db_stats')) as Map<String, dynamic>;

  Future<Map<String, dynamic>> tableRows(
    String table, {
    int limit = 50,
    int offset = 0,
  }) async =>
      (await _client.rpc(
            'admin_table_rows',
            params: {'p_table': table, 'p_limit': limit, 'p_offset': offset},
          ))
          as Map<String, dynamic>;

  /// Returns how many people received it.
  Future<int> broadcast({
    String? role,
    required String title,
    required String body,
  }) async =>
      ((await _client.rpc(
                'admin_broadcast',
                params: {'p_role': role, 'p_title': title, 'p_body': body},
              ))
              as num)
          .toInt();

  Future<void> setOrderStatus(String orderId, String status) => _client.rpc(
    'admin_set_order_status',
    params: {'p_order': orderId, 'p_status': status},
  );

  Future<void> cancelConsultation(String id) =>
      _client.rpc('admin_cancel_consultation', params: {'p_id': id});
}
