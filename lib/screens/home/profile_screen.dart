import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/responsive.dart';
import '../game/widgets/skribbl_avatar.dart';
import 'widgets/image_crop_dialog.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _saving = false;
  String? _verificationId;
  AvatarConfig? _tempConfig;
  Timer? _authTimer;

  @override
  void initState() {
    super.initState();
    _refreshUser();
    // Auto-refresh auth state every 5 seconds to catch email verification from browser
    _authTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshUser());
  }

  Future<void> _refreshUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      final profile = ref.read(userProfileProvider).valueOrNull;
      
      bool needsUpdate = false;
      final updates = <String, dynamic>{};

      if (user.emailVerified && profile?.isEmailVerified == false) {
        updates['isEmailVerified'] = true;
        needsUpdate = true;
      }

      if (user.phoneNumber != null && profile?.phoneNumber != user.phoneNumber) {
        updates['phoneNumber'] = user.phoneNumber;
        updates['isPhoneVerified'] = true;
        needsUpdate = true;
      }

      if (needsUpdate) {
        await ref.read(userServiceProvider).updateUser(user.uid, updates);
      }
      
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _authTimer?.cancel();
    super.dispose();
  }

  Future<void> _verifyEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Check if already verified in Firestore first to avoid unnecessary calls
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile?.isEmailVerified == true) return;

    // Reload to see if they already verified it in browser
    await user.reload();
    if (user.emailVerified) {
      await ref.read(userServiceProvider).updateUser(user.uid, {'isEmailVerified': true});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email is now verified!')));
      }
      return;
    }

    try {
      await user.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification email sent! Please check your inbox.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showLinkPhoneDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _LinkPhoneDialog(
        onSendOtp: (fullPhone) {
          _phoneCtrl.text = fullPhone;
          _startPhoneVerification();
        },
      ),
    );
  }

  Future<void> _startPhoneVerification() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone verification is currently only supported on Android/iOS/Web.'))
        );
      }
      return;
    }
    
    // Check if phone number is unique
    final isUnique = await ref.read(userServiceProvider).isPhoneNumberUnique(phone);
    if (!isUnique) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This phone number is already linked to another account.'))
        );
      }
      return;
    }

    setState(() => _verifyingPhone = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // This can happen automatically on some Android devices
          await FirebaseAuth.instance.currentUser?.linkWithCredential(credential);
          await ref.read(userServiceProvider).updateUser(FirebaseAuth.instance.currentUser!.uid, {
            'phoneNumber': phone,
            'isPhoneVerified': true,
          });
          if (mounted) {
            setState(() => _verifyingPhone = false);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone verified automatically!')));
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification failed: ${e.message}')));
            setState(() => _verifyingPhone = false);
          }
        },
        codeSent: (String vid, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = vid;
              _verifyingPhone = false;
            });
            _showOtpDialog();
          }
        },
        codeAutoRetrievalTimeout: (String vid) => _verificationId = vid,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _verifyingPhone = false);
      }
    }
  }

  void _showOtpDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter OTP', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the 6-digit code sent to your phone.'),
            const SizedBox(height: 16),
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 8),
              maxLength: 6,
              decoration: const InputDecoration(hintText: '000000', counterText: ''),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          FilledButton(
            onPressed: () async {
              final code = _otpCtrl.text.trim();
              if (code.isEmpty || _verificationId == null) return;
              try {
                final credential = PhoneAuthProvider.credential(verificationId: _verificationId!, smsCode: code);
                await FirebaseAuth.instance.currentUser?.linkWithCredential(credential);
                await ref.read(userServiceProvider).updateUser(FirebaseAuth.instance.currentUser!.uid, {
                  'phoneNumber': _phoneCtrl.text.trim(),
                  'isPhoneVerified': true,
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone verified!')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid code: $e')));
                }
              }
            },
            child: const Text('VERIFY & LINK'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      final croppedBytes = await showDialog<Uint8List>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ImageCropDialog(imageBytes: bytes),
      );

      if (croppedBytes == null || !mounted) return;

      setState(() => _saving = true);
      await ref.read(userServiceProvider).uploadProfileImage(user.uid, croppedBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile image updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final updates = <String, dynamic>{
        'displayName': _nameCtrl.text.trim(),
      };
      if (_tempConfig != null) {
        updates['avatarConfig'] = _tempConfig!.toMap();
      }
      await ref.read(userServiceProvider).updateUser(user.uid, updates);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showImagePreview(String url, String uid) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.black, width: 2),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.fw(360, max: 500)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Text('Profile Photo', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.black, thickness: 2),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: NeubrutalistContainer(
                      padding: EdgeInsets.zero,
                      child: InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 4.0,
                        child: Image.network(url, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: Colors.black, thickness: 2),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: NeubrutalistButton(
                  label: 'Remove Photo',
                  color: const Color(0xFF720100),
                  textColor: Colors.white,
                  onPressed: () async {
                    await ref.read(userServiceProvider).removeProfileImage(uid);
                    if (mounted) Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final user = ref.watch(currentUserProvider);
    final isGuest = user?.isAnonymous ?? true;

    return PageShell(
      showHeader: true,
      showSidebar: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              NeubrutalistButton(
                label: '← BACK',
                color: Colors.white,
                onPressed: () => context.go('/home'),
              ),
            ],
          ),
          const Gap(24),
          if (isGuest)
            NeubrutalistContainer(
              color: const Color(0xFFFFFF00),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.lock_outline, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Guest Profile',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Register your account to enable email and phone verification, and save your progress permanently.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  NeubrutalistButton(
                    label: 'CREATE PERMANENT ACCOUNT',
                    color: const Color(0xFF0001BB),
                    textColor: Colors.white,
                    onPressed: () => context.go('/login'),
                  ),
                ],
              ),
            )
          else
            profileAsync.when(
              data: (profile) {
              if (profile == null) return const Center(child: Text('No profile found.'));
              if (_nameCtrl.text.isEmpty && !_saving) {
                _nameCtrl.text = profile.displayName;
              }
              final currentConfig = _tempConfig ?? AvatarConfig.fromMap(profile.avatarConfig);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: profile.photoUrl != null ? () => _showImagePreview(profile.photoUrl!, profile.uid) : null,
                          child: Container(
                            key: ValueKey(profile.photoUrl),
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 3),
                              image: profile.photoUrl != null
                                  ? DecorationImage(image: NetworkImage(profile.photoUrl!), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: profile.photoUrl == null ? const Icon(Icons.person, size: 70, color: Colors.black26) : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: -5,
                          child: NeubrutalistContainer(
                            borderRadius: 999,
                            padding: const EdgeInsets.all(6),
                            child: SkribblAvatar(config: currentConfig, size: 38),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _saving ? null : _pickImage,
                            child: const NeubrutalistContainer(
                              borderRadius: 999,
                              color: Color(0xFF0001BB),
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.camera_alt, size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(32),
                  Center(
                    child: NeubrutalistButton(
                      label: 'Randomize Avatar Look',
                      color: const Color(0xFFFFFF00),
                      onPressed: () => setState(() => _tempConfig = AvatarConfig.random()),
                    ),
                  ),
                  const Gap(32),

                  // ── Verification Section ──────────────────────────────────
                  const Text('Verification', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  const Gap(12),
                  NeubrutalistContainer(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Email Verification
                        _VerificationTile(
                          icon: Icons.email_outlined,
                          label: profile.email?.isNotEmpty == true ? profile.email! : 'No email linked',
                          isVerified: profile.isEmailVerified,
                          onAction: profile.isEmailVerified ? null : _verifyEmail,
                          actionLabel: 'Verify via Link',
                          secondaryAction: profile.isEmailVerified ? null : _refreshUser,
                          secondaryIcon: profile.isEmailVerified ? null : Icons.refresh,
                        ),
                        const Gap(12),
                        // Phone Verification
                        _VerificationTile(
                          icon: Icons.phone_android_outlined,
                          label: (profile.phoneNumber?.isNotEmpty == true) 
                              ? profile.phoneNumber! 
                              : 'No phone linked',
                          isVerified: profile.isPhoneVerified && profile.phoneNumber?.isNotEmpty == true,
                          onAction: (profile.isPhoneVerified && profile.phoneNumber?.isNotEmpty == true) ? null : _showLinkPhoneDialog,
                          actionLabel: 'Link Phone',
                        ),
                      ],
                    ),
                  ),
                  const Gap(32),

                  Row(
                    children: [
                      const Text('Display Name', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      if (ref.watch(isDevProvider)) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0001BB),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('DEVELOPER', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ],
                  ),
                  const Gap(8),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(hintText: 'Enter name...'),
                  ),
                  const Gap(32),
                  NeubrutalistContainer(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Game Statistics', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                        const Gap(20),
                        const Text('Hosted Arena', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        const Gap(12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatItem(label: 'Games', value: '${profile.arenaStats.gamesPlayed}'),
                            _StatItem(label: 'Wins', value: '${profile.arenaStats.wins}'),
                            _StatItem(label: 'Points', value: '${profile.arenaStats.totalPoints}'),
                          ],
                        ),
                        const Gap(24),
                        const Divider(thickness: 1),
                        const Gap(16),
                        const Text('Daily Challenge', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        const Gap(12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatItem(label: 'Played', value: '${profile.dailyStats.challengesPlayed}'),
                            _StatItem(label: 'Perfect', value: '${profile.dailyStats.perfectScores}'),
                            _StatItem(label: 'Points', value: '${profile.dailyStats.totalPoints}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Gap(40),
                  NeubrutalistButton(
                    label: _saving ? 'SAVING...' : 'SAVE CHANGES',
                    color: const Color(0xFF0001BB),
                    textColor: Colors.white,
                    onPressed: _saving ? null : _saveProfile,
                  ),
                  const Gap(20),
                  TextButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (mounted) context.go('/login');
                    },
                    child: const Text('Sign Out', style: TextStyle(color: Color(0xFF720100), fontWeight: FontWeight.w900)),
                  ),
                  const Gap(40),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Theme.of(context).primaryColor)),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Theme.of(context).hintColor)),
      ],
    );
  }
}

