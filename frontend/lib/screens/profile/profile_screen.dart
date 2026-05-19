import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/ez_colors.dart';
import '../../core/services/api_service.dart';
import '../auth/auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _displayName = '';
  String _email = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dn = await ApiService.instance.getSavedDisplayName();
    final em = await ApiService.instance.getSavedEmail();
    if (mounted) {
      setState(() {
        _displayName = dn ?? '';
        _email = em ?? '';
        _loading = false;
      });
    }
  }

  String get _initials {
    if (_displayName.isNotEmpty) {
      return _displayName
          .split(' ')
          .map((w) => w.isNotEmpty ? w[0] : '')
          .take(2)
          .join()
          .toUpperCase();
    }
    if (_email.isNotEmpty) return _email[0].toUpperCase();
    return 'E';
  }

  String get _firstName {
    if (_displayName.isNotEmpty) return _displayName.split(' ').first;
    if (_email.isNotEmpty) return _email.split('@').first;
    return 'User';
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: EzColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign Out',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, color: EzColors.ink)),
        content: Text('Are you sure you want to sign out?',
            style: GoogleFonts.plusJakartaSans(
                color: EzColors.inkSoft, fontWeight: FontWeight.w500)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700, color: EzColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sign Out',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700, color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ApiService.instance.clearSession();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (r) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: EzColors.cream,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: EzColors.yellow))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),

                    Text('Profile',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: EzColors.ink,
                            letterSpacing: -0.5))
                        .animate()
                        .fadeIn(duration: 400.ms),

                    const SizedBox(height: 20),

                    // Avatar + name card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: EzColors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: EzColors.border),
                        boxShadow: [
                          BoxShadow(
                              color: EzColors.ink.withOpacity(0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFCD24A), Color(0xFFE8B617)],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: EzColors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                    color: EzColors.yellowDeep.withOpacity(0.25),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6)),
                              ],
                            ),
                            child: Center(
                              child: Text(_initials,
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: EzColors.ink)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_displayName.isNotEmpty ? _displayName : _firstName,
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: EzColors.ink)),
                                const SizedBox(height: 3),
                                Text(_email,
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        color: EzColors.muted,
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: EzColors.yellowGlow,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: EzColors.yellow),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.verified_rounded,
                                          size: 10, color: EzColors.yellowDeep),
                                      const SizedBox(width: 4),
                                      Text('EZ Member',
                                          style: GoogleFonts.plusJakartaSans(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: EzColors.yellowDeep)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(
                        begin: 0.1, end: 0, delay: 100.ms, duration: 400.ms),

                    const SizedBox(height: 24),

                    // Settings section
                    Text('Account',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: EzColors.muted,
                            letterSpacing: 0.8))
                        .animate()
                        .fadeIn(delay: 150.ms, duration: 300.ms),

                    const SizedBox(height: 8),

                    _SettingsCard(
                      items: [
                        _SettingsItem(
                          icon: Icons.person_outline_rounded,
                          label: 'Display Name',
                          value: _displayName.isNotEmpty ? _displayName : '—',
                        ),
                        _SettingsItem(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: _email.isNotEmpty ? _email : '—',
                        ),
                      ],
                    ).animate().fadeIn(delay: 200.ms, duration: 300.ms),

                    const SizedBox(height: 20),

                    Text('App',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: EzColors.muted,
                            letterSpacing: 0.8))
                        .animate()
                        .fadeIn(delay: 250.ms, duration: 300.ms),

                    const SizedBox(height: 8),

                    _SettingsCard(
                      items: [
                        _SettingsItem(
                          icon: Icons.info_outline_rounded,
                          label: 'Version',
                          value: '1.0.0',
                        ),
                        _SettingsItem(
                          icon: Icons.location_on_outlined,
                          label: 'City',
                          value: 'Islamabad',
                        ),
                      ],
                    ).animate().fadeIn(delay: 300.ms, duration: 300.ms),

                    const SizedBox(height: 28),

                    // Sign out button
                    GestureDetector(
                      onTap: _logout,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: EzColors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFFFCDD2), width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.logout_rounded,
                                size: 18, color: Colors.red),
                            const SizedBox(width: 8),
                            Text('Sign Out',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.red)),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 350.ms, duration: 300.ms),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<_SettingsItem> items;
  const _SettingsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: EzColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EzColors.border),
        boxShadow: [
          BoxShadow(
              color: EzColors.ink.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final isLast = e.key == items.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: EzColors.cream2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(e.value.icon, size: 16, color: EzColors.inkSoft),
                    ),
                    const SizedBox(width: 12),
                    Text(e.value.label,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: EzColors.inkSoft)),
                    const Spacer(),
                    Text(e.value.value,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: EzColors.ink)),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                    height: 1, color: EzColors.border, indent: 16, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String label;
  final String value;
  const _SettingsItem({required this.icon, required this.label, required this.value});
}
