import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/drug.dart';
import '../../data/models/prescription.dart';
import '../../data/providers/repository_providers.dart';
import '../../services/distance.dart';

/// One prescribed medicine that a chemist has in stock.
class MatchedLine {
  const MatchedLine({required this.item, required this.stock});

  final PrescriptionItem item;
  final ChemistInventoryItem stock;

  /// What the patient would buy: the prescribed quantity, capped at stock.
  int get quantity => item.quantity.clamp(1, stock.quantity);
  double get subtotal => quantity * stock.price;
}

/// How well one chemist can fill a prescription.
class ChemistMatch {
  const ChemistMatch({
    required this.chemistId,
    required this.chemistName,
    required this.lines,
    required this.wanted,
    this.km,
  });

  final String chemistId;
  final String chemistName;
  final List<MatchedLine> lines;

  /// Prescribed medicines that can be matched to stock at all (catalogue
  /// items); free-text items are left for the chemist to read.
  final int wanted;
  final double? km;

  bool get hasEverything => lines.length == wanted;
  double get total => lines.fold(0, (sum, l) => sum + l.subtotal);
}

/// Ranks chemists for [prescription]: the most prescribed medicines in stock
/// first, then nearest (when both locations are known), then cheapest.
List<ChemistMatch> rankChemists(
  Prescription prescription,
  List<ChemistInventoryItem> stock, {
  double? patientLat,
  double? patientLng,
}) {
  final structured = prescription.items.where((i) => i.isStructured).toList();
  if (structured.isEmpty) return const [];

  final byChemist = <String, List<ChemistInventoryItem>>{};
  for (final s in stock) {
    if (s.quantity <= 0) continue;
    byChemist.putIfAbsent(s.chemistId, () => []).add(s);
  }

  final matches = <ChemistMatch>[];
  for (final entry in byChemist.entries) {
    final lines = <MatchedLine>[];
    for (final item in structured) {
      final s = entry.value.where((s) => s.drugId == item.drugId).firstOrNull;
      if (s != null) lines.add(MatchedLine(item: item, stock: s));
    }
    if (lines.isEmpty) continue;

    final first = entry.value.first;
    double? km;
    if (patientLat != null &&
        patientLng != null &&
        first.chemistLat != null &&
        first.chemistLng != null) {
      km = distanceKm(
        patientLat,
        patientLng,
        first.chemistLat!,
        first.chemistLng!,
      );
    }
    matches.add(
      ChemistMatch(
        chemistId: entry.key,
        chemistName: first.chemistName ?? 'Chemist',
        lines: lines,
        wanted: structured.length,
        km: km,
      ),
    );
  }

  matches.sort((a, b) {
    final coverage = b.lines.length.compareTo(a.lines.length);
    if (coverage != 0) return coverage;
    if (a.km != null && b.km != null) {
      final d = a.km!.compareTo(b.km!);
      if (d != 0) return d;
    } else if (a.km != null) {
      return -1;
    } else if (b.km != null) {
      return 1;
    }
    return a.total.compareTo(b.total);
  });
  return matches;
}

/// Stock at verified chemists for the catalogue medicines on a prescription.
/// Keyed by the sorted, comma-joined drug ids so equal prescriptions share it.
final prescriptionStockProvider = FutureProvider.autoDispose
    .family<List<ChemistInventoryItem>, String>(
      (ref, drugIdsKey) => ref
          .watch(drugRepositoryProvider)
          .findStockForDrugs(
            drugIdsKey.isEmpty ? const [] : drugIdsKey.split(','),
          ),
    );

/// The key for [prescriptionStockProvider].
String stockKeyFor(Prescription p) {
  final ids = {
    for (final i in p.items)
      if (i.drugId != null) i.drugId!,
  }.toList()..sort();
  return ids.join(',');
}
