import 'package:flutter/material.dart';

import '../visits/visit_widgets.dart';

/// Every visit with a doctor, grouped by month (also the Health tab's
/// "Visits" section).
class ConsultationHistoryScreen extends StatelessWidget {
  const ConsultationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your visits')),
    body: const VisitsList(),
  );
}
