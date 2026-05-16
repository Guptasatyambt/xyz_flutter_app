import 'package:flutter/material.dart';
import '../../core/models/auth_models.dart';
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../screens/auth/phone_entry_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _navy = Color(0xFF1A1A2E);

  UserModel? _user;
  bool _loading = true;
  String? _error;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await AuthService.getMe();
      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load profile.';
        _loading = false;
      });
    }
  }

  Future<void> _editProfile() async {
    if (_user == null) return;
    final updated = await Navigator.push<UserModel>(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: _user!)),
    );
    if (updated != null) setState(() => _user = updated);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('You will be signed out of your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF999999))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Log out',
                style: TextStyle(
                    color: Colors.red[600], fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loggingOut = true);
    try {
      await AuthService.logout();
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PhoneEntryScreen()),
      (_) => false,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          if (_loading)
            const Expanded(
                child: Center(
                    child: CircularProgressIndicator(color: _navy)))
          else if (_error != null)
            _buildError()
          else
            _buildBody(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final user = _user;
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      color: _navy,
      padding: EdgeInsets.only(
          top: topPad + 12, bottom: 28, left: 20, right: 20),
      child: Column(
        children: [
          // Back + status row
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                padding: EdgeInsets.zero,
              ),
              const Spacer(),
              if (user != null) _StatusBadge(status: user.status),
            ],
          ),
          const SizedBox(height: 14),

          // Avatar
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35), width: 2),
            ),
            child: Center(
              child: _loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      user?.initials ?? '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            user?.fullName ?? (user != null ? 'User' : ''),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (user != null) _RolePill(role: user.role),
        ],
      ),
    );
  }

  Expanded _buildError() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(_error!,
                style: const TextStyle(
                    color: Color(0xFF999999), fontSize: 15)),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _loadProfile,
              child: const Text('Retry',
                  style: TextStyle(
                      color: _navy, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Expanded _buildBody() {
    final user = _user!;
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Contact ──────────────────────────────────────────────────
            _SectionLabel(text: 'CONTACT'),
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.phone_outlined,
              label: 'Mobile',
              value: user.phone,
              trailing: _VerifiedBadge(),
            ),
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.email_outlined,
              label: 'Email',
              value: user.email ?? 'Not added',
              dim: user.email == null,
            ),

            // ── Personal ─────────────────────────────────────────────────
            const SizedBox(height: 24),
            _SectionLabel(text: 'PERSONAL'),
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.person_outline,
              label: 'Gender',
              value: _genderLabel(user.gender),
              dim: user.gender == 'UNSPECIFIED',
            ),
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.calendar_today_outlined,
              label: 'Member since',
              value: _formatDate(user.createdAt),
            ),

            // ── Actions ───────────────────────────────────────────────────
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _editProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Edit Profile',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _loggingOut ? null : _logout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[600],
                  side: BorderSide(color: Colors.red[300]!),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _loggingOut
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.red[600]))
                    : const Text('Log Out',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _genderLabel(String g) => switch (g) {
        'MALE' => 'Male',
        'FEMALE' => 'Female',
        'OTHER' => 'Other',
        _ => 'Not specified',
      };

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}

// ── Small widgets ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'ACTIVE';
    final color =
        isActive ? const Color(0xFF4CAF50) : Colors.red;
    final label = isActive ? 'Active' : status == 'SUSPENDED' ? 'Suspended' : 'Deleted';

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String role;
  const _RolePill({required this.role});

  static String _label(String r) => switch (r) {
        'DRIVER' => 'Driver',
        'ADMIN' => 'Admin',
        _ => 'Rider',
      };

  static IconData _icon(String r) => switch (r) {
        'DRIVER' => Icons.drive_eta,
        'ADMIN' => Icons.admin_panel_settings,
        _ => Icons.person,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(role),
              size: 13, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(width: 5),
          Text(_label(role),
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFFAAAAAA),
            letterSpacing: 0.8));
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool dim;
  final Widget? trailing;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.dim = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF999999)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF999999),
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: dim
                            ? const Color(0xFFCCCCCC)
                            : const Color(0xFF1C1C1E))),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text('Verified',
          style: TextStyle(
              fontSize: 10,
              color: Color(0xFF4CAF50),
              fontWeight: FontWeight.w600)),
    );
  }
}
