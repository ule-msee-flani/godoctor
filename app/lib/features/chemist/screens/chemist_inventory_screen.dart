import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/drug.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../medicine/medicine_gallery.dart';
import '../../patient/widgets/medicine_image.dart';
import '../widgets/pack_photo.dart';
import '../../../services/live_updates.dart';

final _inventoryProvider =
    FutureProvider.autoDispose<List<ChemistInventoryItem>>((ref) async {
      final userId = ref.watch(currentUserIdProvider);
      ref.watch(liveTick(LiveTable.inventory));
      if (userId == null) return const [];
      return ref.watch(drugRepositoryProvider).fetchChemistInventory(userId);
    });

/// Chemist's "Stock" tab: the same medicine gallery patients see. "My stock"
/// shows what this pharmacy sells (with its own pack photos, quantities and
/// prices); "All medicines" is the full catalogue to add from.
class ChemistInventoryScreen extends ConsumerStatefulWidget {
  const ChemistInventoryScreen({super.key});

  @override
  ConsumerState<ChemistInventoryScreen> createState() =>
      _ChemistInventoryScreenState();
}

class _ChemistInventoryScreenState
    extends ConsumerState<ChemistInventoryScreen> {
  final _searchCtrl = TextEditingController();
  bool? _showMine; // null = decide from whether there is any stock

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _edit(Drug drug, ChemistInventoryItem? existing) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          StockDialog(chemistId: userId, drug: drug, existing: existing),
    );
    if (changed == true) ref.invalidate(_inventoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final inventory = ref.watch(_inventoryProvider);
    final catalog = ref.watch(medicineCatalogProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        actions: [
          // Bring stock from a pharmacy system or Excel in one go.
          TextButton.icon(
            icon: const Icon(LucideIcons.fileUp, size: 18),
            label: const Text('Import'),
            onPressed: () => context.push('/chemist/import'),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(LucideIcons.logOut),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: switch ((inventory, catalog)) {
        (AsyncError(:final error), _) ||
        (_, AsyncError(:final error)) => ErrorView(
          message: friendlyError(error),
          onRetry: () {
            ref.invalidate(_inventoryProvider);
            ref.invalidate(medicineCatalogProvider);
          },
        ),
        (AsyncData(value: final stock), AsyncData(value: final drugs)) => _body(
          stock,
          drugs,
        ),
        _ => const MedicineGallerySkeleton(),
      },
    );
  }

  Widget _body(List<ChemistInventoryItem> stock, List<Drug> drugs) {
    final byDrug = {for (final s in stock) s.drugId: s};
    final showMine = _showMine ?? stock.isNotEmpty;

    // In "My stock", show this pharmacy's own pack photo where it has one.
    final mine = [
      for (final s in stock)
        if (s.drug != null)
          s.drug!.withChemistPhoto(s.imagePath ?? s.drug!.chemistPhotoPath),
    ]..sort((a, b) => a.genericName.compareTo(b.genericName));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: true,
                    label: Text('My stock (${stock.length})'),
                    icon: const Icon(LucideIcons.packageCheck, size: 16),
                  ),
                  const ButtonSegment(
                    value: false,
                    label: Text('All medicines'),
                    icon: Icon(LucideIcons.pill, size: 16),
                  ),
                ],
                selected: {showMine},
                onSelectionChanged: (s) => setState(() => _showMine = s.first),
              ),
              const SizedBox(height: 10),
              MedicineSearchField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                hint: showMine ? 'Search my stock' : 'Search all medicines',
              ),
            ],
          ),
        ),
        Expanded(
          child: MedicineGallery(
            key: ValueKey(showMine),
            drugs: showMine ? mine : drugs,
            query: _searchCtrl.text,
            markedIds: byDrug.keys.toSet(),
            emptyMessage: showMine
                ? 'You have no stock yet.\nOpen "All medicines" and add what you sell.'
                : 'The medicine catalogue is empty.',
            footerBuilder: (context, drug) {
              final item = byDrug[drug.id];
              final theme = Theme.of(context).textTheme;
              return Row(
                children: [
                  Expanded(
                    child: item == null
                        ? Text('Not in your stock', style: theme.bodyMedium)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formatKes(item.price),
                                style: theme.titleMedium?.copyWith(
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              Text(
                                item.quantity == 0
                                    ? 'Out of stock'
                                    : '${item.quantity} in stock',
                                style: theme.bodySmall?.copyWith(
                                  color: item.quantity == 0
                                      ? AppColors.danger
                                      : item.quantity < 10
                                      ? AppColors.warning
                                      : AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(width: 10),
                  item == null
                      ? FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 44),
                          ),
                          onPressed: () => _edit(drug, null),
                          icon: const Icon(LucideIcons.packagePlus, size: 17),
                          label: const Text('Add to stock'),
                        )
                      : OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                          ),
                          onPressed: () => _edit(drug, item),
                          icon: const Icon(LucideIcons.pencil, size: 16),
                          label: const Text('Edit'),
                        ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Add a medicine to stock, or change its quantity, price or pack photo.
/// Pops `true` when something was saved or removed.
class StockDialog extends ConsumerStatefulWidget {
  const StockDialog({
    super.key,
    required this.chemistId,
    required this.drug,
    this.existing,
  });

  final String chemistId;
  final Drug drug;
  final ChemistInventoryItem? existing;

  @override
  ConsumerState<StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends ConsumerState<StockDialog> {
  late final _quantityCtrl = TextEditingController(
    text: '${widget.existing?.quantity ?? 10}',
  );
  late final _priceCtrl = TextEditingController(
    text: widget.existing == null
        ? ''
        : widget.existing!.price.toStringAsFixed(0),
  );
  ({Uint8List bytes, String ext})? _photo;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final photo = await pickPackPhoto(context);
    if (photo != null && mounted) setState(() => _photo = photo);
  }

  Future<void> _save() async {
    final price = double.tryParse(_priceCtrl.text.trim());
    final quantity = int.tryParse(_quantityCtrl.text.trim());
    if (price == null || price <= 0 || quantity == null || quantity < 0) {
      setState(() => _error = 'Enter a price above 0 and a quantity.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(drugRepositoryProvider);
    try {
      String? imagePath;
      if (_photo != null) {
        imagePath = await repo.uploadInventoryPhoto(
          chemistId: widget.chemistId,
          drugId: widget.drug.id,
          bytes: _photo!.bytes,
          fileExt: _photo!.ext,
        );
      }
      await repo.upsertInventory(
        chemistId: widget.chemistId,
        drugId: widget.drug.id,
        quantity: quantity,
        price: price,
        imagePath: imagePath,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(drugRepositoryProvider)
          .removeInventory(chemistId: widget.chemistId, drugId: widget.drug.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyError(e);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final editing = widget.existing != null;

    return AlertDialog(
      title: Text(editing ? 'Update stock' : 'Add to stock'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  MedicineImage(drug: widget.drug, size: 48, radius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.drug.genericName, style: theme.titleSmall),
                        if (widget.drug.form != null)
                          Text(widget.drug.form!, style: theme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantityCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _priceCtrl,
                      autofocus: !editing,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Price (KES)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  PackPhotoThumb(
                    bytes: _photo?.bytes,
                    path: _photo == null ? widget.existing?.imagePath : null,
                    size: 56,
                    onTap: _pickPhoto,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pack photo', style: theme.titleSmall),
                        Text(
                          'Patients see this photo of the exact pack you sell.',
                          style: theme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _pickPhoto,
                    child: Text(
                      _photo == null && widget.existing?.imagePath == null
                          ? 'Add'
                          : 'Change',
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (editing)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: _saving ? null : _remove,
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
