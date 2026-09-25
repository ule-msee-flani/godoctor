import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/drug.dart';
import '../../../data/models/prescription.dart';
import '../../../data/providers/repository_providers.dart';

/// Doctor prescribing UI: structured drug search (autocomplete against the
/// `drugs` catalog) with a free-text fallback for anything not found.
/// Each added line remembers whether it came from the catalog or free text
/// (`PrescriptionItem.isStructured`) -- free-text items can't be reliably
/// matched against chemist inventory later, per spec.
class PrescriptionBuilder extends ConsumerStatefulWidget {
  const PrescriptionBuilder({
    super.key,
    required this.items,
    required this.onChanged,
  });

  final List<PrescriptionItem> items;
  final ValueChanged<List<PrescriptionItem>> onChanged;

  @override
  ConsumerState<PrescriptionBuilder> createState() =>
      _PrescriptionBuilderState();
}

class _PrescriptionBuilderState extends ConsumerState<PrescriptionBuilder> {
  final _searchCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '1');
  final _instructionsCtrl = TextEditingController();
  Timer? _debounce;
  List<Drug> _suggestions = [];
  Drug? _selectedDrug;
  bool _freeText = false;

  void _onSearchChanged(String value) {
    setState(() => _selectedDrug = null);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      if (value.trim().isEmpty) {
        setState(() => _suggestions = []);
        return;
      }
      final results = await ref.read(drugRepositoryProvider).searchDrugs(value);
      if (mounted) setState(() => _suggestions = results);
    });
  }

  void _addItem() {
    if (!_freeText && _selectedDrug == null) return;
    if (_freeText && _searchCtrl.text.trim().isEmpty) return;

    final item = PrescriptionItem(
      prescriptionId: '', // filled in on save
      drugId: _freeText ? null : _selectedDrug!.id,
      freeTextName: _freeText ? _searchCtrl.text.trim() : null,
      drugName: _freeText ? null : _selectedDrug!.displayName,
      dosage: _dosageCtrl.text.trim().isEmpty ? null : _dosageCtrl.text.trim(),
      quantity: int.tryParse(_quantityCtrl.text) ?? 1,
      instructions: _instructionsCtrl.text.trim().isEmpty
          ? null
          : _instructionsCtrl.text.trim(),
    );
    widget.onChanged([...widget.items, item]);

    setState(() {
      _searchCtrl.clear();
      _dosageCtrl.clear();
      _quantityCtrl.text = '1';
      _instructionsCtrl.clear();
      _selectedDrug = null;
      _suggestions = [];
    });
  }

  void _removeAt(int index) {
    final updated = [...widget.items]..removeAt(index);
    widget.onChanged(updated);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _dosageCtrl.dispose();
    _quantityCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < widget.items.length; i++)
          ListTile(
            dense: true,
            leading: Icon(
              widget.items[i].isStructured
                  ? Icons.verified_outlined
                  : Icons.edit_note,
              size: 18,
            ),
            title: Text(widget.items[i].displayName),
            subtitle: Text(
              [
                if (widget.items[i].dosage != null) widget.items[i].dosage!,
                'x${widget.items[i].quantity}',
              ].join(' · '),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => _removeAt(i),
            ),
          ),
        const Divider(),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Not in catalog (free text)'),
          value: _freeText,
          onChanged: (v) => setState(() {
            _freeText = v;
            _selectedDrug = null;
            _suggestions = [];
          }),
        ),
        TextField(
          controller: _searchCtrl,
          onChanged: _freeText ? null : _onSearchChanged,
          decoration: InputDecoration(
            labelText: _freeText ? 'Drug name' : 'Search drug catalog',
          ),
        ),
        if (!_freeText && _suggestions.isNotEmpty)
          ...(_suggestions
              .take(5)
              .map(
                (d) => ListTile(
                  dense: true,
                  title: Text(d.displayName),
                  selected: _selectedDrug?.id == d.id,
                  onTap: () => setState(() {
                    _selectedDrug = d;
                    _searchCtrl.text = d.displayName;
                    _suggestions = [];
                  }),
                ),
              )),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _dosageCtrl,
                decoration: const InputDecoration(labelText: 'Dosage'),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _quantityCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Qty'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _instructionsCtrl,
          decoration: const InputDecoration(labelText: 'Instructions'),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add item'),
            onPressed: _addItem,
          ),
        ),
      ],
    );
  }
}
