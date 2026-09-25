import 'package:flutter/material.dart';

import 'consultation_history_screen.dart';
import 'order_history_screen.dart';
import 'prescriptions_screen.dart';

/// The patient's activity hub: everything they've done, in one place,
/// replacing the three history buttons that used to crowd the home screen.
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Activity'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Consultations'),
              Tab(text: 'Orders'),
              Tab(text: 'Prescriptions'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ConsultationHistoryList(),
            OrderHistoryList(),
            PrescriptionsList(),
          ],
        ),
      ),
    );
  }
}
