import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  bool _verifyingEmail = false;
  String? _error;

  // Password condition flags
  bool _hasMinLength = false;
  bool _hasLowercase = false;
  bool _hasUppercase = false;
  bool _hasNumber = false;
  bool _hasSpecial = false;

  @override
  void initState() {
    super.initState();
    _passwordCtrl.addListener(_validatePassword);
  }

  void _validatePassword() {
    final v = _passwordCtrl.text;
    setState(() {
      _hasMinLength = v.length >= 12;
      _hasLowercase = v.contains(RegExp(r'[a-z]'));
      _hasUppercase = v.contains(RegExp(r'[A-Z]'));
      _hasNumber = v.contains(RegExp(r'[0-9]'));
      _hasSpecial = v.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  @override
  void dispose() {
    _passwordCtrl.removeListener(_validatePassword);
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final allowedDomains = ['@gmail.com', '@hotmail.com', '@yahoo.com'];
    final normalizedEmail = email.toLowerCase().trim();
    return allowedDomains.any((domain) => normalizedEmail.endsWith(domain));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_isRegister) {
      if (!_hasMinLength || !_hasLowercase || !_hasUppercase || !_hasNumber || !_hasSpecial) {
        setState(() => _error = 'Please fulfill all password requirements.');
        return;
      }
      if (!_isValidEmail(_emailCtrl.text.trim())) {
        setState(() => _error = 'Only Gmail, Hotmail, and Yahoo accounts are allowed.');
        return;
      }
    }

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
        
        final user = result.user;
        if (user != null) {
          final displayName = _nameCtrl.text.trim();
          await user.updateDisplayName(displayName);
          
          // Create the Firestore profile
          final newUser = AppUser(
            uid: user.uid,
            displayName: displayName,
            catcherId: 'CATCHER#0000', // Will be replaced by service
            email: email,
            phoneNumber: phone.isNotEmpty ? phone : null,
            lastSeen: DateTime.now(),
            createdAt: DateTime.now(),
            avatarConfig: AvatarConfig.random().toMap(),
          );
          await ref.read(userServiceProvider).createUser(newUser);

          // 🚨 MANDATORY EMAIL VERIFICATION
          await user.sendEmailVerification();
          setState(() {
            _verifyingEmail = true;
            _loading = false;
          });
          return; // Stop here and show verification UI
        }
      } else {
        final email = _emailCtrl.text.trim();
        
        try {
          // 🛡️ Attempt to fetch methods, but handle the "disabled API" error gracefully
          final methods = await _auth.fetchSignInMethodsForEmail(email);
          if (methods.contains('google.com')) {
            setState(() {
              _error = 'You previously signed in using Google. Please use the Google button to log in.';
              _loading = false;
            });
            return;
          }
        } catch (e) {
          // If fetchSignInMethodsForEmail is disabled (enumeration protection), 
          // we just continue to password login.
          debugPrint('Pre-check notice: $e');
        }

        final result = await _auth.signInWithEmailAndPassword(
          email: email,
          password: _passwordCtrl.text.trim(),
        );
        
        // If they are logging in but haven't verified their email yet
        if (result.user != null && !result.user!.emailVerified && !result.user!.isAnonymous) {
          await result.user!.sendEmailVerification();
          setState(() {
            _verifyingEmail = true;
            _loading = false;
          });
          return;
        }
      }

      if (_isRegister) {
        if (mounted) context.go('/profile');
      } else {
        if (mounted) context.go('/home');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg = e.message ?? 'Authentication failed.';
        
        // 🔍 If the credential fails, it might be because they need to use Google
        if (e.code == 'invalid-credential' || e.code == 'wrong-password') {
          msg = 'Incorrect password. If you originally joined via Google, please use the "Sign in with Google" button below.';
        }
        
        setState(() => _error = msg);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong.');
    } finally {
      if (mounted && !_verifyingEmail) setState(() => _loading = false);
    }
  }

  Future<void> _checkVerificationStatus() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    setState(() => _loading = true);
    await user.reload();
    
    if (user.emailVerified) {
      if (mounted) {
        setState(() {
          _verifyingEmail = false;
          _loading = false;
        });
        context.go('/profile');
      }
    } else {
      if (mounted) {
        setState(() {
          _error = 'Email not verified yet. Please check your inbox.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _loading = true; _error = null; });
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: kIsWeb ? '286054429599-vojcqf0uv5rao0r4gsitcmcou9i5ft1g.apps.googleusercontent.com' : null,
      );
      
      // 🌐 Try silent sign-in first for a better web experience
      GoogleSignInAccount? googleUser = await googleSignIn.signInSilently();
      googleUser ??= await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _loading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result = await _auth.signInWithCredential(credential);
      final user = result.user;

      if (user != null) {
        final existingProfile = await ref.read(userServiceProvider).getUser(user.uid);
        if (existingProfile == null) {
          final newUser = AppUser(
            uid: user.uid,
            displayName: user.displayName ?? 'Catcher',
            catcherId: 'CATCHER#0000',
            email: user.email,
            isEmailVerified: true, // 🛡️ Google emails are verified by default
            photoUrl: user.photoURL,
            lastSeen: DateTime.now(),
            createdAt: DateTime.now(),
            avatarConfig: AvatarConfig.random().toMap(),
          );
          await ref.read(userServiceProvider).createUser(newUser);
        }
        if (mounted) context.go('/home');
      }
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      if (mounted) {
        final errorStr = e.toString();
        // 🤫 Silently handle when user closes the popup manually
        if (errorStr.contains('popup_closed') || errorStr.contains('canceled')) {
          setState(() => _loading = false);
          return;
        }
        setState(() => _error = 'Google Sign-In failed: $e');
      }
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
          catcherId: 'CATCHER#0000',
          lastSeen: DateTime.now(),
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
    if (_verifyingEmail) return _buildVerificationUI();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // ── 1. Animated Background ─────────────────────────────────────────
          const Positioned.fill(child: GridBackground()),
          ...List.generate(15, (i) => _FloatingNote(index: i)),

          // ── 2. Main Content ────────────────────────────────────────────────
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // LOGO & TITLE
                    Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF0001BB), width: 4),
                            boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(6, 6))],
                          ),
                          child: ClipOval(
                            child: Image.asset('assets/images/logo1.png', fit: BoxFit.cover),
                          ),
                        ).animate()
                         .scale(duration: 600.ms, curve: Curves.elasticOut)
                         .rotate(begin: -0.1, end: 0, duration: 600.ms),
                        const SizedBox(height: 24),
                        Text(
                          'SONGCATCHER',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0001BB),
                            letterSpacing: -1,
                          ),
                        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                        const Text(
                          'THE ULTIMATE MUSIC ARENA',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 4,
                            color: Colors.black45,
                          ),
                        ).animate().fadeIn(delay: 400.ms),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // LOGIN/REGISTER CARD
                    NeubrutalistContainer(
                      color: Colors.white,
                      padding: const EdgeInsets.all(32),
                      shadowOffset: 10,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _isRegister ? 'JOIN THE ARENA' : 'WELCOME BACK',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),

                            if (_isRegister) ...[
                              _LoginTextField(controller: _nameCtrl, label: 'DISPLAY NAME', icon: Icons.person_outline),
                              const SizedBox(height: 16),
                              _LoginTextField(
                                controller: _phoneCtrl, 
                                label: 'PHONE NUMBER', 
                                icon: Icons.phone_android,
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 16),
                            ],
                            
                            _LoginTextField(controller: _emailCtrl, label: 'EMAIL ADDRESS', icon: Icons.email_outlined),
                            const SizedBox(height: 16),
                            _LoginTextField(controller: _passwordCtrl, label: 'PASSWORD', icon: Icons.lock_outline, isPassword: true),
                            
                            if (_isRegister) ...[
                              const Gap(12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  _PasswordRequirement(label: '12+ chars', isMet: _hasMinLength),
                                  _PasswordRequirement(label: 'number', isMet: _hasNumber),
                                  _PasswordRequirement(label: 'special', isMet: _hasSpecial),
                                ],
                              ),
                            ],

                            const SizedBox(height: 32),

                            if (_loading)
                              const Center(child: CircularProgressIndicator())
                            else
                              NeubrutalistButton(
                                label: _isRegister ? 'CREATE ACCOUNT' : 'START PLAYING',
                                color: const Color(0xFF0001BB),
                                textColor: Colors.white,
                                onPressed: _submit,
                              ),
                            
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () => setState(() {
                                _isRegister = !_isRegister;
                                _error = null;
                              }),
                              child: Text(
                                _isRegister ? 'ALREADY HAVE AN ACCOUNT? SIGN IN' : 'NEW TO THE ARENA? CREATE ACCOUNT',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF0001BB)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),

                    const SizedBox(height: 32),
                    
                    // SOCIAL & GUEST
                    Row(
                      children: [
                        Expanded(
                          child: NeubrutalistButton(
                            label: 'GOOGLE',
                            color: Colors.white,
                            onPressed: _signInWithGoogle,
                            icon: Image.asset('assets/images/google-logo.png', width: 20),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: NeubrutalistButton(
                            label: 'GUEST',
                            color: const Color(0xFFFFFF00),
                            onPressed: _continueAsGuest,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 800.ms),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationUI() {
    return PageShell(
      showHeader: false,
      showSidebar: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: NeubrutalistContainer(
            color: Colors.white,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mark_email_read_outlined, size: 64, color: Color(0xFF0001BB)),
                const Gap(24),
                const Text('Verify Your Email', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
                const Gap(16),
                Text(
                  'We have sent a verification link to ${_emailCtrl.text.trim()}.\n\nPlease check your inbox and click the link to continue.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54),
                ),
                const Gap(32),
                if (_loading)
                  const CircularProgressIndicator()
                else
                  NeubrutalistButton(
                    label: 'I HAVE VERIFIED',
                    color: const Color(0xFF00FF00),
                    onPressed: _checkVerificationStatus,
                  ),
                const Gap(16),
                TextButton(
                  onPressed: () async {
                    await _auth.currentUser?.sendEmailVerification();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification email resent!')));
                    }
                  },
                  child: const Text('Resend Email', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                TextButton(
                  onPressed: () async {
                    await _auth.signOut();
                    setState(() => _verifyingEmail = false);
                  },
                  child: const Text('Cancel & Back', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordRequirement extends StatelessWidget {
  final String label;
  final bool isMet;
  const _PasswordRequirement({required this.label, required this.isMet});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: isMet ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isMet ? FontWeight.w800 : FontWeight.w500,
              color: isMet ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingNote extends StatelessWidget {
  final int index;
  const _FloatingNote({required this.index});

  @override
  Widget build(BuildContext context) {
    final rand = Random(index);
    final icons = [Icons.music_note, Icons.music_video, Icons.audiotrack, Icons.album];
    final size = 20.0 + rand.nextDouble() * 40.0;
    
    return Positioned(
      left: rand.nextDouble() * MediaQuery.of(context).size.width,
      top: rand.nextDouble() * MediaQuery.of(context).size.height,
      child: Icon(
        icons[rand.nextInt(icons.length)],
        size: size,
        color: const Color(0xFF0001BB).withOpacity(0.05),
      ).animate(onPlay: (c) => c.repeat())
       .moveY(begin: 0, end: -100, duration: (5 + rand.nextDouble() * 5).seconds, curve: Curves.easeInOut)
       .rotate(begin: 0, end: 1, duration: 10.seconds)
       .fadeIn(duration: 1.seconds)
       .then()
       .fadeOut(duration: 1.seconds),
    );
  }
}

class _LoginTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isPassword;
  final TextInputType? keyboardType;

  const _LoginTextField({
    required this.controller, 
    required this.label, 
    required this.icon, 
    this.isPassword = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
        const SizedBox(height: 8),
        NeubrutalistContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shadowOffset: 0,
          color: Colors.white,
          borderWidth: 2,
          child: TextFormField(
            controller: controller,
            obscureText: isPassword,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
            decoration: InputDecoration(
              icon: Icon(icon, color: Colors.black54, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