class _VerificationTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isVerified;
  final VoidCallback? onAction;
  final String actionLabel;
  final VoidCallback? secondaryAction;
  final IconData? secondaryIcon;

  const _VerificationTile({
    required this.icon,
    required this.label,
    required this.isVerified,
    this.onAction,
    required this.actionLabel,
    this.secondaryAction,
    this.secondaryIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: isVerified ? Colors.green : Colors.black45, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label, 
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (secondaryAction != null)
                    IconButton(
                      icon: Icon(secondaryIcon ?? Icons.help_outline, size: 16),
                      onPressed: secondaryAction,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Check status',
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                isVerified ? 'Verified' : 'Not Verified',
                style: TextStyle(
                  color: isVerified ? Colors.green : Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        if (!isVerified && onAction != null)
          NeubrutalistButton(
            label: actionLabel,
            color: const Color(0xFFEEEEEE),
            textColor: Colors.black,
            onPressed: onAction,
          ),
      ],
    );
  }
}

class _LinkPhoneDialog extends StatefulWidget {
  final Function(String) onSendOtp;
  const _LinkPhoneDialog({required this.onSendOtp});

  @override
  State<_LinkPhoneDialog> createState() => _LinkPhoneDialogState();
}

class _LinkPhoneDialogState extends State<_LinkPhoneDialog> {
  final _phoneCtrl = TextEditingController();
  String _selectedCountryCode = '+91';

