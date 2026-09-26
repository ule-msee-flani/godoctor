import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/settings_section.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/doctor_profile.dart';
import '../../../data/models/public_doctor.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../patient/profile/account_screen.dart'
    show showChangePasswordDialog;
import '../../support/rate_app_sheet.dart';

/// What patients see in the certified-doctor directory: photo, bio, fee,
/// languages, experience. Licence details and verification are separate.
class DoctorProfileEditScreen extends ConsumerWidget {
  const DoctorProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(currentDoctorProfileProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My public profile'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(LucideIcons.logOut),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: friendlyError(e)),
        data: (p) => p == null
            ? const ErrorView(message: 'Profile not found')
            : _Form(profile: p),
      ),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.profile});

  final DoctorProfile profile;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late final _bio = TextEditingController(text: widget.profile.bio);
  late final _fee = TextEditingController(
    text: widget.profile.consultationFee?.toStringAsFixed(0) ?? '',
  );
  late final _years = TextEditingController(
    text: widget.profile.yearsExperience?.toString() ?? '',
  );
  late String? _gender = widget.profile.gender;
  late final Set<String> _languages = {...widget.profile.languages};

  bool _saving = false;

  @override
  void dispose() {
    _bio.dispose();
    _fee.dispose();
    _years.dispose();
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _save() async {
    final fee = _fee.text.trim().isEmpty
        ? null
        : double.tryParse(_fee.text.trim());
    final years = _years.text.trim().isEmpty
        ? null
        : int.tryParse(_years.text.trim());
    if (_fee.text.trim().isNotEmpty && (fee == null || fee < 0)) {
      _toast('Enter the fee as a number, e.g. 1500');
      return;
    }
    if (_years.text.trim().isNotEmpty &&
        (years == null || years < 0 || years > 70)) {
      _toast('Years of experience must be between 0 and 70');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateDoctorPublicProfile(
            userId: widget.profile.userId,
            bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
            consultationFee: fee,
            languages: _languages.toList(),
            gender: _gender,
            yearsExperience: years,
          );
      ref.invalidate(currentDoctorProfileProvider);
      if (mounted) _toast('Profile saved');
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final email =
        ref.watch(authRepositoryProvider).currentAuthUser?.email ?? '';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!widget.profile.licenseVerified)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.info,
                      color: AppColors.warning,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You will appear in the patient directory once an admin has verified your licence.',
                        style: theme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                EditableAvatar(name: widget.profile.name, radius: 44),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.profile.name, style: theme.titleLarge),
                      if (email.isNotEmpty)
                        Text(email, style: theme.bodyMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Tap your photo to change it. Patients see it in the directory.',
                        style: theme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _bio,
              maxLines: 5,
              maxLength: 600,
              decoration: const InputDecoration(
                labelText: 'About you',
                hintText: 'Your background, approach, and what you treat',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _fee,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Consultation fee (KES)',
                      prefixIcon: Icon(LucideIcons.banknote, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _years,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Years of experience',
                      prefixIcon: Icon(LucideIcons.briefcaseMedical, size: 18),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Gender', style: theme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final (value, label) in const <(String?, String)>[
                  ('female', 'Female'),
                  ('male', 'Male'),
                  ('other', 'Other'),
                  (null, 'Prefer not to say'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _gender == value,
                    onSelected: (_) => setState(() => _gender = value),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Languages you consult in', style: theme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final lang in kDoctorLanguages)
                  FilterChip(
                    label: Text(lang),
                    selected: _languages.contains(lang),
                    onSelected: (sel) => setState(() {
                      sel ? _languages.add(lang) : _languages.remove(lang);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save profile'),
            ),
            SettingsSection(
              title: 'Account',
              children: [
                SettingsTile(
                  icon: LucideIcons.headset,
                  title: 'Support & feedback',
                  subtitle: 'Get help, report a problem, send feedback',
                  onTap: () => context.push('/account/support'),
                ),
                SettingsTile(
                  icon: LucideIcons.bellRing,
                  title: 'Notifications',
                  subtitle: 'What GoDoctor alerts you about',
                  onTap: () => context.push('/account/notifications'),
                ),
                SettingsTile(
                  icon: LucideIcons.star,
                  title: 'Rate GoDoctor',
                  onTap: () => showRateAppSheet(context),
                ),
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
