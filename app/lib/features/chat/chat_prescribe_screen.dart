import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/prescription.dart';
import '../../data/providers/auth_providers.dart';
import '../doctor/widgets/prescribing.dart';
import 'chat_providers.dart';

/// Doctor, from the 24-hour chat: send a new or changed prescription (e.g.
/// the chemist doesn't stock the first medicine). Same gallery and dose
/// sheet as during the call.
class ChatPrescribeScreen extends ConsumerStatefulWidget {
  const ChatPrescribeScreen({super.key, required this.consultationId});

  final String consultationId;

  @override
  ConsumerState<ChatPrescribeScreen> createState() =>
      _ChatPrescribeScreenState();
}

class _ChatPrescribeScreenState extends ConsumerState<ChatPrescribeScreen>
    with
        SingleTickerProviderStateMixin,
        PrescriptionDrafting<ChatPrescribeScreen> {
  final _searchCtrl = TextEditingController();
  late final _tabs = TabController(length: 2, vsync: this);

  @override
  String get draftConsultationId => widget.consultationId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabs.dispose();
    super.dispose();
  }

  @override
  void onDraftChanged(PrescriptionItem item, {required bool updated}) {
    toast(
      updated
          ? 'Updated ${item.displayName}'
          : 'Added ${item.displayName} to the prescription',
      action: _tabs.index == 1
          ? null
          : SnackBarAction(label: 'View', onPressed: () => _tabs.animateTo(1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final thread = ref
        .watch(myChatsProvider)
        .valueOrNull
        ?.where((t) => t.consultationId == widget.consultationId)
        .firstOrNull;
    final doctor = ref.watch(currentDoctorProfileProvider).valueOrNull;
    final patientName = thread?.otherName ?? 'the patient';
    final doctorName = (doctor?.name.isNotEmpty ?? false)
        ? (doctor!.name.startsWith('Dr') ? doctor.name : 'Dr ${doctor.name}')
        : 'Your doctor';

    return Scaffold(
      appBar: AppBar(
        title: const Text('New prescription'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            const Tab(text: 'Medicines'),
            Tab(
              text: draft.isEmpty
                  ? 'Prescription'
                  : 'Prescription (${draft.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          PrescribeMedicinesPanel(
            searchCtrl: _searchCtrl,
            onSearch: (_) => setState(() {}),
            draft: draft,
            onPrescribe: (drug, {template}) =>
                prescribe(drug, template: template),
          ),
          PrescriptionDraftPanel(
            consultationId: widget.consultationId,
            doctorName: doctorName,
            doctorDetail: doctor?.specialties.firstOrNull,
            patientName: patientName,
            draft: draft,
            sending: sending,
            onEdit: (i) => prescribe(null, editIndex: i),
            onRemove: (i) => setState(() => draft.removeAt(i)),
            onSend: () async {
              final ok = await sendDraft(patientName);
              if (ok && context.mounted) context.pop();
            },
            onBrowse: () => _tabs.animateTo(0),
          ),
        ],
      ),
    );
  }
}
