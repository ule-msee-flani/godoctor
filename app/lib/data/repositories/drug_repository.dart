import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_client.dart';
import '../models/drug.dart';

class DrugRepository {
  SupabaseClient get _client => SupabaseService.client;

  /// The whole medicine catalogue (a few hundred rows), for the gallery.
  Future<List<Drug>> fetchCatalog() async {
    final rows = await _client
        .from('drugs')
        .select()
        .order('generic_name')
        .limit(1000);
    return rows.map((r) => Drug.fromMap(r)).toList();
  }

  /// Public URL for a product photo stored in the `drug-images` bucket.
  String? imageUrl(String? path) => (path == null || path.isEmpty)
      ? null
      : _client.storage.from('drug-images').getPublicUrl(path);

  Future<List<Drug>> searchDrugs(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) {
      final rows = await _client
          .from('drugs')
          .select()
          .order('generic_name')
          .limit(limit);
      return rows.map((r) => Drug.fromMap(r)).toList();
    }
    final rows = await _client
        .from('drugs')
        .select()
        .ilike('generic_name', '%$query%')
        .order('generic_name')
        .limit(limit);
    return rows.map((r) => Drug.fromMap(r)).toList();
  }

  /// Nearby chemists with confirmed stock (`quantity > 0`) of a given drug.
  /// Distance sort happens client-side (see services/distance.dart) since
  /// the patient's own lat/lng is needed and the result set is small.
  Future<List<ChemistInventoryItem>> findStockForDrug(String drugId) async {
    final rows = await _client
        .from('chemist_inventory')
        .select(
          '*, chemist_profiles!inner(business_name, location_lat, location_lng, verified), drugs(*)',
        )
        .eq('drug_id', drugId)
        .eq('chemist_profiles.verified', true)
        .gt('quantity', 0);
    return rows.map((r) => ChemistInventoryItem.fromMap(r)).toList();
  }

  // --- Chemist inventory management ---

  Future<List<ChemistInventoryItem>> fetchChemistInventory(
    String chemistId,
  ) async {
    final rows = await _client
        .from('chemist_inventory')
        .select('*, drugs(*)')
        .eq('chemist_id', chemistId)
        .order('last_updated_at', ascending: false);
    return rows.map((r) => ChemistInventoryItem.fromMap(r)).toList();
  }

  Future<void> upsertInventory({
    required String chemistId,
    required String drugId,
    required int quantity,
    required double price,
  }) async {
    await _client.from('chemist_inventory').upsert({
      'chemist_id': chemistId,
      'drug_id': drugId,
      'quantity': quantity,
      'price': price,
    });
  }

  Future<void> removeInventory({
    required String chemistId,
    required String drugId,
  }) async {
    await _client
        .from('chemist_inventory')
        .delete()
        .eq('chemist_id', chemistId)
        .eq('drug_id', drugId);
  }
}
