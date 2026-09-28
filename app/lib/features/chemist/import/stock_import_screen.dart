import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/heartbeat_loader.dart';
import '../../../core/widgets/motion.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../../data/repositories/stock_sync_repository.dart';
import '../../../services/live_updates.dart';
import 'stock_table.dart';

enum _Stage { choose, matching, preview, saving, done }

/// Bring a pharmacy's existing stock in one go: a CSV exported from their
/// pharmacy system (or Excel), or cells pasted from a spreadsheet. Every
/// name is matched to the catalogue and shown before anything is saved.
class StockImportScreen extends ConsumerStatefulWidget {
  const StockImportScreen({super.key});

  @override
  ConsumerState<StockImportScreen> createState() => _StockImportScreenState();
}

class _StockImportScreenState extends ConsumerState<StockImportScreen> {
  _Stage _stage = _Stage.choose;
  StockTable? _table;
  Map<String, DrugMatch?> _matches = const {};
  String? _error;
  int _saved = 0;
  bool _showMissing = false;

  List<(StockLine, DrugMatch)> get _matched => [
    for (final l in _table?.lines ?? const <StockLine>[])
      if (_matches[l.name] case final m?) (l, m),
  ];

  List<StockLine> get _missing => [
    for (final l in _table?.lines ?? const <StockLine>[])
      if (_matches[l.name] == null) l,
  ];

