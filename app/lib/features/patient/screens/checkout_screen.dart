import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/drug.dart';
import '../../../data/models/prescription.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/order_repository.dart';

final _validPrescriptionsProvider = FutureProvider<List<Prescription>>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final all = await ref
      .watch(prescriptionRepositoryProvider)
      .fetchForPatient(userId);
  return all.where((p) => p.isValid).toList();
});

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.item});

  final ChemistInventoryItem item;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  int _quantity = 1;
  String _fulfillment = 'pickup';
  String? _selectedPrescriptionId;
  bool _placing = false;
  String? _error;

  bool get _requiresPrescription =>
      widget.item.drug?.requiresPrescription ?? false;

  Future<void> _placeOrder() async {
    if (_requiresPrescription && _selectedPrescriptionId == null) {
      setState(
        () => _error = 'Attach a valid prescription to order this item.',
      );
      return;
    }
    setState(() {
      _placing = true;
      _error = null;
    });
    try {
      final orderId = await ref
          .read(orderRepositoryProvider)
          .placeOrder(
            chemistId: widget.item.chemistId,
            prescriptionId: _selectedPrescriptionId,
            fulfillmentType: _fulfillment,
            lines: [
              CartLine(
                drugId: widget.item.drugId,
                quantity: _quantity,
                unitPrice: widget.item.price,
              ),
            ],
          );
      if (mounted) context.pushReplacement('/patient/order/$orderId');
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.item.price * _quantity;
    final prescriptions = ref.watch(_validPrescriptionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.accentTealSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.pill,
                          color: AppColors.accentTeal,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.drug?.displayName ?? 'Medicine',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.item.chemistName ?? '',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'KES ${widget.item.price.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Quantity',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'How many do you need?',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Row(
                    children: [
                      _StepperButton(
                        icon: LucideIcons.minus,
                        onTap: _quantity > 1
                            ? () => setState(() => _quantity--)
                            : null,
                      ),
                      SizedBox(
                        width: 36,
                        child: Text(
                          '$_quantity',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      _StepperButton(
                        icon: LucideIcons.plus,
                        onTap: _quantity < widget.item.quantity
                            ? () => setState(() => _quantity++)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Fulfillment',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'pickup',
                        label: Text('Pickup'),
                        icon: Icon(LucideIcons.store, size: 16),
                      ),
                      ButtonSegment(
                        value: 'delivery',
                        label: Text('Delivery'),
                        icon: Icon(LucideIcons.bike, size: 16),
                      ),
                    ],
                    selected: {_fulfillment},
                    onSelectionChanged: (s) =>
                        setState(() => _fulfillment = s.first),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pickup/delivery logistics are arranged directly with the chemist.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (_requiresPrescription) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Prescription required',
                titleIcon: LucideIcons.fileText,
                child: prescriptions.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('$e'),
                  data: (list) {
                    if (list.isEmpty) {
                      return OutlinedButton.icon(
                        icon: const Icon(LucideIcons.upload, size: 18),
                        label: const Text('Upload a prescription'),
                        onPressed: () =>
                            context.push('/patient/prescriptions/upload'),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedPrescriptionId,
                      decoration: const InputDecoration(
                        labelText: 'Select a prescription',
                      ),
                      items: list
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                '${p.source.name == 'app' ? 'App-issued' : 'Uploaded'} · ${p.issuedAt.toLocal().toString().split(' ').first}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedPrescriptionId = v),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'KES ${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(LucideIcons.wallet, size: 18),
              label: Text(
                _placing ? 'Placing order...' : 'Pay with M-Pesa (simulated)',
              ),
              onPressed: _placing ? null : _placeOrder,
            ),
            const SizedBox(height: 8),
            Text(
              'Real M-Pesa payment isn\'t wired up yet -- this simulates a successful escrow hold.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.titleIcon,
  });

  final String title;
  final IconData? titleIcon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (titleIcon case final icon?) ...[
                  Icon(icon, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                ],
                Text(title, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? AppColors.primarySoft : AppColors.border,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Center(
            child: Icon(
              icon,
              size: 16,
              color: enabled ? AppColors.primary : AppColors.inkFaint,
            ),
          ),
        ),
      ),
    );
  }
}
