/// Patient-facing information about a medicine (table `drug_info`), imported
/// from free public sources by tool/import_drug_info.js. Every field is
/// optional: not every medicine has a public label, and not every label has
/// every section.
class DrugInfo {
  const DrugInfo({
    required this.drugId,
    this.matchedName,
    this.uses,
    this.warnings,
    this.sideEffects,
    this.interactions,
    required this.source,
    this.sourceUrl,
  });

  final String drugId;

  /// The standard name it was matched to (e.g. "acetaminophen" for
  /// paracetamol), shown so the US label text makes sense.
  final String? matchedName;
  final String? uses;
  final String? warnings;
  final String? sideEffects;
  final String? interactions;
  final String source;
  final String? sourceUrl;

  bool get isEmpty =>
      uses == null &&
      warnings == null &&
      sideEffects == null &&
      interactions == null;

  factory DrugInfo.fromMap(Map<String, dynamic> map) => DrugInfo(
    drugId: map['drug_id'] as String,
    matchedName: map['matched_name'] as String?,
    uses: map['uses'] as String?,
    warnings: map['warnings'] as String?,
    sideEffects: map['side_effects'] as String?,
    interactions: map['interactions'] as String?,
    source: (map['source'] as String?) ?? 'openFDA',
    sourceUrl: map['source_url'] as String?,
  );
}