  Future<void> _pickFile() async {
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Choose your stock file',
        type: FileType.custom,
        allowedExtensions: const ['csv', 'txt', 'tsv'],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      await _read(utf8.decode(bytes, allowMalformed: true));
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _paste() async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _PasteDialog(),
    );
    if (text != null && text.trim().isNotEmpty) await _read(text);
  }

  Future<void> _read(String text) async {
    final table = parseStockTable(text);
    if (table.lines.isEmpty) {
      setState(
        () => _error =
            'We couldn\'t find any medicines in that. Make sure it has a '
            'column for the name, the quantity and the selling price.',
      );
      return;
    }
    setState(() {
      _table = table;
      _stage = _Stage.matching;
      _error = null;
    });
    try {
      final matches = await ref.read(stockSyncRepositoryProvider).matchNames([
        for (final l in table.lines) l.name,
      ]);
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _stage = _Stage.preview;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = _Stage.choose;
          _error = friendlyError(e);
        });
      }
    }
  }

  Future<void> _save() async {
    // The same medicine twice in the file: the last line wins.
    final byDrug = <String, ({String drugId, int quantity, double price})>{};
    for (final (l, m) in _matched) {
      byDrug[m.id] = (drugId: m.id, quantity: l.quantity, price: l.price);
    }
    setState(() {
      _stage = _Stage.saving;
      _error = null;
    });
    try {
      final saved = await ref
          .read(stockSyncRepositoryProvider)
          .importStock(byDrug.values.toList());
      ref.read(liveTick(LiveTable.inventory).notifier).state++;
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _stage = _Stage.done;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = _Stage.preview;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _stage != _Stage.saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Import stock')),
        body: switch (_stage) {
          _Stage.choose => _choose(),
          _Stage.matching => const _Busy(
            message: 'Matching your medicines to our catalogue…',
          ),
          _Stage.saving => const _Busy(message: 'Saving your stock…'),
          _Stage.preview => _preview(),
          _Stage.done => _done(),
        },
        bottomNavigationBar: _stage == _Stage.preview
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton.icon(
                    icon: const Icon(LucideIcons.packageCheck, size: 18),
                    label: Text(
                      _matched.isEmpty
                          ? 'Nothing to save'
                          : 'Save ${_matched.length} '
                                '${_matched.length == 1 ? 'medicine' : 'medicines'} to my stock',
                    ),
                    onPressed: _matched.isEmpty ? null : _save,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _choose() {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.primarySofter,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                LucideIcons.fileSpreadsheet,
                color: AppColors.primary,
                size: 30,
              ),
              const SizedBox(height: 10),
              Text(
                'Bring your existing stock',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'No need to add medicines one by one. Export your stock from '
                'your pharmacy system or Excel and we\'ll do the rest.',
                style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (final (n, step) in [
          (
            1,
            'Export your stock as a CSV file (in Excel: File › Save As › CSV).',
          ),
          (
            2,
            'It needs columns for the medicine name, quantity and selling price.',
          ),
          (
            3,
            'We match each name to our catalogue. You check it before saving.',
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.primarySoft,
                  child: Text(
                    '$n',
                    style: text.labelMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(step, style: text.bodyMedium)),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            'Name, Quantity, Selling price\n'
            'Panadol 500mg tablets, 240, 5\n'
            'Amoxil 250mg capsules, 60, 12',
            style: text.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: AppColors.inkSoft,
              height: 1.5,
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          _ErrorNote(message: _error!),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          icon: const Icon(LucideIcons.fileUp, size: 18),
          label: const Text('Choose a CSV file'),
          onPressed: _pickFile,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(LucideIcons.clipboardPaste, size: 18),
          label: const Text('Paste from a spreadsheet'),
          onPressed: _paste,
        ),
        const SizedBox(height: 24),
        Material(
          color: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.border),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            leading: const Icon(LucideIcons.plugZap, color: AppColors.primary),
            title: const Text('Use a pharmacy system (ERP)?'),
            subtitle: const Text(
              'Connect it once and your GoDoctor stock stays up to date '
              'by itself.',
            ),
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () => context.push('/chemist/connect'),
          ),
        ),
      ],
    );
  }

  Widget _preview() {
    final text = Theme.of(context).textTheme;
    final table = _table!;
    final matched = _matched;
    final missing = _missing;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: 1 + (_showMissing ? missing.length : matched.length),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'We read ${table.lines.length} '
                      '${table.lines.length == 1 ? 'medicine' : 'medicines'}',
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Columns: ${table.columns.name} · '
                      '${table.columns.quantity} · ${table.columns.price}',
                      style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                    ),
                    if (table.skipped.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${table.skipped.length} '
                        '${table.skipped.length == 1 ? 'line was' : 'lines were'} '
                        'left out: ${table.skipped.take(3).join('; ')}'
                        '${table.skipped.length > 3 ? '…' : ''}',
                        style: text.bodySmall?.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Medicines already in your stock get the new quantity '
                      'and price.',
                      style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _ErrorNote(message: _error!),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    avatar: const Icon(LucideIcons.check, size: 16),
                    label: Text('Matched (${matched.length})'),
                    selected: !_showMissing,
                    onSelected: (_) => setState(() => _showMissing = false),
                  ),
                  ChoiceChip(
                    avatar: const Icon(LucideIcons.circleHelp, size: 16),
                    label: Text('Not found (${missing.length})'),
                    selected: _showMissing,
                    onSelected: (_) => setState(() => _showMissing = true),
                  ),
                ],
              ),
              if (_showMissing && missing.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'These aren\'t in our catalogue yet, so they\'re skipped. '
                    'Try the generic name (e.g. "Paracetamol 500mg").',
                    style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          );
        }
        if (_showMissing) {
          final l = missing[i - 1];
          return _LineTile(line: l);
        }
        final (l, m) = matched[i - 1];
        return _LineTile(line: l, match: m);
      },
    );
  }

  Widget _done() {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AnimatedCheck(),
            const SizedBox(height: 20),
            Text(
              '$_saved ${_saved == 1 ? 'medicine' : 'medicines'} saved',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Patients near you can now find and order them.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('Back to my stock'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line, this.match});

  final StockLine line;
  final DrugMatch? match;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final m = match;
    final renamed =
        m != null && m.name.toLowerCase() != line.name.toLowerCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            m == null ? LucideIcons.circleHelp : LucideIcons.circleCheck,
            size: 18,
            color: m == null ? AppColors.warning : AppColors.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
                if (renamed)
                  Text(
                    '→ ${m.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: AppColors.primary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatKes(line.price), style: text.labelLarge),
              Text(
                '${line.quantity} in stock',
                style: text.labelSmall?.copyWith(color: AppColors.inkFaint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DelayedHeartbeat(),
        const SizedBox(height: 16),
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.dangerSoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(LucideIcons.circleAlert, size: 18, color: AppColors.danger),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

class _PasteDialog extends StatefulWidget {
  const _PasteDialog();

  @override
  State<_PasteDialog> createState() => _PasteDialogState();
}

class _PasteDialogState extends State<_PasteDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Paste your stock'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Copy the name, quantity and price columns from Excel or '
              'Google Sheets and paste them here.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _text,
              autofocus: true,
              minLines: 6,
              maxLines: 10,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Panadol 500mg\t240\t5',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _text.text),
          child: const Text('Read it'),
        ),
      ],
    );
  }
}
