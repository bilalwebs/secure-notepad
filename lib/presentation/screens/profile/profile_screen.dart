import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:secure_notepad/core/theme/app_theme.dart';
import 'package:secure_notepad/presentation/providers/theme_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
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

    final notesSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notes')
        .get();

    if (mounted) {
      setState(() {
        _totalNotes = notesSnap.docs.length;
        _encryptedNotes = notesSnap.docs
            .where((d) => d.data()['isEncrypted'] == true)
            .length;
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
    final user = FirebaseAuth.instance.currentUser;
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      (user?.displayName ?? 'U')[0].toUpperCase(),
                      style: GoogleFonts.sora(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isEditingName)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _nameController,
                            autofocus: true,
                            style: GoogleFonts.sora(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter name',
                              hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5)),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.white),
                          onPressed: _saveDisplayName,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white70),
                          onPressed: () =>
                              setState(() => _isEditingName = false),
                        ),
                      ],
                    )
                  else
                    GestureDetector(
                      onTap: () {
                        _nameController.text =
                            user?.displayName ?? '';
                        setState(() => _isEditingName = true);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            user?.displayName ?? 'User',
                            style: GoogleFonts.sora(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit,
                              size: 16, color: Colors.white70),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (_username.isNotEmpty)
                    Text(
                      '@$_username',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    user?.email ?? '',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Account'),
                  _settingsTile(
                    icon: Icons.lock_outline,
                    title: 'Change Password',
                    onTap: () => _showChangePasswordDialog(context),
                  ),
                  _settingsTile(
                    icon: Icons.email_outlined,
                    title: 'Change Email',
                    onTap: () => _showChangeEmailDialog(context),
                  ),

                  const SizedBox(height: 20),
                  _sectionTitle('Appearance'),
                  _settingsTile(
                    icon: isDark ? Icons.dark_mode : Icons.light_mode,
                    title: 'Dark Mode',
                    trailing: Switch(
                      value: isDark,
                      onChanged: (_) {
                        ref.read(themeProvider.notifier).toggleTheme();
                      },
                      activeThumbColor: AppTheme.primary,
                    ),
                  ),

                  const SizedBox(height: 20),
                  _sectionTitle('Notes Stats'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '$_totalNotes',
                                style: GoogleFonts.sora(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                              Text(
                                'Total Notes',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.grey.withValues(alpha: 0.2),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '$_encryptedNotes',
                                style: GoogleFonts.sora(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                              Text(
                                'Encrypted',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  _sectionTitle('Danger Zone', color: Colors.red),
                  _settingsTile(
                    icon: Icons.delete_forever_outlined,
                    title: 'Delete Account',
                    titleColor: Colors.red,
                    onTap: () => _showDeleteAccountDialog(context),
                  ),
                  _settingsTile(
                    icon: Icons.logout_rounded,
                    title: 'Sign Out',
                    titleColor: Colors.red,
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) context.go('/login');
                    },
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.sora(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color ??
              (Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.textLight
                  : AppTheme.textDark),
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon,
            color: titleColor ??
                (isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
        title: Text(
          title,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w500,
            color: titleColor ??
                (isDark ? AppTheme.textLight : AppTheme.textDark),
          ),
        ),
        trailing: trailing ??
            (onTap != null
                ? Icon(Icons.chevron_right_rounded,
                    color: Colors.grey.shade400)
                : null),
        onTap: onTap,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _saveDisplayName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await user.updateDisplayName(name);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'displayName': name});

    setState(() => _isEditingName = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name updated'),
          backgroundColor: AppTheme.primary,
        ),
      );
    }
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current password',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New password',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm new password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }
              try {
                final user = FirebaseAuth.instance.currentUser;
                final cred = EmailAuthProvider.credential(
                  email: user!.email!,
                  password: currentCtrl.text,
                );
                await user.reauthenticateWithCredential(cred);
                await user.updatePassword(newCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password changed'),
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
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangeEmailDialog(BuildContext context) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'New email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final user = FirebaseAuth.instance.currentUser;
                final cred = EmailAuthProvider.credential(
                  email: user!.email!,
                  password: passCtrl.text,
                );
                await user.reauthenticateWithCredential(cred);
                await user.verifyBeforeUpdateEmail(emailCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Verification email sent. Check your inbox.'),
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
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account',
            style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'This will permanently delete your account and all data. This cannot be undone.'),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Enter password to confirm',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;

                final cred = EmailAuthProvider.credential(
                  email: user.email!,
                  password: passCtrl.text,
                );
                await user.reauthenticateWithCredential(cred);

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .delete();

                await user.delete();

                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) context.go('/login');
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child:
                const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
