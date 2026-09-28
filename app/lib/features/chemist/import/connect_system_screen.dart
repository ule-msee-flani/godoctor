import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../../data/repositories/stock_sync_repository.dart';

final _apiKeysProvider = FutureProvider.autoDispose<List<ApiKeyInfo>>(
  (ref) => ref.watch(stockSyncRepositoryProvider).apiKeys(),
);

/// For pharmacies with their own system (ERP / point of sale): a key their
/// system uses to send stock levels to GoDoctor, so the app always shows
/// what's really on the shelf.
class ConnectSystemScreen extends ConsumerWidget {
  const ConnectSystemScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final label = await showDialog<String>(
      context: context,
      builder: (_) => const _LabelDialog(),
    );
    if (label == null || !context.mounted) return;
    try {
      final key = await ref
          .read(stockSyncRepositoryProvider)
          .createApiKey(label);
      ref.invalidate(_apiKeysProvider);
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _NewKeyDialog(apiKey: key),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    ApiKeyInfo key,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect this system?'),
        content: Text(
          '"${key.label}" will stop updating your stock. You can connect it '
          'again with a new key.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(stockSyncRepositoryProvider).revokeApiKey(key.id);
      ref.invalidate(_apiKeysProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final keys = ref.watch(_apiKeysProvider);
    final url = ref.watch(stockSyncRepositoryProvider).syncUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('Connect your system')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            'Keep your stock in sync automatically',
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'If your pharmacy uses a stock or point-of-sale system, it can '
            'send its stock levels to GoDoctor. Give your system provider '
            'a connection key and the details below.',
            style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Text('Connection keys', style: text.titleMedium)),
              FilledButton.tonalIcon(
                icon: const Icon(LucideIcons.keyRound, size: 16),
                label: const Text('New key'),
                onPressed: () => _create(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 10),
          keys.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ErrorView(
              message: friendlyError(e),
              onRetry: () => ref.invalidate(_apiKeysProvider),
            ),
            data: (list) {
              final active = list.where((k) => k.active).toList();
              if (active.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primarySofter,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'No systems connected yet. Create a key to connect one.',
                    style: text.bodyMedium,
                  ),
                );
              }
              return Column(
                children: [
                  for (final k in active)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(
                          LucideIcons.plugZap,
                          color: AppColors.success,
                        ),
                        title: Text(k.label),
                        subtitle: Text(
                          '${k.prefix}… · '
                          '${k.lastUsedAt == null ? 'Not used yet' : 'Last sync ${formatDateTime(k.lastUsedAt!)}'}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Disconnect',
                          icon: const Icon(LucideIcons.trash2, size: 18),
                          onPressed: () => _revoke(context, ref, k),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text('For your system provider', style: text.titleMedium),
          const SizedBox(height: 8),
          _CodeBlock(label: 'Endpoint', code: 'POST $url', copy: url),
          const SizedBox(height: 10),
          const _CodeBlock(
            label: 'Headers',
            code:
                'Authorization: Bearer <connection key>\n'
                'Content-Type: application/json',
          ),
          const SizedBox(height: 10),
          const _CodeBlock(
            label: 'Body',
            code:
                '{\n'
                '  "items": [\n'
                '    { "name": "Panadol 500mg", "quantity": 240, "price": 5 },\n'
                '    { "name": "Amoxil 250mg", "quantity": 0, "price": 12 }\n'
                '  ]\n'
                '}',
          ),
          const SizedBox(height: 10),
          Text(
            'Send the full list or only what changed, up to 2,000 items per '
            'request. Names are matched to our catalogue; the reply lists '
            'anything we couldn\'t match. A quantity of 0 marks a medicine '
            'out of stock.',
            style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.label, required this.code, this.copy});

  final String label;
  final String code;
  final String? copy;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: text.labelSmall?.copyWith(
                    color: AppColors.inkFaint,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Copy',
                icon: const Icon(
                  LucideIcons.copy,
                  size: 16,
                  color: AppColors.inkFaint,
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: copy ?? code));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Copied')));
                },
              ),
            ],
          ),
          SelectableText(
            code,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Colors.white,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelDialog extends StatefulWidget {
  const _LabelDialog();

  @override
  State<_LabelDialog> createState() => _LabelDialogState();
}

class _LabelDialogState extends State<_LabelDialog> {
  final _label = TextEditingController(text: 'Pharmacy system');

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name this connection'),
      content: TextField(
        controller: _label,
        autofocus: true,
        maxLength: 60,
        decoration: const InputDecoration(hintText: 'e.g. Front desk POS'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _label.text.trim()),
          child: const Text('Create key'),
        ),
      ],
    );
  }
}

/// Shows a new key once, with a copy button.
class _NewKeyDialog extends StatelessWidget {
  const _NewKeyDialog({required this.apiKey});

  final String apiKey;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your connection key'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Copy it now and give it to your system provider. For your '
            'safety we can\'t show it again.',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primarySofter,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(
              apiKey,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(LucideIcons.copy, size: 16),
          label: const Text('Copy'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: apiKey));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Key copied')));
          },
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
