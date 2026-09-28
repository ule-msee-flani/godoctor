import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';
import '../../core/config/supabase_client.dart';

/// A catalogue medicine a pharmacy's own name was matched to.
typedef DrugMatch = ({String id, String name});

/// A key a pharmacy's own system uses to send stock to GoDoctor. Only the
/// first characters are kept for display; the key itself is shown once.
class ApiKeyInfo {
  const ApiKeyInfo({
    required this.id,
    required this.label,
    required this.prefix,
    required this.createdAt,
    this.lastUsedAt,
    this.revokedAt,
  });

  final String id;
  final String label;
  final String prefix;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final DateTime? revokedAt;

  bool get active => revokedAt == null;

  factory ApiKeyInfo.fromMap(Map<String, dynamic> m) => ApiKeyInfo(
    id: m['id'] as String,
    label: (m['label'] as String?) ?? 'Pharmacy system',
    prefix: (m['key_prefix'] as String?) ?? 'gdk_',
    createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
    lastUsedAt: m['last_used_at'] == null
        ? null
        : DateTime.parse(m['last_used_at'] as String).toLocal(),
    revokedAt: m['revoked_at'] == null
        ? null
        : DateTime.parse(m['revoked_at'] as String).toLocal(),
  );
}

/// Bringing a pharmacy's existing stock into GoDoctor: a file import from
/// the app, or their own system pushing updates with an API key.
class StockSyncRepository {
  SupabaseClient get _client => SupabaseService.client;

  /// Matches the pharmacy's own names ("Panadol 500mg", "amoxil") to the
  /// catalogue. Names with no match map to null.
  Future<Map<String, DrugMatch?>> matchNames(List<String> names) async {
    final unique = names.toSet().toList();
    final out = <String, DrugMatch?>{};
    for (var i = 0; i < unique.length; i += 400) {
      final chunk = unique.sublist(
        i,
        i + 400 > unique.length ? unique.length : i + 400,
      );
      final rows =
          await _client.rpc('match_drugs', params: {'p_names': chunk}) as List;
      for (final r in rows.cast<Map<String, dynamic>>()) {
        final id = r['drug_id'] as String?;
        out[r['name'] as String] = id == null
            ? null
            : (
                id: id,
                name: (r['drug_name'] as String?) ?? r['name'] as String,
              );
      }
    }
    return out;
  }

  /// Saves (adds or updates) the pharmacy's stock. Returns how many
  /// medicines were saved.
  Future<int> importStock(
    List<({String drugId, int quantity, double price})> rows,
  ) async {
    final res = await _client.rpc(
      'import_inventory',
      params: {
        'p_rows': [
          for (final r in rows)
            {'drug_id': r.drugId, 'quantity': r.quantity, 'price': r.price},
        ],
      },
    );
    return ((res as Map)['saved'] as num?)?.toInt() ?? 0;
  }

  Future<List<ApiKeyInfo>> apiKeys() async {
    final rows = await _client
        .from('chemist_api_keys')
        .select()
        .order('created_at', ascending: false);
    return rows.map(ApiKeyInfo.fromMap).toList();
  }

  /// A new key, returned in full this once.
  Future<String> createApiKey(String label) async =>
      await _client.rpc('create_chemist_api_key', params: {'p_label': label})
          as String;

  Future<void> revokeApiKey(String id) =>
      _client.rpc('revoke_chemist_api_key', params: {'p_id': id});

  /// Where a pharmacy system sends its stock.
  String get syncUrl => '${Env.supabaseUrl}/functions/v1/inventory-sync';
}
