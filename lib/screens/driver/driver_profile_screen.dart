import 'package:flutter/material.dart';
import '../../core/models/auth_models.dart';
import '../../core/models/driver_models.dart';
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/driver_service.dart';
import '../../core/navigation/app_navigator.dart';
import '../auth/phone_entry_screen.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  UserModel? _user;
  DriverProfile? _profile;
  bool _loading = true;
  String? _error;

  // Edit state
  bool _editing = false;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  String? _gender;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        AuthService.getMe(),
        DriverService.getProfile(),
      ]);
      final user = results[0] as UserModel;
      setState(() {
        _user = user;
        _profile = results[1] as DriverProfile;
        _nameCtrl.text = user.fullName ?? '';
        _emailCtrl.text = user.email ?? '';
        _gender = user.gender == 'UNSPECIFIED' ? null : user.gender;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final updated = await AuthService.updateProfile(
        fullName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        gender: _gender,
      );
      setState(() {
        _user = updated;
        _editing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.isConflict ? 'Email already in use.' : e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update profile.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PhoneEntryScreen()),
      (_) => false,
    );
  }

  void _startEditing() {
    if (_user == null) return;
    _nameCtrl.text = _user!.fullName ?? '';
    _emailCtrl.text = _user!.email ?? '';
    _gender = _user!.gender == 'UNSPECIFIED' ? null : _user!.gender;
    setState(() => _editing = true);
  }

  void _cancelEditing() {
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: BackButton(color: const Color(0xFF1A1A2E)),
        actions: [
          if (!_loading && _error == null && !_editing)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF5C6BC0)),
              onPressed: _startEditing,
              tooltip: 'Edit profile',
            ),
          if (_editing)
            TextButton(
              onPressed: _cancelEditing,
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF9E9E9E))),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildAvatarCard(),
                      const SizedBox(height: 16),
                      _editing ? _buildEditForm() : _buildInfoCard(),
                      const SizedBox(height: 16),
                      _buildStatsCard(),
                      const SizedBox(height: 24),
                      _buildLogoutButton(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
    );
  }

  // ── Avatar card ──────────────────────────────────────────────────────────────

  Widget _buildAvatarCard() {
    final user = _user!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFF5C6BC0),
            child: Text(
              user.initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.fullName ?? 'Driver',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.phone,
            style: const TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
          ),
          if (_profile != null) ...[
            const SizedBox(height: 8),
            _KycBadge(status: _profile!.kycStatus),
          ],
        ],
      ),
    );
  }

  // ── Info card (read mode) ────────────────────────────────────────────────────

  Widget _buildInfoCard() {
    final user = _user!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personal Info',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF424242),
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.person_outline,
            label: 'Full Name',
            value: user.fullName ?? '—',
          ),
          const _Divider(),
          _InfoRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: user.phone,
          ),
          const _Divider(),
          _InfoRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: user.email ?? '—',
          ),
          const _Divider(),
          _InfoRow(
            icon: Icons.wc_outlined,
            label: 'Gender',
            value: _genderLabel(user.gender),
          ),
        ],
      ),
    );
  }

  // ── Edit form ────────────────────────────────────────────────────────────────

  Widget _buildEditForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit Profile',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF424242),
              ),
            ),
            const SizedBox(height: 16),

            // Full name
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration('Full Name', Icons.person_outline),
              validator: (v) {
                if (v != null && v.trim().isNotEmpty && v.trim().length < 2) {
                  return 'Min 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Email
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDecoration('Email (optional)', Icons.email_outlined),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim());
                return ok ? null : 'Enter a valid email';
              },
            ),
            const SizedBox(height: 16),

            // Gender
            const Text(
              'Gender',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF424242),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _GenderChip(
                  label: 'Male',
                  icon: Icons.male,
                  selected: _gender == 'MALE',
                  onTap: () => setState(
                      () => _gender = _gender == 'MALE' ? null : 'MALE'),
                ),
                const SizedBox(width: 10),
                _GenderChip(
                  label: 'Female',
                  icon: Icons.female,
                  selected: _gender == 'FEMALE',
                  onTap: () => setState(
                      () => _gender = _gender == 'FEMALE' ? null : 'FEMALE'),
                ),
                const SizedBox(width: 10),
                _GenderChip(
                  label: 'Other',
                  icon: Icons.transgender,
                  selected: _gender == 'OTHER',
                  onTap: () => setState(
                      () => _gender = _gender == 'OTHER' ? null : 'OTHER'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C6BC0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Changes',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stats card ───────────────────────────────────────────────────────────────

  Widget _buildStatsCard() {
    final p = _profile!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Driver Stats',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF424242),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatTile(
                icon: Icons.star_rounded,
                iconColor: const Color(0xFFFFA000),
                label: 'Rating',
                value: p.rating.toStringAsFixed(1),
                sub: '${p.ratingCount} reviews',
              ),
              const SizedBox(width: 12),
              _StatTile(
                icon: Icons.directions_car,
                iconColor: const Color(0xFF5C6BC0),
                label: 'Total Rides',
                value: '${p.totalRides}',
                sub: '${p.acceptedOffers} accepted',
              ),
              const SizedBox(width: 12),
              _StatTile(
                icon: Icons.check_circle_outline,
                iconColor: const Color(0xFF2E7D32),
                label: 'Completion',
                value: '${p.completionRate.toStringAsFixed(0)}%',
                sub: '${p.cancelledRides} cancelled',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Logout ───────────────────────────────────────────────────────────────────

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout, color: Color(0xFFE53935)),
        label: const Text(
          'Log Out',
          style: TextStyle(
            color: Color(0xFFE53935),
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFEF9A9A)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF9E9E9E)),
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF5C6BC0), width: 1.5),
      ),
    );
  }

  String _genderLabel(String g) => switch (g) {
        'MALE' => 'Male',
        'FEMALE' => 'Female',
        'OTHER' => 'Other',
        _ => '—',
      };
}

// ── KYC badge ──────────────────────────────────────────────────────────────────

class _KycBadge extends StatelessWidget {
  final String status;
  const _KycBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'APPROVED'       => (const Color(0xFF2E7D32), 'KYC Approved'),
      'UNDER_REVIEW'   => (const Color(0xFFF57F17), 'Under Review'),
      'DOCS_SUBMITTED' => (const Color(0xFF1565C0), 'Docs Submitted'),
      'REJECTED'       => (const Color(0xFFC62828), 'KYC Rejected'),
      _                => (const Color(0xFF9E9E9E), 'KYC Pending'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Info row ───────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF9E9E9E)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: Color(0xFFF0F0F0));
}

// ── Stat tile ──────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String sub;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF424242)),
          ),
          Text(
            sub,
            style: const TextStyle(fontSize: 10, color: Color(0xFFBDBDBD)),
          ),
        ],
      ),
    );
  }
}

// ── Gender chip ────────────────────────────────────────────────────────────────

class _GenderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF5C6BC0)
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFF5C6BC0)
                  : const Color(0xFFE0E0E0),
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 20,
                  color: selected ? Colors.white : const Color(0xFF666666)),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
