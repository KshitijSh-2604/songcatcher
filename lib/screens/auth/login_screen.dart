import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/responsive.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl     = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  final _auth         = FirebaseAuth.instance;

  bool    _isRegister      = false;
  bool    _loading         = false;
  bool    _obscurePassword = true;
  String? _error;

  late final AnimationController _animController;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeIn);
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
    setState(() { _loading = true; _error = null; });
    try {
      if (_isRegister) {
        final result = await _auth.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
        );
        await result.user?.updateDisplayName(_nameCtrl.text.trim());
      } else {
        await _auth.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
        );
      }
      if (mounted) context.go('/home');
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyError(e.code));
    } catch (_) {
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _auth.signInAnonymously();
      await result.user?.updateDisplayName('Guest');
      if (mounted) context.go('/home');
    } catch (_) {
      setState(() => _error = 'Guest sign-in failed. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleMode() {
    setState(() { _isRegister = !_isRegister; _error = null; });
    _animController..reset()..forward();
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':        return 'No account found with that email.';
      case 'wrong-password':
      case 'invalid-credential':    return 'Incorrect email or password.';
      case 'email-already-in-use':  return 'An account already exists with this email.';
      case 'weak-password':         return 'Password must be at least 6 characters.';
      case 'invalid-email':         return 'Please enter a valid email address.';
      case 'too-many-requests':     return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':return 'No internet connection.';
      default:                      return 'Something went wrong. Try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth  = context.fw(360, max: 460);
    // Available height after SafeArea insets — used as minHeight so Center
    // can actually center when content is shorter than the screen.
    final safeHeight = MediaQuery.of(context).size.height
        - MediaQuery.of(context).padding.top
        - MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: SafeArea(
        // SingleChildScrollView always present so the keyboard can push
        // content up on small screens without overflow.
        // ConstrainedBox(minHeight) makes the inner Center fill the
        // viewport when the form is smaller than the screen, giving
        // true vertical centering on large screens without any scrolling.
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: safeHeight),
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: cardWidth),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.fs(20, max: 32),
                      vertical:   context.fs(24, max: 40),
                    ),
                    child: _FormContent(
                      formKey:         _formKey,
                      emailCtrl:       _emailCtrl,
                      passwordCtrl:    _passwordCtrl,
                      nameCtrl:        _nameCtrl,
                      isRegister:      _isRegister,
                      loading:         _loading,
                      error:           _error,
                      obscurePassword: _obscurePassword,
                      onSubmit:        _submit,
                      onToggleMode:    _toggleMode,
                      onGuestLogin:    _continueAsGuest,
                      onToggleObscure: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
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

// ── Form content ──────────────────────────────────────────────────────────────

class _FormContent extends StatelessWidget {
  final GlobalKey<FormState>      formKey;
  final TextEditingController     emailCtrl;
  final TextEditingController     passwordCtrl;
  final TextEditingController     nameCtrl;
  final bool    isRegister;
  final bool    loading;
  final String? error;
  final bool    obscurePassword;
  final VoidCallback onSubmit;
  final VoidCallback onToggleMode;
  final VoidCallback onGuestLogin;
  final VoidCallback onToggleObscure;

  const _FormContent({
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.nameCtrl,
    required this.isRegister,
    required this.loading,
    required this.error,
    required this.obscurePassword,
    required this.onSubmit,
    required this.onToggleMode,
    required this.onGuestLogin,
    required this.onToggleObscure,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Branding ───────────────────────────────────────────────
          Center(child: Text('🎵', style: TextStyle(fontSize: context.ff(44, max: 60)))),
          Gap(context.fs(8, max: 12)),
          Center(
            child: Text(
              'SongCatcher',
              style: TextStyle(
                color: Colors.purpleAccent,
                fontWeight: FontWeight.w900,
                fontSize: context.ff(26, max: 36),
              ),
            ),
          ),
          Gap(context.fs(4, max: 8)),
          Center(
            child: Text(
              isRegister ? 'Create your account' : 'Welcome back!',
              style: TextStyle(
                  color: Colors.white54, fontSize: context.ff(13, max: 15)),
            ),
          ),
          Gap(context.fs(28, max: 44)),

          // ── Error banner ────────────────────────────────────────────
          if (error != null) ...[
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: context.fs(12, max: 16),
                  vertical:   context.fs(9, max: 12)),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(children: [
                Icon(Icons.error_outline,
                    color: Colors.redAccent, size: context.ff(15, max: 18)),
                SizedBox(width: context.fs(7, max: 10)),
                Expanded(
                  child: Text(error!,
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: context.ff(12, max: 14))),
                ),
              ]),
            ),
            Gap(context.fs(14, max: 20)),
          ],

          // ── Name (register only) ────────────────────────────────────
          if (isRegister) ...[
            TextFormField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(fontSize: context.ff(14, max: 16)),
              decoration: const InputDecoration(
                labelText: 'Display Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) {
                if (isRegister && (v == null || v.trim().isEmpty)) {
                  return 'Enter a display name';
                }
                return null;
              },
            ),
            Gap(context.fs(12, max: 18)),
          ],

          // ── Email ───────────────────────────────────────────────────
          TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(fontSize: context.ff(14, max: 16)),
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter your email';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          Gap(context.fs(12, max: 18)),

          // ── Password ────────────────────────────────────────────────
          TextFormField(
            controller: passwordCtrl,
            obscureText: obscurePassword,
            onFieldSubmitted: (_) => onSubmit(),
            style: TextStyle(fontSize: context.ff(14, max: 16)),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: onToggleObscure,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter your password';
              if (isRegister && v.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          Gap(context.fs(20, max: 30)),

          // ── Submit ──────────────────────────────────────────────────
          FilledButton(
            onPressed: loading ? null : onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              padding:
              EdgeInsets.symmetric(vertical: context.fs(14, max: 18)),
            ),
            child: loading
                ? SizedBox(
              width:  context.ff(18, max: 22),
              height: context.ff(18, max: 22),
              child: const CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
                : Text(
              isRegister ? 'Create Account' : 'Sign In',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: context.ff(14, max: 16)),
            ),
          ),
          Gap(context.fs(10, max: 14)),

          // ── Toggle mode ─────────────────────────────────────────────
          Center(
            child: TextButton(
              onPressed: loading ? null : onToggleMode,
              child: Text(
                isRegister
                    ? 'Already have an account? Sign In'
                    : "Don't have an account? Register",
                style: TextStyle(fontSize: context.ff(12, max: 14)),
              ),
            ),
          ),
          Gap(context.fs(6, max: 10)),

          // ── Divider ─────────────────────────────────────────────────
          Row(children: [
            const Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: context.fs(12, max: 16)),
              child: Text('or',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: context.ff(12, max: 14))),
            ),
            const Expanded(child: Divider()),
          ]),
          Gap(context.fs(10, max: 14)),

          // ── Guest ────────────────────────────────────────────────────
          OutlinedButton.icon(
            onPressed: loading ? null : onGuestLogin,
            icon: Icon(Icons.person_outline, size: context.ff(16, max: 20)),
            label: Text('Continue as Guest',
                style: TextStyle(fontSize: context.ff(13, max: 15))),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: context.fs(12, max: 16)),
            ),
          ),
          Gap(context.fs(8, max: 12)),

          Center(
            child: Text(
              'Guest progress is not saved between sessions.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white38, fontSize: context.ff(10, max: 12)),
            ),
          ),
        ],
      ),
    );
  }
}