import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/patient_card.dart';
import '../../data/providers/repository_providers.dart';
import '../../data/repositories/repository_errors.dart';

/// A patient's card, for their own doctor or pharmacy.
final patientCardProvider = FutureProvider.autoDispose
    .family<PatientCard?, String>(
      (ref, id) => ref.watch(profileRepositoryProvider).patientCard(id),
    );

/// Opens the patient's card: photo, age, allergies, conditions and the
/// medicines they take. [forPharmacy] words it for dispensing.
Future<void> showPatientCard(
  BuildContext context,
  String patientId, {
  bool forPharmacy = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.white,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => _PatientCardBody(
        patientId: patientId,
        forPharmacy: forPharmacy,
        scroll: scroll,
      ),
    ),
  );
}

class _PatientCardBody extends ConsumerWidget {
  const _PatientCardBody({
    required this.patientId,
    required this.forPharmacy,
    required this.scroll,
  });

  final String patientId;
  final bool forPharmacy;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(patientCardProvider(patientId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: friendlyError(e),
        onRetry: () => ref.invalidate(patientCardProvider(patientId)),
      ),
      data: (p) => p == null
          ? const ErrorView(
              message: 'This patient\'s profile isn\'t available.',
            )
          : _card(context, p),
    );
  }

  Widget _card(BuildContext context, PatientCard p) {
    final text = Theme.of(context).textTheme;
    final allergies = PatientCard.items(p.allergies);
    final conditions = PatientCard.items(p.conditions);
    final medicines = PatientCard.items(p.medications);
    final noAllergyInfo = (p.allergies ?? '').trim().isEmpty;

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: p.hasAllergies ? AppColors.danger : AppColors.primary,
                width: 2.5,
              ),
            ),
            child: UserAvatar(
              name: p.displayName,
              path: p.avatarPath,
              radius: 46,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          p.displayName,
          textAlign: TextAlign.center,
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (p.basics.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            p.basics,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            _Fact(
              icon: LucideIcons.droplet,
              label: 'Blood group',
              value: (p.bloodGroup ?? '').trim().isEmpty ? '—' : p.bloodGroup!,
            ),
            const SizedBox(width: 10),
            _Fact(
              icon: forPharmacy
                  ? LucideIcons.shoppingBag
                  : LucideIcons.stethoscope,
              label: forPharmacy ? 'Orders with you' : 'Visits with you',
              value: '${forPharmacy ? p.ordersWithMe : p.visitsWithMe}',
            ),
            const SizedBox(width: 10),
            _Fact(
              icon: LucideIcons.calendar,
              label: 'On GoDoctor',
              value: p.memberSince == null ? '—' : '${p.memberSince!.year}',
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Allergies first and loudest: they matter most when treating or
        // dispensing.
        _Section(
          icon: LucideIcons.triangleAlert,
          title: 'Allergies',
          color: allergies.isNotEmpty
              ? AppColors.danger
              : noAllergyInfo
              ? AppColors.warning
              : AppColors.success,
          empty: noAllergyInfo
              ? 'Not recorded. Ask before ${forPharmacy ? 'dispensing' : 'prescribing'}.'
              : 'No known allergies.',
          items: allergies,
        ),
        const SizedBox(height: 10),
        _Section(
          icon: LucideIcons.heartPulse,
          title: 'Long-term conditions',
          color: AppColors.primary,
          empty: 'None recorded.',
          items: conditions,
        ),
        const SizedBox(height: 10),
        _Section(
          icon: LucideIcons.pill,
          title: 'Medicines they take',
          color: AppColors.accentTeal,
          empty: 'None recorded.',
          items: medicines,
          hint: forPharmacy
              ? 'Check for interactions with what you\'re dispensing.'
              : null,
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(LucideIcons.lock, size: 14, color: AppColors.inkFaint),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Shared with you because they\'re your patient. Their contact '
                'details and visit notes stay private.',
                style: text.bodySmall?.copyWith(color: AppColors.inkFaint),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: AppColors.primarySofter,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.color,
    required this.empty,
    required this.items,
    this.hint,
  });

  final IconData icon;
  final String title;
  final Color color;
  final String empty;
  final List<String> items;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              empty,
              style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final i in items)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      i,
                      style: text.labelLarge?.copyWith(color: AppColors.ink),
                    ),
                  ),
              ],
            ),
          if (hint != null && items.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              hint!,
              style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
          ],
        ],
      ),
    );
  }
}

/// A compact patient row for an order ticket or appointment: photo, name,
/// age, an allergy warning, and a tap to open the full card.
class PatientRow extends ConsumerWidget {
  const PatientRow({
    super.key,
    required this.patientId,
    this.forPharmacy = false,
    this.fallbackName = 'Patient',
  });

  final String patientId;
  final bool forPharmacy;
  final String fallbackName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final p = ref.watch(patientCardProvider(patientId)).valueOrNull;
    final name = p?.displayName ?? fallbackName;
    return Material(
      color: AppColors.primarySofter,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () =>
            showPatientCard(context, patientId, forPharmacy: forPharmacy),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
          child: Row(
            children: [
              UserAvatar(name: name, path: p?.avatarPath, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall,
                    ),
                    if (p != null && p.hasAllergies)
                      Text(
                        'Allergies: ${PatientCard.items(p.allergies).join(', ')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelSmall?.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else if (p != null && p.basics.isNotEmpty)
                      Text(
                        p.basics,
                        style: text.labelSmall?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                'Profile',
                style: text.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
