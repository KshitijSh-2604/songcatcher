import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../utils/responsive.dart';
import '../../models/app_user.dart';
import '../../providers/user_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;

  bool _isRegister = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      if (_isRegister) {
        final email = _emailCtrl.text.trim();
        final phone = _phoneCtrl.text.trim();

        // Check uniqueness before creating auth user
        final isUnique = await ref.read(userServiceProvider).isEmailUnique(email);
        if (!isUnique) {
          if (mounted) {
            setState(() {
              _error = 'An account already exists with this email.';
              _loading = false;
            });
          }
          return;
        }

        if (phone.isNotEmpty) {
          final isPhoneUnique = await ref.read(userServiceProvider).isPhoneNumberUnique(phone);
          if (!isPhoneUnique) {
            if (mounted) {
              setState(() {
                _error = 'This phone number is already linked to another account.';
                _loading = false;
              });
            }
            return;
          }
        }

        final result = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: _passwordCtrl.text.trim(),
        );
        final displayName = _nameCtrl.text.trim();
        await result.user?.updateDisplayName(displayName);
        if (result.user != null) {
          final newUser = AppUser(
            uid: result.user!.uid,
            displayName: displayName,
            email: email,
            phoneNumber: phone.isNotEmpty ? phone : null,
            createdAt: DateTime.now(),
            avatarConfig: AvatarConfig.random().toMap(),
          );
          await ref.read(userServiceProvider).createUser(newUser);
        }
      } else {
        await _auth.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
        );
      }
      if (_isRegister) {
        if (mounted) context.go('/profile');
      } else {
        if (mounted) context.go('/home');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Authentication failed.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _auth.signInAnonymously();
      const displayName = 'Guest';
      await result.user?.updateDisplayName(displayName);
      if (result.user != null) {
        final newUser = AppUser(
          uid: result.user!.uid,
          displayName: displayName,
          createdAt: DateTime.now(),
          avatarConfig: AvatarConfig.random().toMap(),
        );
        await ref.read(userServiceProvider).createUser(newUser);
      }
      if (mounted) context.go('/home');
    } catch (_) {
      if (mounted) setState(() => _error = 'Guest sign-in failed.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageShell(
      showHeader: false,
      showSidebar: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: NeubrutalistContainer(
            color: Colors.white,
            borderWidth: 4,
            shadowOffset: 8,
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Text(
                      'SongCatcher',
                      style: TextStyle(
                        fontFamily: 'Bricolage Grotesque',
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0001BB),
                      ),
                    ),
                  ),
                  const Gap(8),
                  Center(
                    child: Text(
                      _isRegister ? 'Join the Arena' : 'Welcome Back!',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).hintColor),
                    ),
                  ),
                  const Gap(32),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          border: Border.all(color: Colors.red, width: 2),
                        ),
                        child: Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  if (_isRegister) ...[
                    const Text('Display Name', style: TextStyle(fontWeight: FontWeight.w800)),
                    const Gap(8),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(hintText: 'e.g. NeonNinja'),
                      validator: (v) => v!.isEmpty ? 'Enter a name' : null,
                    ),
                    const Gap(20),
                    const Text('Phone Number', style: TextStyle(fontWeight: FontWeight.w800)),
                    const Gap(8),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(hintText: '+91 98765 43210'),
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter phone number';
                        if (!v.startsWith('+')) return 'Include country code (e.g. +91)';
                        return null;
                      },
                    ),
                    const Gap(20),
                  ],
                  const Text('Email', style: TextStyle(fontWeight: FontWeight.w800)),
                  const Gap(8),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(hintText: 'you@example.com'),
                    validator: (v) => !v!.contains('@') ? 'Invalid email' : null,
                  ),
                  const Gap(20),
                  const Text('Password', style: TextStyle(fontWeight: FontWeight.w800)),
                  const Gap(8),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: '••••••••'),
                    validator: (v) => v!.length < 6 ? 'Too short' : null,
                  ),
                  const Gap(32),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else
                    NeubrutalistButton(
                      label: _isRegister ? 'CREATE ACCOUNT' : 'SIGN IN',
                      color: const Color(0xFF0001BB),
                      textColor: Colors.white,
                      onPressed: _submit,
                    ),
                  const Gap(16),
                  TextButton(
                    onPressed: () => setState(() => _isRegister = !_isRegister),
                    child: Text(_isRegister ? 'Already have an account? Sign In' : 'No account? Create one!'),
                  ),
                  const Gap(12),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('OR', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const Gap(24),
                  NeubrutalistButton(
                    label: 'CONTINUE AS GUEST',
                    color: const Color(0xFFFFFF00),
                    onPressed: _continueAsGuest,
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
