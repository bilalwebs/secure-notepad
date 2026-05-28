import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secure_notepad/core/theme/app_theme.dart';
import 'package:secure_notepad/presentation/providers/auth_provider.dart';

final biometricEnabledProvider = StateProvider<bool>((ref) => false);
final darkModeProvider = StateProvider<bool>((ref) => false);
final autoLockProvider = StateProvider<String>((ref) => 'Immediately');
final fontSizeProvider = StateProvider<String>((ref) => 'Medium');

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _localAuth = LocalAuthentication();
  bool _isUploading = false;
  bool _isEditingName = false;
  final _nameController = TextEditingController();
  String _username = '';
  int _totalNotes = 0;
  int _encryptedNotes = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadNoteStats();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists && mounted) {
      setState(() {
        _username = doc.data()?['username'] ?? '';
      });
    }
  }

  Future<void> _loadNoteStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notes')
        .get();

    if (mounted) {
      setState(() {
        _totalNotes = snapshot.docs.length;
        _encryptedNotes =
            snapshot.docs.where((d) => d.data()['isEncrypted'] == true).length;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.textLight : AppTheme.textDark;
    final subTextColor =
        isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final biometricEnabled = ref.watch(biometricEnabledProvider);

    final displayName = user?.displayName ?? 'User';
    final email = user?.email ?? '';
    final initials = displayName.isNotEmpty
        ? displayName.split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : 'U';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Profile Header ──
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                bottom: 24,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primary,
                    AppTheme.primary.withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Avatar
                  GestureDetector(
                    onTap: _pickAndUploadAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          backgroundImage: user?.photoURL != null
                              ? NetworkImage(user!.photoURL!)
                              : null,
                          child: user?.photoURL == null
                              ? Text(
                                  initials,
                                  style: GoogleFonts.sora(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                        if (_isUploading)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Icon(Icons.camera_alt_rounded,
                                size: 16, color: AppTheme.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name (editable)
                  if (_isEditingName)
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: _nameController,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.sora(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.check_rounded,
                                color: Colors.white),
                            onPressed: _saveName,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        autofocus: true,
                        onSubmitted: (_) => _saveName(),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () {
                        _nameController.text = displayName;
                        setState(() => _isEditingName = true);
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayName,
                            style: GoogleFonts.sora(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.edit_rounded,
                              color: Colors.white70, size: 16),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (_username.isNotEmpty)
                    Text(
                      '@$_username',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Settings ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Account
                  _sectionHeader('Account', textColor),
                  const SizedBox(height: 10),
                  _settingsCard([
                    _settingsTile(
                      icon: Icons.person_outline_rounded,
                      title: 'Change Display Name',
                      subtitle: displayName,
                      onTap: () {
                        _nameController.text = displayName;
                        setState(() => _isEditingName = true);
                      },
                      isDark: isDark,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    _divider(isDark),
                    _settingsTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'Change Password',
                      onTap: () => _showChangePasswordDialog(),
                      isDark: isDark,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    _divider(isDark),
                    _settingsTile(
                      icon: Icons.email_outlined,
                      title: 'Change Email',
                      subtitle: email,
                      onTap: () => _showChangeEmailDialog(),
                      isDark: isDark,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                  ], isDark),

                  const SizedBox(height: 20),

                  // Security
                  _sectionHeader('Security', textColor),
                  const SizedBox(height: 10),
                  _settingsCard([
                    _settingsSwitchTile(
                      icon: Icons.fingerprint_rounded,
                      title: 'Biometric Lock',
                      subtitle: 'Use fingerprint or face to unlock',
                      value: biometricEnabled,
                      onChanged: (v) => _toggleBiometric(v, ref),
                      isDark: isDark,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    _divider(isDark),
                    _settingsTile(
                      icon: Icons.timer_outlined,
                      title: 'Auto-lock Timer',
                      trailing: DropdownButton<String>(
                        value: ref.watch(autoLockProvider),
                        underline: const SizedBox(),
                        items: ['Immediately', '1 min', '5 min', 'Never']
                            .map((v) => DropdownMenuItem(
                                  value: v,
                                  child: Text(v,
                                      style: GoogleFonts.dmSans(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            ref.read(autoLockProvider.notifier).state = v;
                          }
                        },
                      ),
                      isDark: isDark,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                  ], isDark),

                  const SizedBox(height: 20),

                  // Appearance
                  _sectionHeader('Appearance', textColor),
                  const SizedBox(height: 10),
                  _settingsCard([
                    _settingsSwitchTile(
                      icon: Icons.dark_mode_rounded,
                      title: 'Dark Mode',
                      subtitle: 'Switch between light and dark themes',
                      value: ref.watch(darkModeProvider),
                      onChanged: (v) =>
                          ref.read(darkModeProvider.notifier).state = v,
                      isDark: isDark,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    _divider(isDark),
                    _settingsTile(
                      icon: Icons.text_fields_rounded,
                      title: 'Font Size',
                      trailing: DropdownButton<String>(
                        value: ref.watch(fontSizeProvider),
                        underline: const SizedBox(),
                        items: ['Small', 'Medium', 'Large']
                            .map((v) => DropdownMenuItem(
                                  value: v,
                                  child: Text(v,
                                      style: GoogleFonts.dmSans(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            ref.read(fontSizeProvider.notifier).state = v;
                          }
                        },
                      ),
                      isDark: isDark,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                  ], isDark),

                  const SizedBox(height: 20),

                  // Notes
                  _sectionHeader('Notes', textColor),
                  const SizedBox(height: 10),
                  _settingsCard([
                    _settingsTile(
                      icon: Icons.note_alt_outlined,
                      title: 'Total Notes',
                      trailing: Text(
                        '$_totalNotes',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                      isDark: isDark,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    _divider(isDark),
                    _settingsTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'Encrypted Notes',
                      trailing: Text(
                        '$_encryptedNotes',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                      isDark: isDark,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    _divider(isDark),
                    _settingsTile(
                      icon: Icons.picture_as_pdf_outlined,
                      title: 'Export All Notes',
                      onTap: _exportNotes,
                      isDark: isDark,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                  ], isDark),

                  const SizedBox(height: 20),

                  // About
                  _sectionHeader('About', textColor),
                  const SizedBox(height: 10),
                  _settingsCard([
                    _settingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'App Version',
                      trailing: Text(
                        '1.0.0+1',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: subTextColor,
                        ),
                      ),
                      isDark: isDark,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                  ], isDark),

                  const SizedBox(height: 20),

                  // Danger Zone
                  _sectionHeader('Danger Zone', textColor),
                  const SizedBox(height: 10),
                  _settingsCard([
                    _settingsTile(
                      icon: Icons.logout_rounded,
                      title: 'Sign Out',
                      titleColor: AppTheme.error,
                      onTap: () async {
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) context.go('/login');
                      },
                      isDark: isDark,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    _divider(isDark),
                    _settingsTile(
                      icon: Icons.delete_forever_rounded,
                      title: 'Delete Account',
                      titleColor: AppTheme.error,
                      onTap: _showDeleteAccountDialog,
                      isDark: isDark,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                  ], isDark),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──

  Widget _sectionHeader(String title, Color textColor) {
    return Text(
      title,
      style: GoogleFonts.sora(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
    );
  }

  Widget _settingsCard(List<Widget> children, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    Widget? trailing,
    VoidCallback? onTap,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: titleColor ?? AppTheme.primary, size: 22),
      title: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: titleColor ?? textColor,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: GoogleFonts.dmSans(fontSize: 12, color: subTextColor))
          : null,
      trailing: trailing ??
          Icon(Icons.chevron_right_rounded,
              color: Colors.grey.shade400, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _settingsSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppTheme.primary, size: 22),
      title: Text(
        title,
        style: GoogleFonts.dmSans(
            fontSize: 15, fontWeight: FontWeight.w500, color: textColor),
      ),
      subtitle: Text(subtitle,
          style: GoogleFonts.dmSans(fontSize: 12, color: subTextColor)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppTheme.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(
      height: 1,
      indent: 52,
      endIndent: 16,
      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
    );
  }

  // ── Avatar Upload ──
  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('avatars')
          .child('${user.uid}.jpg');

      final bytes = await image.readAsBytes();
      await storageRef.putData(bytes);
      final url = await storageRef.getDownloadURL();
      await user.updatePhotoURL(url);

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'avatarUrl': url});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Avatar updated'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Save Name ──
  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    try {
      final user = FirebaseAuth.instance.currentUser!;
      await user.updateDisplayName(newName);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fullName': newName});

      setState(() => _isEditingName = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Name updated'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // ── Biometric ──
  Future<void> _toggleBiometric(bool enable, WidgetRef ref) async {
    if (enable) {
      try {
        final canAuth = await _localAuth.canCheckBiometrics;
        if (!canAuth) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Biometrics not available on this device')),
            );
          }
          return;
        }
        final didAuth = await _localAuth.authenticate(
          localizedReason: 'Enable biometric lock',
          options: const AuthenticationOptions(biometricOnly: true),
        );
        if (didAuth) {
          ref.read(biometricEnabledProvider.notifier).state = true;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Biometric error: $e')),
          );
        }
      }
    } else {
      ref.read(biometricEnabledProvider.notifier).state = false;
    }
  }

  // ── Change Password ──
  void _showChangePasswordDialog() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Change Password',
              style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: Icon(Icons.lock_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: Icon(Icons.lock_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newController.text != confirmController.text) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                          content: Text('Passwords don\'t match')),
                    );
                  }
                  return;
                }
                try {
                  final user = FirebaseAuth.instance.currentUser!;
                  final cred = EmailAuthProvider.credential(
                    email: user.email!,
                    password: currentController.text,
                  );
                  await user.reauthenticateWithCredential(cred);
                  await user.updatePassword(newController.text);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Password updated successfully'),
                        backgroundColor: AppTheme.primary,
                      ),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  // ── Change Email ──
  void _showChangeEmailDialog() {
    final passwordController = TextEditingController();
    final newEmailController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Change Email',
              style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'New Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final user = FirebaseAuth.instance.currentUser!;
                  final cred = EmailAuthProvider.credential(
                    email: user.email!,
                    password: passwordController.text,
                  );
                  await user.reauthenticateWithCredential(cred);
                  await user.verifyBeforeUpdateEmail(newEmailController.text.trim());

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .update({'email': newEmailController.text.trim()});

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Email updated successfully'),
                        backgroundColor: AppTheme.primary,
                      ),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  // ── Export Notes ──
  Future<void> _exportNotes() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export feature coming soon')),
    );
  }

  // ── Delete Account ──
  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Delete Account',
              style: GoogleFonts.sora(
                  fontWeight: FontWeight.w600, color: AppTheme.error)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This action is permanent. All your notes, folders, and data will be deleted.',
                style: GoogleFonts.dmSans(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Enter password to confirm',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
              ),
              onPressed: () async {
                try {
                  final user = FirebaseAuth.instance.currentUser!;
                  final cred = EmailAuthProvider.credential(
                    email: user.email!,
                    password: passwordController.text,
                  );
                  await user.reauthenticateWithCredential(cred);

                  // Delete user data from Firestore
                  final uid = user.uid;
                  final notesSnapshot = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('notes')
                      .get();
                  for (final doc in notesSnapshot.docs) {
                    await doc.reference.delete();
                  }
                  final foldersSnapshot = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('folders')
                      .get();
                  for (final doc in foldersSnapshot.docs) {
                    await doc.reference.delete();
                  }
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .delete();

                  await user.delete();
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) context.go('/login');
                } catch (e) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Delete Account'),
            ),
          ],
        );
      },
    );
  }
}
