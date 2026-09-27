import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';
import '../../../data/providers/repository_providers.dart';
import '../widgets/auth_hero.dart';

/// Log in or register (email and password) as a patient, doctor or chemist,
/// under a photo for that kind of account.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, required this.role});

  final UserRole role;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isRegistering = false;
  bool _showPassword = false;
  bool _loading = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  ({String image, Alignment alignment, String label}) get _role =>
      switch (widget.role) {
        UserRole.patient => (
          image: 'assets/images/auth/role_patient',
          alignment: const Alignment(0.2, -0.2),
          label: 'patient',
        ),
        UserRole.doctor => (
          image: 'assets/images/auth/role_doctor',
          alignment: const Alignment(0, -0.55),
          label: 'doctor',
        ),
        UserRole.chemist => (
          image: 'assets/images/auth/role_chemist',
          alignment: const Alignment(0.1, -0.3),
          label: 'chemist',
        ),
        UserRole.admin => (
          image: 'assets/images/auth/auth_hero',
          alignment: Alignment.center,
          label: 'admin',
        ),
      };

  /// Supabase's messages, in plain words.
  static String _friendly(Object e) {
    final msg = e is AuthException ? e.message : e.toString();
    final m = msg.toLowerCase();
    if (m.contains('invalid login credentials')) {
      return 'That email and password don\'t match. Check them and try again.';
    }
    if (m.contains('email not confirmed')) {
      return 'Please confirm your email first. Check your inbox for the link we sent.';
    }
    if (m.contains('already registered') || m.contains('already exists')) {
      return 'An account with this email already exists. Log in instead.';
    }
    if (m.contains('password should be at least') ||
        m.contains('weak password')) {
      return 'Choose a stronger password: at least 6 characters.';
    }
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'Too many attempts. Please wait a minute and try again.';
    }
    if (m.contains('socket') ||
        m.contains('network') ||
        m.contains('failed host lookup')) {
      return 'No internet connection. Check your data or Wi-Fi and try again.';
    }
    return msg;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });
    final auth = ref.read(authRepositoryProvider);
    try {
      if (_isRegistering) {
        final mustConfirm = await auth.signUpWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          role: widget.role,
          name: _nameCtrl.text.trim(),
        );
        if (mustConfirm) {
          if (mounted) {
            setState(() {
              _loading = false;
              _isRegistering = false;
              _notice =
                  'Account created. We sent a link to ${_emailCtrl.text.trim()}: '
                  'confirm your email, then log in.';
            });
          }
          return;
        }
      } else {
        await auth.signInWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
      }
      // Signed in: the router moves on by itself as soon as the account has
      // loaded. Keep the spinner until then so it isn't tapped again (but
      // never forever).
      Future<void>.delayed(const Duration(seconds: 10), () {
        if (mounted) setState(() => _loading = false);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _friendly(e);
        });
      }
    }
  }

  InputDecoration _field(String label, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(icon, size: 20),
        ),
        suffixIcon: suffix,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final role = _role;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/auth');
      },
      child: AuthHeroScaffold(
        image: role.image,
        alignment: role.alignment,
        heightFactor: 0.40,
        onBack: () => context.go('/auth'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isRegistering ? 'Create your account' : 'Welcome back',
                    textAlign: TextAlign.center,
                    style: theme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_isRegistering ? 'Register' : 'Log in'} as a ${role.label}',
                    textAlign: TextAlign.center,
                    style: theme.bodyMedium,
                  ),
                  const SizedBox(height: 22),
                  if (_isRegistering) ...[
                    TextFormField(
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      decoration: _field(
                        widget.role == UserRole.chemist
                            ? 'Pharmacy name'
                            : 'Full name',
                        LucideIcons.idCard,
                      ),
                      validator: (v) => (v ?? '').trim().length < 2
                          ? 'Enter your name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    decoration: _field('Email', LucideIcons.mail),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return 'Enter your email';
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                        return 'That doesn\'t look like an email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: !_showPassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: [
                      _isRegistering
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    onFieldSubmitted: (_) => _loading ? null : _submit(),
                    decoration: _field(
                      'Password',
                      LucideIcons.lockKeyhole,
                      suffix: IconButton(
                        tooltip: _showPassword
                            ? 'Hide password'
                            : 'Show password',
                        icon: Icon(
                          _showPassword ? LucideIcons.eyeOff : LucideIcons.eye,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                    validator: (v) {
                      if ((v ?? '').isEmpty) return 'Enter your password';
                      if (_isRegistering && v!.length < 6) {
                        return 'Use at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isRegistering ? 'Create account' : 'Log in'),
                  ),
                  if (_error != null)
                    _Banner(
                      text: _error!,
                      icon: LucideIcons.circleAlert,
                      fg: AppColors.danger,
                      bg: AppColors.dangerSoft,
                    ),
                  if (_notice != null)
                    _Banner(
                      text: _notice!,
                      icon: LucideIcons.mailCheck,
                      fg: AppColors.success,
                      bg: AppColors.successSoft,
                    ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                            _isRegistering = !_isRegistering;
                            _error = null;
                            _notice = null;
                          }),
                    child: Text(
                      _isRegistering
                          ? 'Already have an account? Log in'
                          : 'New here? Create an account',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.text,
    required this.icon,
    required this.fg,
    required this.bg,
  });

  final String text;
  final IconData icon;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: TextStyle(color: AppColors.ink)),
            ),
          ],
        ),
      ),
    );
  }
}
