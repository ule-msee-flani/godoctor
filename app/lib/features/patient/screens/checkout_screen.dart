import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
              child: ListTile(
                title: Text(widget.item.drug?.displayName ?? 'Medicine'),
                subtitle: Text(widget.item.chemistName ?? ''),
                trailing: Text('KES ${widget.item.price.toStringAsFixed(0)}'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Quantity'),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
                    ),
                    Text('$_quantity', style: Theme.of(context).textTheme.titleMedium),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _quantity < widget.item.quantity
                          ? () => setState(() => _quantity++)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Fulfillment'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'pickup', label: Text('Pickup')),
                ButtonSegment(value: 'delivery', label: Text('Delivery')),
              ],
              selected: {_fulfillment},
              onSelectionChanged: (s) => setState(() => _fulfillment = s.first),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Pickup/delivery logistics are arranged directly with the chemist.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            if (_requiresPrescription) ...[
              const SizedBox(height: 20),
              const Text(
                'Prescription required',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              prescriptions.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (list) {
                  if (list.isEmpty) {
                    return OutlinedButton.icon(
                      icon: const Icon(Icons.upload_file),
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
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  'KES ${total.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.payment),
              label: Text(_placing ? 'Placing order...' : 'Pay with M-Pesa (simulated)'),
              onPressed: _placing ? null : _placeOrder,
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Real M-Pesa payment isn\'t wired up yet -- this simulates a successful escrow hold.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}
