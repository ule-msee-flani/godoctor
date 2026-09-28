import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/billing.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../../services/live_updates.dart';

final paymentMethodsProvider = FutureProvider.autoDispose<List<PaymentMethod>>(
  (ref) => ref.watch(billingRepositoryProvider).methods(),
);

final _settingsProvider = FutureProvider.autoDispose<BillingSettings>(
  (ref) => ref.watch(billingRepositoryProvider).settings(),
);

final _historyProvider = FutureProvider.autoDispose<List<PaymentRecord>>((ref) {
  ref.watch(liveTick(LiveTable.payments));
  return ref.watch(billingRepositoryProvider).history();
});

/// Profile › Billing information: M-Pesa numbers and cards, payment
/// preferences and past payments.
class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      ref.invalidate(paymentMethodsProvider);
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
    final theme = Theme.of(context).textTheme;
    final methods = ref.watch(paymentMethodsProvider);
    final settings = ref.watch(_settingsProvider).valueOrNull;
    final history = ref.watch(_historyProvider);
    final repo = ref.read(billingRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Billing information')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('Payment methods', style: theme.titleMedium),
          const SizedBox(height: 10),
          methods.when(
            loading: () => const Skeleton(height: 64),
            error: (e, _) => ErrorView(message: friendlyError(e)),
            data: (list) => list.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'No payment methods yet. Add your M-Pesa number to pay faster.',
                      style: theme.bodyMedium,
                    ),
                  )
                : Column(
                    children: [
                      for (final m in list)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: m.isMpesa
                                    ? AppColors.successSoft
                                    : AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                m.isMpesa
                                    ? LucideIcons.smartphone
                                    : LucideIcons.creditCard,
                                size: 20,
                                color: m.isMpesa
                                    ? AppColors.success
                                    : AppColors.primary,
                              ),
                            ),
                            title: Text(m.title),
                            subtitle: m.subtitle == null
                                ? null
                                : Text(m.subtitle!),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (m.isDefault)
                                  const _Chip('Default', AppColors.primary),
                                PopupMenuButton<String>(
                                  tooltip: 'Options',
                                  onSelected: (v) => _run(
                                    context,
                                    ref,
                                    () => v == 'default'
                                        ? repo.setDefault(m.id)
                                        : repo.remove(m.id),
                                  ),
                                  itemBuilder: (_) => [
                                    if (!m.isDefault)
                                      const PopupMenuItem(
                                        value: 'default',
                                        child: Text('Make default'),
                                      ),
                                    const PopupMenuItem(
                                      value: 'remove',
                                      child: Text('Remove'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => const _AddMpesaDialog(),
                    );
                    if (ok == true) ref.invalidate(paymentMethodsProvider);
                  },
                  icon: const Icon(LucideIcons.smartphone, size: 18),
                  label: const Text('Add M-Pesa'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => const _AddCardDialog(),
                    );
                    if (ok == true) ref.invalidate(paymentMethodsProvider);
                  },
                  icon: const Icon(LucideIcons.creditCard, size: 18),
                  label: const Text('Add card'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(LucideIcons.lock, size: 14, color: AppColors.inkFaint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'We never store full card numbers or CVV codes, only the last 4 digits.',
                  style: theme.bodySmall,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),
          Text('Payment preferences', style: theme.titleMedium),
          const SizedBox(height: 6),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Pay with my default method'),
                  subtitle: const Text(
                    'Skip choosing a method each time you pay',
                  ),
                  value: settings?.payWithDefault ?? true,
                  onChanged: settings == null
                      ? null
                      : (v) async {
                          await repo.saveSettings(
                            payWithDefault: v,
                            emailReceipts: settings.emailReceipts,
                          );
                          ref.invalidate(_settingsProvider);
                        },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Email me receipts'),
                  value: settings?.emailReceipts ?? true,
                  onChanged: settings == null
                      ? null
                      : (v) async {
                          await repo.saveSettings(
                            payWithDefault: settings.payWithDefault,
                            emailReceipts: v,
                          );
                          ref.invalidate(_settingsProvider);
                        },
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          Text('Payment history', style: theme.titleMedium),
          const SizedBox(height: 10),
          history.when(
            loading: () => const Skeleton(height: 56),
            error: (e, _) => Text(friendlyError(e), style: theme.bodySmall),
            data: (list) => list.isEmpty
                ? Text('No payments yet.', style: theme.bodyMedium)
                : Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < list.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          ListTile(
                            dense: true,
                            leading: Icon(
                              list[i].consultationId != null
                                  ? LucideIcons.stethoscope
                                  : LucideIcons.pill,
                              size: 20,
                              color: AppColors.inkSoft,
                            ),
                            title: Text(list[i].what),
                            subtitle: Text(formatDateTime(list[i].createdAt)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatKes(list[i].amount),
                                  style: theme.titleSmall,
                                ),
                                if (list[i].isSimulated)
                                  Text('Test payment', style: theme.bodySmall)
                                else
                                  Text(list[i].status, style: theme.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

class _AddMpesaDialog extends ConsumerStatefulWidget {
  const _AddMpesaDialog();

  @override
  ConsumerState<_AddMpesaDialog> createState() => _AddMpesaDialogState();
}

class _AddMpesaDialogState extends ConsumerState<_AddMpesaDialog> {
  final _phone = TextEditingController();
  final _label = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _phone.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final phone = normalizeKenyanPhone(_phone.text);
    if (phone == null) {
      setState(() => _error = 'Enter a Safaricom number like 0712 345 678.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(billingRepositoryProvider)
          .addMpesa(
            phone: phone,
            label: _label.text.trim().isEmpty ? null : _label.text.trim(),
          );
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
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add M-Pesa number'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _phone,
          autofocus: true,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'M-Pesa number',
            hintText: '0712 345 678',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _label,
          decoration: const InputDecoration(
            labelText: 'Name it (optional)',
            hintText: 'e.g. My line, Mum\'s line',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: const Text('Save'),
      ),
    ],
  );
}

class _AddCardDialog extends ConsumerStatefulWidget {
  const _AddCardDialog();

  @override
  ConsumerState<_AddCardDialog> createState() => _AddCardDialogState();
}

class _AddCardDialogState extends ConsumerState<_AddCardDialog> {
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _label = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _number.dispose();
    _expiry.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final digits = _number.text.replaceAll(RegExp(r'\D'), '');
    final exp = RegExp(
      r'^(\d{1,2})\s*/\s*(\d{2}|\d{4})$',
    ).firstMatch(_expiry.text.trim());
    if (!isValidCardNumber(digits)) {
      setState(() => _error = 'That card number is not valid.');
      return;
    }
    final month = exp == null ? null : int.parse(exp.group(1)!);
    var year = exp == null ? null : int.parse(exp.group(2)!);
    if (year != null && year < 100) year += 2000;
    final now = DateTime.now();
    if (month == null ||
        month < 1 ||
        month > 12 ||
        year == null ||
        DateTime(year, month + 1).isBefore(DateTime(now.year, now.month))) {
      setState(() => _error = 'Enter a valid expiry date, like 08/28.');
      return;
    }
    setState(() => _saving = true);
    try {
      // Only the brand, last 4 digits and expiry leave this device.
      await ref
          .read(billingRepositoryProvider)
          .addCard(
            brand: cardBrandOf(digits),
            last4: digits.substring(digits.length - 4),
            expMonth: month,
            expYear: year,
            label: _label.text.trim().isEmpty ? null : _label.text.trim(),
          );
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
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add a card'),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _number,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
              LengthLimitingTextInputFormatter(23),
            ],
            decoration: const InputDecoration(
              labelText: 'Card number',
              prefixIcon: Icon(LucideIcons.creditCard, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _expiry,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              labelText: 'Expiry (MM/YY)',
              hintText: '08/28',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _label,
            decoration: const InputDecoration(labelText: 'Name it (optional)'),
          ),
          const SizedBox(height: 10),
          Text(
            'Only the last 4 digits are saved. No CVV is needed until card payments launch.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: const Text('Save'),
      ),
    ],
  );
}