  final List<Map<String, String>> _countryCodes = [
    {'name': 'India', 'code': '+91'},
    {'name': 'USA', 'code': '+1'},
    {'name': 'UK', 'code': '+44'},
    {'name': 'Canada', 'code': '+1'},
    {'name': 'Australia', 'code': '+61'},
    {'name': 'Germany', 'code': '+49'},
    {'name': 'France', 'code': '+33'},
    {'name': 'Japan', 'code': '+81'},
    {'name': 'China', 'code': '+86'},
    {'name': 'Brazil', 'code': '+55'},
  ];

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Link Phone Number', style: TextStyle(fontWeight: FontWeight.w900)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Select your country and enter your mobile number to receive an OTP.', style: TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButton<String>(
                  value: _selectedCountryCode,
                  underline: const SizedBox(),
                  items: _countryCodes.map((c) {
                    return DropdownMenuItem(
                      value: c['code'],
                      child: Text('${c['code']} (${c['name']})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCountryCode = val);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: '10-digit number'),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        FilledButton(
          onPressed: () {
            final phone = _phoneCtrl.text.trim();
            if (phone.isEmpty) return;
            Navigator.pop(context);
            widget.onSendOtp('$_selectedCountryCode$phone');
          },
          child: const Text('SEND OTP'),
        ),
      ],
    );
  }
}

