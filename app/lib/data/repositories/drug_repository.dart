import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_client.dart';
import '../models/drug.dart';
import '../models/drug_info.dart';

class DrugRepository {
  SupabaseClient get _client => SupabaseService.client;

  /// The whole medicine catalogue (a few hundred rows), for the gallery,
  /// with each medicine's latest chemist pack photo attached.
  Future<List<Drug>> fetchCatalog() async {
    final results = await Future.wait([
      _client.from('drugs').select().order('generic_name').limit(1000),
      _client.from('drug_display_photos').select(),
    ]);
    final photos = {
      for (final r in results[1])
        r['drug_id'] as String: r['image_path'] as String?,
    };
    return results[0]
        .map((r) => Drug.fromMap(r))
        .map((d) => d.withChemistPhoto(photos[d.id]))
        .toList();
  }

  /// Public URL for a chemist's pack photo.
  String? inventoryPhotoUrl(String? path) => (path == null || path.isEmpty)
      ? null
      : _client.storage.from('inventory-photos').getPublicUrl(path);

  /// Uploads a pack photo into the chemist's own folder and returns its path.
  Future<String> uploadInventoryPhoto({
    required String chemistId,
    required String drugId,
    required Uint8List bytes,
    required String fileExt,
  }) async {
    var ext = fileExt.toLowerCase().replaceAll('.', '');
    if (ext == 'jpg') ext = 'jpeg';
    final path =
        '$chemistId/${drugId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage
        .from('inventory-photos')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
        );
    return path;
  }

  Future<void> setInventoryPhoto({
    required String chemistId,
    required String drugId,
    required String imagePath,
  }) => _client
      .from('chemist_inventory')
      .update({'image_path': imagePath})
      .eq('chemist_id', chemistId)
      .eq('drug_id', drugId);

  /// Patient information for one medicine, or null if none was imported.
  Future<DrugInfo?> fetchInfo(String drugId) async {
    final row = await _client
        .from('drug_info')
        .select()
        .eq('drug_id', drugId)
        .maybeSingle();
    return row == null ? null : DrugInfo.fromMap(row);
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

  /// Stock at verified chemists for any of [drugIds] (for ordering a whole
  /// prescription from one chemist).
  Future<List<ChemistInventoryItem>> findStockForDrugs(
    List<String> drugIds,
  ) async {
    if (drugIds.isEmpty) return const [];
    final rows = await _client
        .from('chemist_inventory')
        .select(
          '*, chemist_profiles!inner(business_name, location_lat, location_lng, verified), drugs(*)',
        )
        .inFilter('drug_id', drugIds)
        .eq('chemist_profiles.verified', true)
        .gt('quantity', 0);
    return rows.map((r) => ChemistInventoryItem.fromMap(r)).toList();
  }

  /// What a pharmacy has in stock, for its public page (with its name, so
  /// "Buy" can go straight to checkout).
  Future<List<ChemistInventoryItem>> publicStock(
    String chemistId, {
    int limit = 60,
  }) async {
    final rows = await _client
        .from('chemist_inventory')
        .select('*, chemist_profiles!inner(business_name), drugs(*)')
        .eq('chemist_id', chemistId)
        .gt('quantity', 0)
        .order('last_updated_at', ascending: false)
        .limit(limit);
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
    String? imagePath,
  }) async {
    await _client.from('chemist_inventory').upsert({
      'chemist_id': chemistId,
      'drug_id': drugId,
      'quantity': quantity,
      'price': price,
      'image_path': ?imagePath,
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
