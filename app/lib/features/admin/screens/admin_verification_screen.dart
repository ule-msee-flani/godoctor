import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/chemist_profile.dart';
import '../../../data/models/doctor_profile.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../widgets/admin_ui.dart';

final _pendingDoctorsProvider = FutureProvider.autoDispose<List<DoctorProfile>>(
  (ref) => ref.watch(profileRepositoryProvider).fetchPendingDoctors(),
);
final _pendingChemistsProvider =
    FutureProvider.autoDispose<List<ChemistProfile>>(
      (ref) => ref.watch(profileRepositoryProvider).fetchPendingChemists(),
    );

/// Manual doctor/chemist verification. Per spec, a human checks the public
/// KMPDC (doctors) or PPB (pharmacies) register -- this is the approve
/// queue on top of that check.
class AdminVerificationScreen extends ConsumerWidget {
  const AdminVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctors = ref.watch(_pendingDoctorsProvider);
    final chemists = ref.watch(_pendingChemistsProvider);

    Future<void> approve(Future<void> Function() call, String name) async {
      try {
        await call();
        ref.invalidate(_pendingDoctorsProvider);
        ref.invalidate(_pendingChemistsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$name verified')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
        }
      }
    }

    final repo = ref.read(profileRepositoryProvider);
    return AdminPage(
      title: 'Verification',
      subtitle:
          'Check each licence on the official register, then approve. Unverified accounts cannot practise or sell.',
      onRefresh: () async {
        ref.invalidate(_pendingDoctorsProvider);
        ref.invalidate(_pendingChemistsProvider);
      },
      children: [
        _Queue(
          title: 'Doctors',
          register: 'Check on the KMPDC register',
          async: doctors,
          empty: 'No doctors waiting.',
          itemsOf: (List<DoctorProfile> list) => [
            for (final d in list)
              _Applicant(
                userId: d.userId,
                name: d.name.isEmpty ? 'Unnamed doctor' : d.name,
                icon: LucideIcons.stethoscope,
                submitted: (d.licenseNumber ?? '').isNotEmpty,
                facts: [
                  'Licence ${d.licenseNumber ?? 'not given'}',
                  if (d.specialties.isNotEmpty) d.specialties.join(', '),
                  if (d.licenseExpiry != null)
                    'expires ${stamp(d.licenseExpiry).split(',').first}',
                  '${d.verificationDocuments.length} document(s)',
                ],
                onApprove: () => approve(
                  () => repo.adminSetDoctorVerified(d.userId, true),
                  d.name,
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        _Queue(
          title: 'Chemists',
          register: 'Check on the PPB premises register',
          async: chemists,
          empty: 'No chemists waiting.',
          itemsOf: (List<ChemistProfile> list) => [
            for (final c in list)
              _Applicant(
                userId: c.userId,
                name: c.businessName.isEmpty
                    ? 'Unnamed pharmacy'
                    : c.businessName,
                icon: LucideIcons.store,
                submitted: (c.registrationNumber ?? '').isNotEmpty,
                facts: [
                  'Registration ${c.registrationNumber ?? 'not given'}',
                  if (c.locationName != null) c.locationName!,
                  '${c.verificationDocuments.length} document(s)',
                ],
                onApprove: () => approve(
                  () => repo.adminSetChemistVerified(c.userId, true),
                  c.businessName,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Queue<T> extends StatelessWidget {
  const _Queue({
    required this.title,
    required this.register,
    required this.async,
    required this.empty,
    required this.itemsOf,
  });

  final String title;
  final String register;
  final AsyncValue<List<T>> async;
  final String empty;
  final List<_Applicant> Function(List<T>) itemsOf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return AdminCard(
      title: title,
      subtitle: register,
      trailing: async.valueOrNull == null
          ? null
          : StatusChip(
              '${async.valueOrNull!.length} waiting',
              tone: async.valueOrNull!.isEmpty ? Tone.good : Tone.warning,
            ),
      child: async.when(
        loading: () => const SizedBox(height: 80, child: LoadingView()),
        error: (e, _) => Text(friendlyError(e)),
        data: (list) {
          final items = itemsOf(list)
            ..sort((a, b) => (b.submitted ? 1 : 0) - (a.submitted ? 1 : 0));
          if (items.isEmpty) return Text(empty, style: theme.bodyMedium);
          return Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                items[i],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Applicant extends StatelessWidget {
  const _Applicant({
    required this.userId,
    required this.name,
    required this.icon,
    required this.submitted,
    required this.facts,
    required this.onApprove,
  });

  final String userId;
  final String name;
  final IconData icon;
  final bool submitted;
  final List<String> facts;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.titleSmall),
                    const SizedBox(height: 2),
                    submitted
                        ? const StatusChip('Submitted', tone: Tone.warning)
                        : const StatusChip('Not submitted yet'),
                    const SizedBox(height: 4),
                    Text(facts.join(' · '), style: theme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => context.go('/admin/users/$userId'),
                child: const Text('Open profile'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: submitted ? onApprove : null,
                child: const Text('Approve'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
