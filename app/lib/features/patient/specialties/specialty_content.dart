/// Everything shown on one specialty page.
///
/// Each specialty's text lives in its own file under `content/`, so any one
/// of them can be rewritten (or given a completely custom screen -- see
/// `specialty_registry.dart`) without touching the others.
///
/// IMPORTANT: this is patient-facing health information. The drafts that ship
/// with the app are general and deliberately cautious; have a clinician
/// review and sign off each page before launch.
class SpecialtyContent {
  const SpecialtyContent({
    required this.slug,
    required this.name,
    required this.title,
    required this.tagline,
    required this.about,
    required this.commonReasons,
    required this.onlineHelp,
    required this.urgentSigns,
    required this.findDoctorsLabel,
  });

  /// URL/file slug -- must match a SpecialtyMeta.slug in specialty_tiles.dart.
  final String slug;

  /// Canonical specialty name stored in the database (matches kSpecialties);
  /// used to filter the doctor directory.
  final String name;

  /// Page heading, e.g. "Ear, Nose & Throat (ENT)".
  final String title;
  final String tagline;

  /// "What is this specialty?" -- one paragraph per entry.
  final List<String> about;

  /// "Common reasons to see a ..." -- short bullet points.
  final List<String> commonReasons;

  /// "What a video consultation can help with".
  final List<String> onlineHelp;

  /// "Get urgent help if..." -- signs that need emergency care instead.
  final List<String> urgentSigns;

  /// Label of the main button, e.g. "Find ENT doctors".
  final String findDoctorsLabel;
}
