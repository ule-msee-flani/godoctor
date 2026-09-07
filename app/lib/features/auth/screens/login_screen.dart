import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';
import '../../../data/providers/repository_providers.dart';

enum _Method { phone, email }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, required this.role});

  final UserRole role;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  _Method _method = _Method.phone;
  bool _isRegistering = false;
  bool _otpSent = false;
  bool _loading = false;
  String? _error;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  ({IconData icon, Color color}) get _roleBrand => switch (widget.role) {
    UserRole.patient => (icon: LucideIcons.user, color: AppColors.primary),
    UserRole.doctor => (
      icon: LucideIcons.stethoscope,
      color: AppColors.accentTeal,
    ),
    UserRole.chemist => (icon: LucideIcons.pill, color: AppColors.primaryDark),
    UserRole.admin => (icon: LucideIcons.shieldCheck, color: AppColors.ink),
  };

  String get _roleLabel => switch (widget.role) {
    UserRole.patient => 'patient',
    UserRole.doctor => 'doctor',
    UserRole.chemist => 'chemist',
    UserRole.admin => 'admin',
  };

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendOtp() async {
    final auth = ref.read(authRepositoryProvider);
    await _run(
      () => auth.requestPhoneOtp(
        phone: _phoneCtrl.text.trim(),
        role: _isRegistering ? widget.role : null,
        name: _isRegistering ? _nameCtrl.text.trim() : null,
      ),
    );
    if (mounted && _error == null) setState(() => _otpSent = true);
  }

  Future<void> _verifyOtp() async {
    final auth = ref.read(authRepositoryProvider);
    await _run(
      () => auth.verifyPhoneOtp(
        phone: _phoneCtrl.text.trim(),
        otp: _otpCtrl.text.trim(),
      ),
    );
    // On success the router's redirect (driven by auth state) takes over.
  }

  Future<void> _emailSubmit() async {
    final auth = ref.read(authRepositoryProvider);
    if (_isRegistering) {
      await _run(
        () => auth.signUpWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          role: widget.role,
          name: _nameCtrl.text.trim(),
        ),
      );
    } else {
      await _run(
        () => auth.signInWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = _roleBrand;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.white,
                      foregroundColor: AppColors.ink,
                      side: const BorderSide(color: AppColors.border),
                    ),
                    icon: const Icon(LucideIcons.arrowLeft),
                    onPressed: () => context.go('/auth'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: brand.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Icon(brand.icon, color: brand.color, size: 28),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isRegistering ? 'Create your account' : 'Welcome back',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${_isRegistering ? 'Register' : 'Log in'} as $_roleLabel',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              SegmentedButton<_Method>(
                segments: const [
                  ButtonSegment(
                    value: _Method.phone,
                    label: Text('Phone (OTP)'),
                    icon: Icon(LucideIcons.smartphone, size: 16),
                  ),
                  ButtonSegment(
                    value: _Method.email,
                    label: Text('Email'),
                    icon: Icon(LucideIcons.mail, size: 16),
                  ),
                ],
                selected: {_method},
                onSelectionChanged: (s) => setState(() {
                  _method = s.first;
                  _otpSent = false;
                  _error = null;
                }),
              ),
              const SizedBox(height: 24),
              if (_isRegistering)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: widget.role == UserRole.chemist
                          ? 'Business name'
                          : 'Full name',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(14),
                        child: Icon(LucideIcons.idCard, size: 20),
                      ),
                    ),
                  ),
                ),
              if (_method == _Method.phone) ...[
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  enabled: !_otpSent,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    hintText: '+2547XXXXXXXX',
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(14),
                      child: Icon(LucideIcons.smartphone, size: 20),
                    ),
                  ),
                ),
                if (_otpSent) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _otpCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Enter the code we sent you',
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(14),
                        child: Icon(LucideIcons.lockKeyhole, size: 20),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading
                      ? null
                      : (_otpSent ? _verifyOtp : _sendOtp),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_otpSent ? 'Verify code' : 'Send code'),
                ),
              ] else ...[
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(14),
                      child: Icon(LucideIcons.mail, size: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(14),
                      child: Icon(LucideIcons.lockKeyhole, size: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : _emailSubmit,
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
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.circleAlert,
                        color: AppColors.danger,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() {
                  _isRegistering = !_isRegistering;
                  _otpSent = false;
                  _error = null;
                }),
                child: Text(
                  _isRegistering
                      ? 'Already have an account? Log in'
                      : 'New here? Register',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
