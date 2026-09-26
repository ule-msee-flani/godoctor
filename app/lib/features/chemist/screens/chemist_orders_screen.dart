import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/order.dart' as model;
import '../../../data/models/prescription.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/notification_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../patient/screens/doctor_profile_screen.dart'
    show publicDoctorProvider;
import '../../patient/widgets/medicine_image.dart';
import '../../prescription/digital_prescription.dart';

/// Live orders for the signed-in chemist (newest first).
final chemistOrdersProvider = StreamProvider.autoDispose<List<model.Order>>((
  ref,
) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(orderRepositoryProvider).watchForChemist(userId);
});

/// Orders waiting for the chemist to act on (shown as a badge on the tab).
final chemistNewOrderCountProvider = Provider.autoDispose<int>(
  (ref) =>
      ref
          .watch(chemistOrdersProvider)
          .valueOrNull
          ?.where((o) => o.status == OrderStatus.placed)
          .length ??
      0,
);

final _prescriptionProvider = FutureProvider.autoDispose
    .family<Prescription?, String>(
      (ref, id) => ref.watch(prescriptionRepositoryProvider).fetchById(id),
    );

class ChemistOrdersScreen extends ConsumerWidget {
  const ChemistOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(chemistOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          Badge(
            isLabelVisible: ref.watch(unreadNotificationCountProvider) > 0,
            label: Text('${ref.watch(unreadNotificationCountProvider)}'),
            offset: const Offset(-4, 4),
            child: IconButton(
              tooltip: 'Notifications',
              icon: const Icon(LucideIcons.bell),
              onPressed: () => context.push('/chemist/notifications'),
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(LucideIcons.logOut),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: friendlyError(e)),
        data: (orders) {
          if (orders.isEmpty) {
            return const EmptyView(
              message:
                  'No orders yet.\nWhen a patient orders from you, it appears here straight away.',
              icon: LucideIcons.receipt,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, i) => _OrderCard(order: orders[i]),
          );
        },
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});

  final model.Order order;

  (String, Color, Color) get _status => switch (order.status) {
    OrderStatus.placed => ('New', AppColors.primary, AppColors.primarySoft),
    OrderStatus.confirmed => (
      'Preparing',
      AppColors.warning,
      AppColors.warningSoft,
    ),
    OrderStatus.ready => ('Ready', AppColors.success, AppColors.successSoft),
    OrderStatus.fulfilled => ('Collected', AppColors.inkSoft, AppColors.border),
    OrderStatus.disputed => (
      'Disputed',
      AppColors.danger,
      AppColors.dangerSoft,
    ),
    OrderStatus.refunded => ('Refunded', AppColors.inkSoft, AppColors.border),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final repo = ref.read(orderRepositoryProvider);
    final (label, fg, bg) = _status;
    final code = order.id.length > 8 ? order.id.substring(0, 8) : order.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order ${code.toUpperCase()}',
                        style: theme.titleMedium,
                      ),
                      Text(
                        '${formatDateTime(order.createdAt.toLocal())} · '
                        '${order.fulfillmentType == FulfillmentType.delivery ? 'Delivery' : 'Pickup'}',
                        style: theme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final i in order.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    if (i.drug != null)
                      MedicineImage(drug: i.drug!, size: 40, radius: 10)
                    else
                      const Icon(LucideIcons.pill, color: AppColors.inkFaint),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${i.drugName ?? 'Item'} × ${i.quantity}',
                        style: theme.bodyMedium,
                      ),
                    ),
                    Text(
                      formatKes(i.unitPrice * i.quantity),
                      style: theme.bodyMedium,
                    ),
                  ],
                ),
              ),
            const Divider(height: 16),
            Row(
              children: [
                Expanded(child: Text('Total paid', style: theme.bodyMedium)),
                Text(formatKes(order.totalAmount), style: theme.titleSmall),
              ],
            ),
            if (order.prescriptionId != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.fileText,
                      size: 16,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Prescription attached. Check it before preparing.',
                        style: theme.bodySmall?.copyWith(color: AppColors.ink),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          _showPrescription(context, order.prescriptionId!),
                      child: const Text('View'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (order.status == OrderStatus.placed)
                  FilledButton.icon(
                    onPressed: () => repo.chemistConfirm(order.id),
                    icon: const Icon(LucideIcons.check, size: 16),
                    label: const Text('Accept and prepare'),
                  ),
                if (order.status == OrderStatus.confirmed)
                  FilledButton.icon(
                    onPressed: () => repo.chemistMarkReady(order.id),
                    icon: const Icon(LucideIcons.packageCheck, size: 16),
                    label: const Text('Mark ready'),
                  ),
                if (order.status == OrderStatus.ready)
                  Text(
                    'Waiting for the patient to confirm they received it.',
                    style: theme.bodySmall,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showPrescription(BuildContext context, String prescriptionId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _PrescriptionSheet(prescriptionId: prescriptionId),
  );
}

class _PrescriptionSheet extends ConsumerWidget {
  const _PrescriptionSheet({required this.prescriptionId});

  final String prescriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_prescriptionProvider(prescriptionId));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: async.when(
        loading: () => const SizedBox(height: 200, child: LoadingView()),
        error: (e, _) => ErrorView(message: friendlyError(e)),
        data: (p) {
          if (p == null) {
            return const ErrorView(message: 'Prescription not found');
          }
          if (p.source == PrescriptionSource.externalUpload) {
            final url = p.imageUrl == null
                ? null
                : ref
                      .read(prescriptionRepositoryProvider)
                      .publicUrlForUpload(p.imageUrl!);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Uploaded prescription photo',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (url != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
              ],
            );
          }
          final doctor = p.doctorId == null
              ? null
              : ref.watch(publicDoctorProvider(p.doctorId!)).valueOrNull;
          return SingleChildScrollView(
            child: DigitalPrescription(
              doctorName: doctor?.name ?? 'GoDoctor doctor',
              doctorDetail: doctor?.primarySpecialty,
              patientName: 'GoDoctor patient',
              items: p.items,
              issuedAt: p.issuedAt.toLocal(),
              validUntil: p.validUntil,
              reference: p.id,
            ),
          );
        },
      ),
    );
  }
}
