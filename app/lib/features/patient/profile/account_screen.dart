import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/settings_section.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/billing.dart';
import '../../../data/models/patient_profile.dart';
import '../../../data/models/support.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';

/// Profile › User profile: photo, personal details, contact info and
/// account settings.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentPatientProfileProvider);
    final user = ref.watch(currentAppUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('User profile')),
      body: switch ((profile, user)) {
        (AsyncData(value: final p?), AsyncData(value: final u)) => _Form(
          profile: p,
          contactPhone: u?.contactPhone,
        ),
        (AsyncError(:final error), _) || (_, AsyncError(:final error)) =>
          ErrorView(message: friendlyError(error)),
        (AsyncData(value: null), _) => const ErrorView(
          message: 'Your profile could not be loaded.',
        ),
        _ => const LoadingView(),
      },
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.profile, required this.contactPhone});

  final PatientProfile profile;
  final String? contactPhone;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late final _name = TextEditingController(text: widget.profile.name);
  late final _phone = TextEditingController(
    text: widget.contactPhone == null
        ? ''
        : formatKenyanPhone(widget.contactPhone!),
  );
  late final _emName = TextEditingController(
    text: widget.profile.emergencyContactName,
  );
  late final _emPhone = TextEditingController(
    text: widget.profile.emergencyContactPhone == null
        ? ''
        : formatKenyanPhone(widget.profile.emergencyContactPhone!),
  );
  late DateTime? _dob = widget.profile.dateOfBirth;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _emName, _emPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  /// Empty is fine; anything else must be a Kenyan mobile number.
  (bool ok, String? value) _phoneField(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return (true, null);
    final n = normalizeKenyanPhone(t);
    return (n != null, n);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return _toast('Please enter your name.');
    final (phoneOk, phone) = _phoneField(_phone);
    final (emOk, emPhone) = _phoneField(_emPhone);
    if (!phoneOk || !emOk) {
      return _toast('Enter phone numbers like 0712 345 678.');
    }
    final p = widget.profile;
    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updatePatientProfile(
            PatientProfile(
              userId: p.userId,
              name: name,
              dateOfBirth: _dob,
              locationLat: p.locationLat,
              locationLng: p.locationLng,
              locationName: p.locationName,
              locationDetails: p.locationDetails,
              allergies: p.allergies,
              currentMedications: p.currentMedications,
              chronicConditions: p.chronicConditions,
              bloodGroup: p.bloodGroup,
              heightCm: p.heightCm,
              weightKg: p.weightKg,
              emergencyContactName: _emName.text.trim().isEmpty
                  ? null
                  : _emName.text.trim(),
              emergencyContactPhone: emPhone,
            ),
          );
      await ref
          .read(profileRepositoryProvider)
          .updateContactPhone(p.userId, phone);
      ref.invalidate(currentPatientProfileProvider);
      ref.invalidate(currentAppUserProvider);
      if (mounted) _toast('Saved');
    } catch (e) {
      if (mounted) _toast('Could not save: ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final authUser = ref.watch(authRepositoryProvider).currentAuthUser;
    final email = authUser?.email ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Center(
          child: EditableAvatar(
            name: _name.text.isEmpty ? '?' : _name.text,
            radius: 46,
          ),
        ),
        const SizedBox(height: 6),
        Center(child: Text('Tap to change photo', style: theme.bodySmall)),

        _Heading(icon: LucideIcons.userRound, text: 'Personal details'),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Full name'),
        ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _pickDob,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Date of birth',
              suffixIcon: Icon(LucideIcons.calendar, size: 18),
            ),
            child: Text(
              _dob == null ? 'Not set' : formatDate(_dob!),
              style: theme.bodyLarge?.copyWith(
                color: _dob == null ? AppColors.inkFaint : AppColors.ink,
              ),
            ),
          ),
        ),

        _Heading(icon: LucideIcons.phone, text: 'Contact info'),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Email',
            helperText: 'Used to sign in',
            suffixIcon: Icon(LucideIcons.lock, size: 16),
          ),
          child: Text(email.isEmpty ? '—' : email, style: theme.bodyLarge),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: '0712 345 678',
          ),
        ),
        const SizedBox(height: 16),
        Text('Emergency contact', style: theme.titleSmall),
        Text(
          'Someone we can suggest you call if a consultation shows an emergency.',
          style: theme.bodySmall,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _emName,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emPhone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: '0712 345 678',
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save changes'),
        ),

        SettingsSection(
          title: 'Account settings',
          children: [
            if (email.isNotEmpty)
              SettingsTile(
                icon: LucideIcons.keyRound,
                title: 'Change password',
                onTap: () => showChangePasswordDialog(context, ref),
              ),
            SettingsTile(
              icon: LucideIcons.logOut,
              title: 'Sign out',
              onTap: () => ref.read(authRepositoryProvider).signOut(),
            ),
            SettingsTile(
              icon: LucideIcons.trash2,
              title: 'Delete my account',
              subtitle: 'Ask support to delete your account and data',
              onTap: () => requestAccountDeletion(context, ref),
            ),
          ],
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.ink),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

/// Shared by every role's account page.
Future<void> showChangePasswordDialog(BuildContext context, WidgetRef ref) {
  final a = TextEditingController();
  final b = TextEditingController();
  String? error;
  var saving = false;
  return showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: a,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: b,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Repeat it'),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(color: AppColors.danger)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    if (a.text.length < 8) {
                      return setState(
                        () => error = 'Use at least 8 characters.',
                      );
                    }
                    if (a.text != b.text) {
                      return setState(() => error = 'The passwords differ.');
                    }
                    setState(() => saving = true);
                    try {
                      await ref
                          .read(authRepositoryProvider)
                          .changePassword(a.text);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password changed')),
                        );
                      }
                    } catch (e) {
                      setState(() {
                        error = friendlyError(e);
                        saving = false;
                      });
                    }
                  },
            child: const Text('Change'),
          ),
        ],
      ),
    ),
  );
}

/// Opens an account-deletion request with support (deleting an account and
/// its medical records is done by staff, not instantly).
Future<void> requestAccountDeletion(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete your account?'),
      content: const Text(
        'We will send a deletion request to our support team. They will '
        'confirm with you, then delete your account and personal data. '
        'Records the law requires us to keep (such as prescriptions) are '
        'kept for the required period only.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Keep my account'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Send request'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    final id = await ref
        .read(supportRepositoryProvider)
        .create(
          kind: SupportKind.accountDeletion,
          subject: 'Please delete my account',
          message: 'I would like my GoDoctor account and data deleted.',
        );
    if (context.mounted) context.push('/account/support/$id');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}
