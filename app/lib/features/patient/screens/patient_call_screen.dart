import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/video_call_panel.dart';

class PatientCallScreen extends ConsumerWidget {
  const PatientCallScreen({super.key, required this.consultationId});

  final String consultationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consultation in progress')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              VideoCallPanel(
                otherPartyName: 'your doctor',
                onEndCall: () => context.pop(),
              ),
              const SizedBox(height: 16),
              const Expanded(
                child: EmptyView(
                  message:
                      'Your doctor will share notes and any prescription here once the consultation ends.',
                  icon: Icons.chat_bubble_outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
