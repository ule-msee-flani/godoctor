import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/loading_view.dart';
import '../../../data/repositories/repository_errors.dart';
import '../widgets/pack_photo.dart';
import '../../../data/models/drug.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';

/// Photograph (or re-photograph) the pack for one inventory row.
Future<void> _changePhoto(
  BuildContext context,
  WidgetRef ref,
  ChemistInventoryItem item,
) async {
  final photo = await pickPackPhoto(context);
  if (photo == null) return;
  final repo = ref.read(drugRepositoryProvider);
  try {
    final path = await repo.uploadInventoryPhoto(
      chemistId: item.chemistId,
      drugId: item.drugId,
      bytes: photo.bytes,
      fileExt: photo.ext,
    );
    await repo.setInventoryPhoto(
      chemistId: item.chemistId,
      drugId: item.drugId,
      imagePath: path,
    );
    ref.invalidate(_inventoryProvider);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload photo: ${friendlyError(e)}')),
      );
    }
  }
}

final _inventoryProvider = FutureProvider((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  return ref.watch(drugRepositoryProvider).fetchChemistInventory(userId);
});

class ChemistInventoryScreen extends ConsumerWidget {
  const ChemistInventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(_inventoryProvider);
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Incoming orders',
            onPressed: () => context.push('/chemist/orders'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: userId == null
            ? null
            : () async {
                await showDialog(
                  context: context,
                  builder: (_) => _AddDrugDialog(chemistId: userId),
                );
                ref.invalidate(_inventoryProvider);
              },
        icon: const Icon(Icons.add),
        label: const Text('Add drug'),
      ),
      body: inventory.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyView(
              message: 'No inventory yet. Add your first drug.',
              icon: LucideIcons.package,
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Photo')),
                DataColumn(label: Text('Drug')),
                DataColumn(label: Text('Quantity')),
                DataColumn(label: Text('Price (KES)')),
                DataColumn(label: Text('Updated')),
                DataColumn(label: Text('')),
              ],
              rows: items
                  .map(
                    (item) => DataRow(
                      cells: [
                        DataCell(
                          Tooltip(
                            message: item.imagePath == null
                                ? 'Add a photo of this pack'
                                : 'Change photo',
                            child: PackPhotoThumb(
                              path: item.imagePath,
                              size: 40,
                              onTap: () => _changePhoto(context, ref, item),
                            ),
                          ),
                        ),
                        DataCell(Text(item.drug?.displayName ?? item.drugId)),
                        DataCell(
                          _InlineNumberField(
                            initial: item.quantity.toString(),
                            onSubmit: (v) async {
                              await ref
                                  .read(drugRepositoryProvider)
                                  .upsertInventory(
                                    chemistId: item.chemistId,
                                    drugId: item.drugId,
                                    quantity: int.tryParse(v) ?? item.quantity,
                                    price: item.price,
                                  );
                              ref.invalidate(_inventoryProvider);
                            },
                          ),
                        ),
                        DataCell(
                          _InlineNumberField(
                            initial: item.price.toStringAsFixed(0),
                            onSubmit: (v) async {
                              await ref
                                  .read(drugRepositoryProvider)
                                  .upsertInventory(
                                    chemistId: item.chemistId,
                                    drugId: item.drugId,
                                    quantity: item.quantity,
                                    price: double.tryParse(v) ?? item.price,
                                  );
                              ref.invalidate(_inventoryProvider);
                            },
                          ),
                        ),
                        DataCell(
                          Text(
                            item.lastUpdatedAt
                                .toLocal()
                                .toString()
                                .split('.')
                                .first,
                          ),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () async {
                              await ref
                                  .read(drugRepositoryProvider)
                                  .removeInventory(
                                    chemistId: item.chemistId,
                                    drugId: item.drugId,
                                  );
                              ref.invalidate(_inventoryProvider);
                            },
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          );
        },
      ),
    );
  }
}

class _InlineNumberField extends StatefulWidget {
  const _InlineNumberField({required this.initial, required this.onSubmit});

  final String initial;
  final ValueChanged<String> onSubmit;

  @override
  State<_InlineNumberField> createState() => _InlineNumberFieldState();
}

class _InlineNumberFieldState extends State<_InlineNumberField> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: TextField(
        controller: _ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
        ),
        onSubmitted: widget.onSubmit,
        onTapOutside: (_) => widget.onSubmit(_ctrl.text),
      ),
    );
  }
}

class _AddDrugDialog extends ConsumerStatefulWidget {
  const _AddDrugDialog({required this.chemistId});

  final String chemistId;

  @override
  ConsumerState<_AddDrugDialog> createState() => _AddDrugDialogState();
}

class _AddDrugDialogState extends ConsumerState<_AddDrugDialog> {
  final _searchCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '10');
  final _priceCtrl = TextEditingController();
  List<Drug> _results = [];
  Drug? _selected;
  bool _saving = false;
  ({Uint8List bytes, String ext})? _photo;
  String? _error;

  Future<void> _pickPhoto() async {
    final photo = await pickPackPhoto(context);
    if (photo != null && mounted) setState(() => _photo = photo);
  }

  Future<void> _search(String query) async {
    final results = await ref.read(drugRepositoryProvider).searchDrugs(query);
    if (mounted) setState(() => _results = results);
  }

  Future<void> _save() async {
    if (_selected == null) return;
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
          drugId: _selected!.id,
          bytes: _photo!.bytes,
          fileExt: _photo!.ext,
        );
      }
      await repo.upsertInventory(
        chemistId: widget.chemistId,
        drugId: _selected!.id,
        quantity: int.tryParse(_quantityCtrl.text) ?? 0,
        price: double.tryParse(_priceCtrl.text) ?? 0,
        imagePath: imagePath,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add drug to inventory'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: _search,
              decoration: const InputDecoration(labelText: 'Search drug'),
            ),
            if (_results.isNotEmpty)
              SizedBox(
                height: 150,
                child: ListView(
                  children: _results
                      .map(
                        (d) => ListTile(
                          dense: true,
                          title: Text(d.displayName),
                          selected: _selected?.id == d.id,
                          onTap: () => setState(() {
                            _selected = d;
                            _searchCtrl.text = d.displayName;
                            _results = [];
                          }),
                        ),
                      )
                      .toList(),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Price (KES)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                PackPhotoThumb(
                  bytes: _photo?.bytes,
                  size: 56,
                  onTap: _pickPhoto,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pack photo (recommended)',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        'Patients see this photo of the exact pack you sell.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _saving ? null : _pickPhoto,
                  child: Text(_photo == null ? 'Add' : 'Change'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selected == null || _saving ? null : _save,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
