import 'package:flutter/widgets.dart';

import 'content/bones_content.dart';
import 'content/children_content.dart';
import 'content/ent_content.dart';
import 'content/general_content.dart';
import 'content/heart_content.dart';
import 'content/internal_content.dart';
import 'content/mental_health_content.dart';
import 'content/obgyn_content.dart';
import 'content/skin_content.dart';
import 'specialty_content.dart';
import 'specialty_page.dart';

const kSpecialtyContents = <SpecialtyContent>[
  generalContent,
  childrenContent,
  obgynContent,
  internalContent,
  skinContent,
  mentalHealthContent,
  heartContent,
  entContent,
  bonesContent,
];

SpecialtyContent? specialtyContentForSlug(String slug) {
  for (final c in kSpecialtyContents) {
    if (c.slug == slug) return c;
  }
  return null;
}

/// Give one specialty a completely custom screen by adding an entry here,
/// keyed by its slug, e.g.
///
///     'ent': (context) => const MyCustomEntPage(),
///
/// Any specialty not listed uses the shared [SpecialtyPage] layout driven by
/// its content file.
final Map<String, WidgetBuilder> specialtyPageOverrides = {};

/// Builds the page for [slug], or null if it isn't a known specialty.
Widget? buildSpecialtyPage(BuildContext context, String slug) {
  final override = specialtyPageOverrides[slug];
  if (override != null) return override(context);
  final content = specialtyContentForSlug(slug);
  return content == null ? null : SpecialtyPage(content: content);
}
