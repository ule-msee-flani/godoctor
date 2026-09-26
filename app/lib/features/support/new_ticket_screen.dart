import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../data/models/consultation.dart';
import '../../data/models/enums.dart';
import '../../data/models/order.dart' as model;
import '../../data/models/support.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/repository_providers.dart';
import '../../data/repositories/repository_errors.dart';
import 'support_screen.dart' show myTicketsProvider;

/// A patient's recent consultations and orders, to attach to a complaint.
final _recentProvider =
    FutureProvider.autoDispose<
      ({List<Consultation> consultations, List<model.Order> orders})
    >((ref) async {
      final user = await ref.watch(currentAppUserProvider.future);
      if (user == null || user.role != UserRole.patient) {
        return (consultations: <Consultation>[], orders: <model.Order>[]);
      }
      final results = await Future.wait([
        ref
            .watch(consultationRepositoryProvider)
            .fetchHistoryForPatient(user.id),
        ref.watch(orderRepositoryProvider).fetchForPatient(user.id),
      ]);
      return (
        consultations: (results[0] as List<Consultation>).take(10).toList(),
        orders: (results[1] as List<model.Order>).take(10).toList(),
      );
    });

/// Start a support conversation, feedback or complaint.
class NewTicketScreen extends ConsumerStatefulWidget {
  const NewTicketScreen({super.key, this.kind = SupportKind.support});

  final SupportKind kind;

  @override
  ConsumerState<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends ConsumerState<NewTicketScreen> {
  late SupportKind _kind = widget.kind;
  final _subject = TextEditingController();
  final _message = TextEditingController();

  /// "c:ID" for a consultation, "o:ID" for an order.
  String? _related;
  bool _sending = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  String get _title => switch (_kind) {
    SupportKind.complaint => 'Report a complaint',
    SupportKind.feedback => 'Give feedback',
    _ => 'Get help',
  };

  Future<void> _send() async {
    final message = _message.text.trim();
    if (message.isEmpty) return;
    final subject = _subject.text.trim().isNotEmpty
        ? _subject.text.trim()
        : (message.length > 60 ? '${message.substring(0, 60)}…' : message);
    setState(() => _sending = true);
    try {
      final id = await ref
          .read(supportRepositoryProvider)
          .create(
            kind: _kind,
            subject: subject,
            message: message,
            consultationId: _related?.startsWith('c:') == true
                ? _related!.substring(2)
                : null,
            orderId: _related?.startsWith('o:') == true
                ? _related!.substring(2)
                : null,
          );
      ref.invalidate(myTicketsProvider);
      if (!mounted) return;
      if (_kind == SupportKind.feedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you! Your feedback was sent.')),
        );
        context.pop();
      } else {
        context.pushReplacement('/account/support/$id');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final recent = _kind == SupportKind.complaint
        ? ref.watch(_recentProvider).valueOrNull
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SegmentedButton<SupportKind>(
            segments: const [
              ButtonSegment(value: SupportKind.support, label: Text('Help')),
              ButtonSegment(
                value: SupportKind.complaint,
                label: Text('Complaint'),
              ),
              ButtonSegment(
                value: SupportKind.feedback,
                label: Text('Feedback'),
              ),
            ],
            selected: {
              _kind == SupportKind.accountDeletion
                  ? SupportKind.support
                  : _kind,
            },
            onSelectionChanged: (s) => setState(() {
              _kind = s.first;
              _related = null;
            }),
          ),
          const SizedBox(height: 18),
          if (_kind == SupportKind.complaint &&
              recent != null &&
              (recent.consultations.isNotEmpty ||
                  recent.orders.isNotEmpty)) ...[
            DropdownButtonFormField<String?>(
              initialValue: _related,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'What is it about?'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Something else'),
                ),
                for (final c in recent.consultations)
                  DropdownMenuItem(
                    value: 'c:${c.id}',
                    child: Text(
                      'Consultation · ${c.specialtyRequested} · ${formatDayShort(c.createdAt.toLocal())}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                for (final o in recent.orders)
                  DropdownMenuItem(
                    value: 'o:${o.id}',
                    child: Text(
                      'Order · ${o.chemistName ?? 'Chemist'} · ${formatDayShort(o.createdAt.toLocal())}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _related = v),
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _subject,
            maxLength: 120,
            decoration: InputDecoration(
              labelText: 'Subject (optional)',
              hintText: switch (_kind) {
                SupportKind.complaint => 'e.g. My order arrived late',
                SupportKind.feedback => 'e.g. Add Swahili',
                _ => 'e.g. I can\'t pay with M-Pesa',
              },
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _message,
            minLines: 5,
            maxLines: 10,
            maxLength: 4000,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: _kind == SupportKind.feedback
                  ? 'Your feedback'
                  : 'Tell us what happened',
              alignLabelWithHint: true,
            ),
          ),
          if (_kind == SupportKind.complaint)
            Text(
              'Complaints go to our team for review. We reply here, usually within a day.',
              style: theme.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _message.text.trim().isEmpty || _sending ? null : _send,
            child: Text(_sending ? 'Sending…' : 'Send'),
          ),
        ],
      ),
    );
  }
}
