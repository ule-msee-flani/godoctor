import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/motion.dart';
import '../../../data/models/drug.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/prescription.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../payments/fulfillment_picker.dart';
import '../../payments/mpesa_checkout.dart';
import '../widgets/medicine_image.dart';

final _validPrescriptionsProvider =
    FutureProvider.autoDispose<List<Prescription>>((ref) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) return [];
      final all = await ref
          .watch(prescriptionRepositoryProvider)
          .fetchForPatient(userId);
      return all.where((p) => p.isValid).toList();
    });

/// Buy one medicine from the chemist the patient picked: how many, pickup
/// or delivery, the prescription when it needs one, and M-Pesa.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.item});

  final ChemistInventoryItem item;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  int _quantity = 1;
  String _fulfillment = 'pickup';
  String? _prescriptionId;
  bool _pickedPrescription = false;
  bool _paying = false;
  bool _paid = false;
  String? _error;

  ChemistInventoryItem get _item => widget.item;

  bool get _needsPrescription => _item.drug?.requiresPrescription ?? false;

  Future<void> _pay() async {
    if (_needsPrescription && _prescriptionId == null) {
      setState(
        () => _error = 'Choose or upload a prescription for this medicine.',
      );
      return;
    }
    setState(() {
      _paying = true;
      _error = null;
    });
    try {
      await simulateMpesaPrompt();
      final orderId = await ref
          .read(orderRepositoryProvider)
          .placeOrder(
            chemistId: _item.chemistId,
            prescriptionId: _needsPrescription ? _prescriptionId : null,
            fulfillmentType: _fulfillment,
            lines: [
              CartLine(
                drugId: _item.drugId,
                quantity: _quantity,
                unitPrice: _item.price,
              ),
            ],
          );
      if (!mounted) return;
      setState(() => _paid = true);
      await Future<void>.delayed(const Duration(milliseconds: 1700));
      if (mounted) context.pushReplacement('/patient/order/$orderId');
    } catch (e) {
      if (mounted) {
        setState(() {
          _paying = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final total = _item.price * _quantity;

    if (_paid) {
      return Scaffold(
        body: PaymentSuccessView(
          message:
              'Order placed. ${_item.chemistName ?? 'The chemist'} is getting '
              'your medicine ready.',
        ),
      );
    }

    return PopScope(
      canPop: !_paying,
      child: Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  FadeSlideIn(child: _ItemCard(item: _item)),
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    index: 1,
                    child: _QuantityRow(
                      quantity: _quantity,
                      max: _item.quantity,
                      onChanged: (v) => setState(() => _quantity = v),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeSlideIn(
                    index: 2,
                    child: FulfillmentPicker(
                      value: _fulfillment,
                      chemistName: _item.chemistName,
                      onChanged: (v) => setState(() => _fulfillment = v),
                    ),
                  ),
                  if (_needsPrescription) ...[
                    const SizedBox(height: 22),
                    FadeSlideIn(index: 3, child: _prescriptionPicker(theme)),
                  ],
                  const SizedBox(height: 22),
                  const FadeSlideIn(index: 4, child: MpesaPayWithCard()),
                  const SizedBox(height: 10),
                  const EscrowNote(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.dangerSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.circleAlert,
                              size: 18,
                              color: AppColors.danger,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!, style: theme.bodyMedium),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            MpesaPayBar(total: total, paying: _paying, onPay: _pay),
          ],
        ),
      ),
    );
  }

  Widget _prescriptionPicker(TextTheme theme) {
    final async = ref.watch(_validPrescriptionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.fileText, size: 18, color: AppColors.ink),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Prescription needed', style: theme.titleMedium),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'The chemist checks it before handing this medicine over.',
          style: theme.bodySmall,
        ),
        const SizedBox(height: 10),
        async.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(friendlyError(e)),
          data: (list) {
            // The ones that include this medicine first; pick one for them.
            final sorted = [...list]
              ..sort(
                (a, b) =>
                    (_includes(b) ? 1 : 0).compareTo(_includes(a) ? 1 : 0),
              );
            if (!_pickedPrescription && sorted.isNotEmpty) {
              final best = sorted.first;
              if (_includes(best) ||
                  best.source == PrescriptionSource.externalUpload) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_pickedPrescription) {
                    setState(() {
                      _prescriptionId = best.id;
                      _pickedPrescription = true;
                    });
                  }
                });
              }
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final p in sorted)
                  _PrescriptionOption(
                    prescription: p,
                    includesThis: _includes(p),
                    drugName: _item.drug?.genericName,
                    selected: _prescriptionId == p.id,
                    onTap: () => setState(() {
                      _prescriptionId = p.id;
                      _pickedPrescription = true;
                      _error = null;
                    }),
                  ),
                OutlinedButton.icon(
                  icon: const Icon(LucideIcons.upload, size: 18),
                  label: Text(
                    list.isEmpty
                        ? 'Upload a photo of your prescription'
                        : 'Upload a different prescription',
                  ),
                  onPressed: () async {
                    await context.push('/patient/prescriptions/upload');
                    ref.invalidate(_validPrescriptionsProvider);
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  bool _includes(Prescription p) =>
      p.items.any((i) => i.drugId != null && i.drugId == _item.drugId);
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});

  final ChemistInventoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final drug = item.drug;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (drug != null)
            MedicineImage(drug: drug, size: 64, radius: 16)
          else
            const SizedBox(
              width: 64,
              height: 64,
              child: Icon(LucideIcons.pill, color: AppColors.ink),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  drug?.displayName ?? 'Medicine',
                  style: theme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.chemistName != null)
                  Text(item.chemistName!, style: theme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  '${formatKes(item.price)} each · ${item.quantity} in stock',
                  style: theme.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityRow extends StatelessWidget {
  const _QuantityRow({
    required this.quantity,
    required this.max,
    required this.onChanged,
  });

  final int quantity;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    Widget step(IconData icon, String tip, VoidCallback? onTap) =>
        IconButton.filledTonal(
          tooltip: tip,
          onPressed: onTap,
          icon: Icon(icon, size: 16),
        );
    return Row(
      children: [
        Expanded(child: Text('Quantity', style: theme.titleMedium)),
        step(
          LucideIcons.minus,
          'Fewer',
          quantity > 1 ? () => onChanged(quantity - 1) : null,
        ),
        SizedBox(
          width: 44,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            transitionBuilder: (child, a) =>
                ScaleTransition(scale: a, child: child),
            child: Text(
              '$quantity',
              key: ValueKey(quantity),
              textAlign: TextAlign.center,
              style: theme.titleLarge,
            ),
          ),
        ),
        step(
          LucideIcons.plus,
          'More',
          quantity < max ? () => onChanged(quantity + 1) : null,
        ),
      ],
    );
  }
}

class _PrescriptionOption extends StatelessWidget {
  const _PrescriptionOption({
    required this.prescription,
    required this.includesThis,
    required this.drugName,
    required this.selected,
    required this.onTap,
  });

  final Prescription prescription;
  final bool includesThis;
  final String? drugName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final p = prescription;
    final uploaded = p.source == PrescriptionSource.externalUpload;
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
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  selected ? LucideIcons.circleCheck : LucideIcons.circle,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.inkFaint,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${uploaded ? 'Uploaded photo' : 'From your consultation'} · '
                        '${formatDayShort(p.issuedAt.toLocal())}',
                        style: theme.titleSmall,
                      ),
                      Text(
                        uploaded
                            ? 'The chemist reads the photo'
                            : p.items.map((i) => i.displayName).join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodySmall,
                      ),
                      if (!uploaded)
                        Text(
                          includesThis
                              ? 'Includes ${drugName ?? 'this medicine'}'
                              : 'Doesn\'t include ${drugName ?? 'this medicine'}',
                          style: theme.bodySmall?.copyWith(
                            color: includesThis
                                ? AppColors.success
                                : AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
