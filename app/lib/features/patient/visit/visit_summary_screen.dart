import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/consultation.dart';
import '../../../data/models/prescription.dart';
import '../../../data/providers/appointment_providers.dart';
import '../../../data/providers/prescription_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../chat/chats_screen.dart' show chatWindowLabel;
import '../../medications/dose_reminder_sheet.dart';
import '../screens/doctor_profile_screen.dart' show publicDoctorProvider;

/// After a consultation: what the doctor said, the medicines, the warning
/// signs and when to come back, as one card the patient can keep or share
/// (e.g. on WhatsApp with whoever looks after them).
class VisitSummaryScreen extends ConsumerStatefulWidget {
  const VisitSummaryScreen({super.key, required this.consultationId});

  final String consultationId;

  @override
  ConsumerState<VisitSummaryScreen> createState() => _VisitSummaryScreenState();
}

class _VisitSummaryScreenState extends ConsumerState<VisitSummaryScreen> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share(String fallbackText) async {
    setState(() => _sharing = true);
    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(png!.buffer.asUint8List(), mimeType: 'image/png'),
          ],
          fileNameOverrides: const ['godoctor-visit-summary.png'],
          text: 'My GoDoctor visit summary',
        ),
      );
    } catch (_) {
      // No image sharing here (e.g. a desktop browser): share the text.
      try {
        await SharePlus.instance.share(ShareParams(text: fallbackText));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
        }
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(appointmentProvider(widget.consultationId));
    final prescriptions =
        ref
            .watch(consultationPrescriptionsProvider(widget.consultationId))
            .valueOrNull ??
        const <Prescription>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Visit summary')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: friendlyError(e)),
        data: (c) {
          if (c == null) {
            return const ErrorView(message: 'Consultation not found');
          }
          final doctor = c.doctorId == null
              ? null
              : ref.watch(publicDoctorProvider(c.doctorId!)).valueOrNull;
          final doctorName = doctor?.name ?? 'Your doctor';
          final items = [for (final p in prescriptions) ...p.items];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              RepaintBoundary(
                key: _cardKey,
                child: VisitSummaryCard(
                  consultation: c,
                  doctorName: doctorName,
                  items: items,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _sharing
                    ? null
                    : () => _share(
                        visitSummaryText(
                          consultation: c,
                          doctorName: doctorName,
                          items: items,
                        ),
                      ),
                icon: const Icon(LucideIcons.share2, size: 18),
                label: Text(
                  _sharing ? 'Preparing...' : 'Share (WhatsApp, SMS...)',
                ),
              ),
              const SizedBox(height: 10),
              if (items.isNotEmpty) ...[
                OutlinedButton.icon(
                  onPressed: () => showDoseReminderSheet(context, items: items),
                  icon: const Icon(LucideIcons.alarmClock, size: 18),
                  label: const Text('Remind me to take my medicines'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => context.push(
                    '/patient/prescription/${prescriptions.last.id}/order',
                  ),
                  icon: const Icon(LucideIcons.shoppingBag, size: 18),
                  label: const Text('Order the medicines'),
                ),
                const SizedBox(height: 10),
              ],
              if (c.chatOpen)
                OutlinedButton.icon(
                  onPressed: () => context.push('/patient/chat/${c.id}'),
                  icon: const Icon(LucideIcons.messageCircle, size: 18),
                  label: Text(
                    'Message $doctorName · ${chatWindowLabel(c.chatClosesAt).toLowerCase()}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (c.followUpOn != null && c.doctorId != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => context.push('/patient/book/${c.doctorId}'),
                  icon: const Icon(LucideIcons.calendarPlus, size: 18),
                  label: const Text('Book the follow-up'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Plain text version (for sharing where images can't be).
String visitSummaryText({
  required Consultation consultation,
  required String doctorName,
  required List<PrescriptionItem> items,
}) {
  final c = consultation;
  final when = c.startedAt?.toLocal() ?? c.createdAt.toLocal();
  return [
    'GoDoctor visit summary · ${formatDate(when)}',
    '$doctorName (${c.specialtyRequested})',
    '',
    'Reason: ${c.symptomSummary}',
    if (c.summaryForPatient != null) ...['', c.summaryForPatient!],
    if (items.isNotEmpty) ...[
      '',
      'Medicines:',
      for (final i in items)
        '- ${[i.displayName, if (i.dosage?.isNotEmpty ?? false) i.dosage!].join(', ')}',
    ],
    if (c.redFlags != null) ...[
      '',
      'Get help urgently if:',
      for (final f in c.redFlags!.split('\n'))
        if (f.trim().isNotEmpty) '- ${f.trim()}',
    ],
    if (c.followUpOn != null) ...[
      '',
      'Follow-up: ${formatDate(c.followUpOn!)}',
    ],
    '',
    'Emergency? Call 999 or 1199.',
  ].join('\n');
}

/// The card itself (also what's shared as an image).
class VisitSummaryCard extends StatelessWidget {
  const VisitSummaryCard({
    super.key,
    required this.consultation,
    required this.doctorName,
    required this.items,
  });

  final Consultation consultation;
  final String doctorName;
  final List<PrescriptionItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final c = consultation;
    final when = c.startedAt?.toLocal() ?? c.createdAt.toLocal();
    final flags = (c.redFlags ?? '')
        .split('\n')
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .toList();

    Widget section(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.labelSmall?.copyWith(
              letterSpacing: 0.8,
              color: AppColors.inkSoft,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            color: AppColors.primarySofter,
            child: Row(
              children: [
                const AppLogo(height: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Visit summary',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.titleSmall,
                      ),
                      Text(
                        formatDate(when),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doctorName, style: theme.titleMedium),
                Text(c.specialtyRequested, style: theme.bodySmall),
                section(
                  'Reason for visit',
                  Text(c.symptomSummary, style: theme.bodyMedium),
                ),
                section(
                  'Doctor\'s advice',
                  Text(
                    c.summaryForPatient ??
                        'Your doctor didn\'t write a summary for this visit.',
                    style: c.summaryForPatient == null
                        ? theme.bodySmall
                        : theme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ),
                if (items.isNotEmpty)
                  section(
                    'Medicines',
                    Column(
                      children: [
                        for (final i in items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(
                                    LucideIcons.pill,
                                    size: 16,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        i.displayName,
                                        style: theme.titleSmall,
                                      ),
                                      Text(
                                        [
                                          if (i.dosage?.isNotEmpty ?? false)
                                            i.dosage!,
                                          if (i.instructions?.isNotEmpty ??
                                              false)
                                            i.instructions!,
                                          'Qty ${i.quantity}',
                                        ].join(' · '),
                                        style: theme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                if (flags.isNotEmpty)
                  section(
                    'Get help urgently if',
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.dangerSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final f in flags)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Icon(
                                      LucideIcons.triangleAlert,
                                      size: 14,
                                      color: AppColors.danger,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      f,
                                      style: theme.bodySmall?.copyWith(
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (c.followUpOn != null)
                  section(
                    'Follow-up',
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.calendarCheck,
                          size: 16,
                          color: AppColors.ink,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatDayShort(c.followUpOn!),
                          style: theme.titleSmall,
                        ),
                        Text(
                          '  ${formatCountdown(c.followUpOn!)}',
                          style: theme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 28),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.phone,
                      size: 14,
                      color: AppColors.inkSoft,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Emergency? Call 999 or 1199.',
                        style: theme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
