import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;

  bool _isRegister = false;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isRegister) {
        final result = await _auth.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
        );
        await result.user
            ?.updateDisplayName(_nameCtrl.text.trim());
      } else {
        await _auth.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
        );
      }
      if (mounted) context.go('/home');
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyError(e.code));
    } catch (e) {
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _auth.signInAnonymously();
      await result.user?.updateDisplayName('Guest');
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _error = 'Guest sign-in failed. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _isRegister = !_isRegister;
      _error = null;
    });
    _animController
      ..reset()
      ..forward();
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return 'Something went wrong. Try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Header ─────────────────────────────────────
                      const Center(
                        child: Text('🎵',
                            style: TextStyle(fontSize: 52)),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          'SongCatcher',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                            color: Colors.purpleAccent,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          _isRegister
                              ? 'Create your account'
                              : 'Welcome back!',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 36),

                      // ── Error banner ────────────────────────────────
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.redAccent,
                                  size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Name field (register only) ──────────────────
                      if (_isRegister) ...[
                        TextFormField(
                          controller: _nameCtrl,
                          textCapitalization:
                          TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Display Name',
                            prefixIcon:
                            Icon(Icons.person_outline),
                          ),
                          validator: (v) {
                            if (_isRegister &&
                                (v == null || v.trim().isEmpty)) {
                              return 'Enter a display name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Email ───────────────────────────────────────
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType:
                        TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon:
                          Icon(Icons.email_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter your email';
                          }
                          if (!v.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // ── Password ────────────────────────────────────
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon:
                          const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons
                                  .visibility_off_outlined,
                            ),
                            onPressed: () => setState(() =>
                            _obscurePassword =
                            !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Enter your password';
                          }
                          if (_isRegister && v.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // ── Submit button ───────────────────────────────
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.purpleAccent,
                          padding: const EdgeInsets.symmetric(
                              vertical: 16),
                        ),
                        child: _loading
                            ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                            : Text(
                          _isRegister
                              ? 'Create Account'
                              : 'Sign In',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Toggle register/login ───────────────────────
                      Center(
                        child: TextButton(
                          onPressed:
                          _loading ? null : _toggleMode,
                          child: Text(
                            _isRegister
                                ? 'Already have an account? Sign In'
                                : "Don't have an account? Register",
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ── Divider ─────────────────────────────────────
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 14),
                            child: Text('or',
                                style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 13)),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Guest button ────────────────────────────────
                      OutlinedButton.icon(
                        onPressed:
                        _loading ? null : _continueAsGuest,
                        icon: const Icon(
                            Icons.person_outline,
                            size: 18),
                        label:
                        const Text('Continue as Guest'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 10),

                      const Center(
                        child: Text(
                          'Guest progress is not saved between sessions.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}