import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/models/auth_models.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/socket/socket_manager.dart';
import '../home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final UserModel user;
  const ProfileSetupScreen({super.key, required this.user});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  static const _navy = Color(0xFF1A1A2E);

  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  String? _gender;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.updateProfile(
        fullName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        gender: _gender,
      );
      _goHome();
    } on ApiException catch (e) {
      if (mounted) _showError(e.isConflict ? 'Email already in use.' : e.message);
    } catch (_) {
      if (mounted) _showError('Could not reach server.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goHome() {
    unawaited(SocketManager.instance.connectDriver());
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
      (_) => false,
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red[700],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: _navy,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 36,
              left: 20,
              right: 20,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8),
                Text('Complete your profile',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 6),
                Text("Personalise your QuickRide experience",
                    style: TextStyle(
                        color: Color(0x99FFFFFF), fontSize: 14)),
              ],
            ),
          ),

          // ── Form ───────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Phone (read-only)
                    _label('Mobile Number'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_outlined,
                              size: 18, color: Color(0xFF999999)),
                          const SizedBox(width: 10),
                          Text(widget.user.phone,
                              style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF666666),
                                  fontWeight: FontWeight.w500)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Verified',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF4CAF50),
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Full name
                    _label('Full Name'),
                    const SizedBox(height: 8),
                    _inputField(
                      controller: _nameCtrl,
                      hint: 'Enter your full name',
                      icon: Icons.person_outline,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) {
                        if (v != null && v.trim().isNotEmpty &&
                            v.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Email (optional)
                    _label('Email Address', optional: true),
                    const SizedBox(height: 8),
                    _inputField(
                      controller: _emailCtrl,
                      hint: 'Enter your email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final ok = RegExp(
                                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                            .hasMatch(v.trim());
                        return ok ? null : 'Enter a valid email address';
                      },
                    ),
                    const SizedBox(height: 20),

                    // Gender
                    _label('Gender', optional: true),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _GenderChip(
                          label: 'Male',
                          icon: Icons.male,
                          selected: _gender == 'MALE',
                          onTap: () => setState(() =>
                              _gender = _gender == 'MALE' ? null : 'MALE'),
                        ),
                        const SizedBox(width: 10),
                        _GenderChip(
                          label: 'Female',
                          icon: Icons.female,
                          selected: _gender == 'FEMALE',
                          onTap: () => setState(() =>
                              _gender = _gender == 'FEMALE' ? null : 'FEMALE'),
                        ),
                        const SizedBox(width: 10),
                        _GenderChip(
                          label: 'Other',
                          icon: Icons.transgender,
                          selected: _gender == 'OTHER',
                          onTap: () => setState(() =>
                              _gender = _gender == 'OTHER' ? null : 'OTHER'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          disabledBackgroundColor: Colors.grey[200],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Save & Continue',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Skip
                    Center(
                      child: TextButton(
                        onPressed: _loading ? null : _goHome,
                        child: const Text('Skip for now',
                            style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF999999))),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _label(String text, {bool optional = false}) {
    return Row(
      children: [
        Text(text,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E))),
        if (optional) ...[
          const SizedBox(width: 6),
          Text('(optional)',
              style:
                  TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ],
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1C1C1E)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF999999)),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF1A1A2E), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.red[400]!, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.red[400]!, width: 1.5),
        ),
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF1A1A2E)
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF1A1A2E)
                  : const Color(0xFFE0E0E0),
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 22,
                  color:
                      selected ? Colors.white : const Color(0xFF666666)),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : const Color(0xFF666666))),
            ],
          ),
        ),
      ),
    );
  }
}
