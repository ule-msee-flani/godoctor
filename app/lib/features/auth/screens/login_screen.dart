import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/auth'),
        ),
        title: Text(
          '${_isRegistering ? 'Register' : 'Log in'} as $_roleLabel',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<_Method>(
                segments: const [
                  ButtonSegment(
                    value: _Method.phone,
                    label: Text('Phone (OTP)'),
                    icon: Icon(Icons.phone_android),
                  ),
                  ButtonSegment(
                    value: _Method.email,
                    label: Text('Email'),
                    icon: Icon(Icons.email_outlined),
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
                  ),
                ),
                if (_otpSent) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _otpCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Enter the code we sent you',
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_otpSent ? 'Verify code' : 'Send code'),
                ),
              ] else ...[
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : _emailSubmit,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isRegistering ? 'Create account' : 'Log in'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
