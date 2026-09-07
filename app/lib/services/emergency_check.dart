import '../core/constants/emergency_keywords.dart';

/// Result of running the emergency keyword scan on intake text.
class EmergencyCheckResult {
  const EmergencyCheckResult({required this.flagged, this.matchedKeyword});

  final bool flagged;
  final String? matchedKeyword;
}

/// Pure function: scans free-text intake fields for red-flag keywords.
///
/// This is a **hard stop**, not a warning (per spec) -- callers must not
/// proceed to doctor matching when [EmergencyCheckResult.flagged] is true.
/// The check still runs (and its result is still recorded) even though the
/// UI blocks progress, so there's an audit trail (`intake_forms.flagged_emergency`).
EmergencyCheckResult checkForEmergency(List<String?> textFields) {
  final combined = textFields
      .where((f) => f != null && f.isNotEmpty)
      .join(' ')
      .toLowerCase();

  for (final keyword in kEmergencyKeywords) {
    if (combined.contains(keyword)) {
      return EmergencyCheckResult(flagged: true, matchedKeyword: keyword);
    }
  }
  return const EmergencyCheckResult(flagged: false);
}
