import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/prescription.dart';
import '../../data/providers/repository_providers.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/repository_errors.dart';
import '../../core/widgets/motion.dart';
import '../patient/widgets/medicine_image.dart';
import '../payments/fulfillment_picker.dart';
import '../payments/mpesa_checkout.dart';
import '../location/match_location_bar.dart';
import '../../services/chemist_matching.dart';
import 'chemist_match.dart';

final _prescriptionProvider = FutureProvider.autoDispose
    .family<Prescription?, String>(
      (ref, id) => ref.watch(prescriptionRepositoryProvider).fetchById(id),
    );

/// Order every medicine on a prescription from one chemist. Chemists are
/// ranked by how many of the medicines they have, then distance, then
/// price; the prescription is attached to the order so the chemist can
/// check it before handing anything over.
class PrescriptionOrderScreen extends ConsumerStatefulWidget {
  const PrescriptionOrderScreen({
    super.key,
    required this.prescriptionId,
    this.initialChemistId,
  });

  final String prescriptionId;
  final String? initialChemistId;

  @override
  ConsumerState<PrescriptionOrderScreen> createState() =>
      _PrescriptionOrderScreenState();
}

class _PrescriptionOrderScreenState
    extends ConsumerState<PrescriptionOrderScreen> {
  late String? _chemistId = widget.initialChemistId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) offerPreciseLocation(context, ref);
    });
  }

  String _fulfillment = 'pickup';

  /// Quantities the patient changed, by drug id.
  final Map<String, int> _qty = {};
  bool _placing = false;
  String? _paidAt;

  Future<void> _place(ChemistMatch match) async {
    setState(() => _placing = true);
    try {
      await simulateMpesaPrompt();
      final orderId = await ref
          .read(orderRepositoryProvider)
          .placeOrder(
            chemistId: match.chemistId,
            prescriptionId: widget.prescriptionId,
            fulfillmentType: _fulfillment,
            lines: [
              for (final l in match.lines)
                CartLine(
                  drugId: l.stock.drugId,
                  quantity: _qty[l.stock.drugId] ?? l.quantity,
                  unitPrice: l.stock.price,
                ),
            ],
          );
      if (!mounted) return;
      setState(() => _paidAt = match.chemistName);
      await Future<void>.delayed(const Duration(milliseconds: 1700));
      if (mounted) context.pushReplacement('/patient/order/$orderId');
    } catch (e) {
      if (mounted) {
        setState(() => _placing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${friendlyError(e)} You haven\'t been charged.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prescriptionAsync = ref.watch(
      _prescriptionProvider(widget.prescriptionId),
    );

    if (_paidAt != null) {
      return Scaffold(
        body: PaymentSuccessView(
          message: 'Order placed. $_paidAt is getting your medicines ready.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Order your medicines')),
      body: prescriptionAsync.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorView(message: friendlyError(e)),
        data: (prescription) {
          if (prescription == null) {
            return const ErrorView(message: 'Prescription not found');
          }
          if (!prescription.isValid) {
            return const EmptyView(
              message:
                  'This prescription has expired. Ask your doctor for a new one.',
              icon: LucideIcons.fileX,
            );
          }
          final key = stockKeyFor(prescription);
          if (key.isEmpty) {
            return const EmptyView(
              message:
                  'The medicines on this prescription were written by name, so '
                  'they cannot be matched automatically. Show the prescription at any chemist.',
              icon: LucideIcons.store,
            );
          }
          return _body(prescription, key);
        },
      ),
    );
  }

  Widget _body(Prescription prescription, String key) {
    final theme = Theme.of(context).textTheme;
    final stock = ref.watch(prescriptionStockProvider(key));
    final at = ref.watch(matchingLocationProvider);
    final freeText = prescription.items.where((i) => !i.isStructured).toList();

    return stock.when(
      loading: () => const SkeletonList(),
      error: (e, _) => ErrorView(
        message: friendlyError(e),
        onRetry: () => ref.invalidate(prescriptionStockProvider(key)),
      ),
      data: (items) {
        final ranked = rankChemists(
          prescription,
          items,
          patientLat: at?.lat,
          patientLng: at?.lng,
        );
        if (ranked.isEmpty) {
          return const EmptyView(
            message:
                'No chemist on GoDoctor has these medicines in stock right now. '
                'You can still show your prescription at any chemist.',
            icon: LucideIcons.packageX,
          );
        }
        final selected =
            ranked.where((m) => m.chemistId == _chemistId).firstOrNull ??
            ranked.first;
        final missing = prescription.items
            .where(
              (i) =>
                  i.isStructured &&
                  !selected.lines.any((l) => l.item.drugId == i.drugId),
            )
            .toList();
        final total = selected.lines.fold<double>(
          0,
          (sum, l) =>
              sum + (_qty[l.stock.drugId] ?? l.quantity) * l.stock.price,
        );

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  const MatchLocationBar(),
                  const SizedBox(height: 16),
                  Text('Choose a chemist', style: theme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'The ones with all your medicines, closest to you, come first.',
                    style: theme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  for (final (i, m) in ranked.indexed)
                    FadeSlideIn(
                      index: i,
                      child: _ChemistOption(
                        match: m,
                        selected: m.chemistId == selected.chemistId,
                        onTap: () => setState(() {
                          _chemistId = m.chemistId;
                          _qty.clear();
                        }),
                      ),
                    ),
                  const SizedBox(height: 18),
                  Text(
                    'From ${selected.chemistName}',
                    style: theme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  for (final l in selected.lines)
                    _LineRow(
                      line: l,
                      quantity: _qty[l.stock.drugId] ?? l.quantity,
                      onChanged: (v) =>
                          setState(() => _qty[l.stock.drugId] = v),
                    ),
                  if (missing.isNotEmpty || freeText.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            LucideIcons.info,
                            size: 18,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              [
                                if (missing.isNotEmpty)
                                  'Not in stock here: ${missing.map((i) => i.displayName).join(', ')}.',
                                if (freeText.isNotEmpty)
                                  'Ask the chemist about: ${freeText.map((i) => i.displayName).join(', ')}.',
                              ].join('\n'),
                              style: theme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  FulfillmentPicker(
                    value: _fulfillment,
                    chemistName: selected.chemistName,
                    onChanged: (v) => setState(() => _fulfillment = v),
                  ),
                  const SizedBox(height: 20),
                  const MpesaPayWithCard(),
                  const SizedBox(height: 10),
                  const EscrowNote(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.fileCheck,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your prescription is attached. The chemist checks it before preparing the order.',
                          style: theme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            MpesaPayBar(
              total: total,
              paying: _placing,
              onPay: () => _place(selected),
            ),
          ],
        );
      },
    );
  }
}

class _ChemistOption extends StatelessWidget {
  const _ChemistOption({
    required this.match,
    required this.selected,
    required this.onTap,
  });

  final ChemistMatch match;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppColors.primarySofter : AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  selected ? LucideIcons.circleCheck : LucideIcons.circle,
                  color: selected ? AppColors.ink : AppColors.inkFaint,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(match.chemistName, style: theme.titleSmall),
                      Text(
                        [
                          match.hasEverything
                              ? 'Has all ${match.wanted}'
                              : 'Has ${match.lines.length} of ${match.wanted}',
                          if (match.km != null)
                            '${match.km!.toStringAsFixed(1)} km',
                        ].join(' · '),
                        style: theme.bodySmall?.copyWith(
                          color: match.hasEverything
                              ? AppColors.success
                              : AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(formatKes(match.total), style: theme.titleSmall),
                IconButton(
                  tooltip: 'About this pharmacy',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(LucideIcons.info, size: 18),
                  onPressed: () =>
                      context.push('/patient/chemist/${match.chemistId}'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.quantity,
    required this.onChanged,
  });

  final MatchedLine line;
  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final drug = line.stock.drug ?? line.item.drug;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (drug != null)
            MedicineImage(drug: drug, size: 52, radius: 14)
          else
            const SizedBox(width: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.item.displayName, style: theme.titleSmall),
                if (line.item.dosage != null)
                  Text(line.item.dosage!, style: theme.bodySmall),
                Text(
                  '${formatKes(line.stock.price)} each · prescribed ${line.item.quantity}',
                  style: theme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Fewer',
            icon: const Icon(LucideIcons.minus, size: 16),
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
          ),
          Text('$quantity', style: theme.titleSmall),
          IconButton(
            tooltip: 'More',
            icon: const Icon(LucideIcons.plus, size: 16),
            // Never more than prescribed, nor more than the chemist has.
            onPressed:
                quantity < line.item.quantity && quantity < line.stock.quantity
                ? () => onChanged(quantity + 1)
                : null,
          ),
        ],
      ),
    );
  }
}
