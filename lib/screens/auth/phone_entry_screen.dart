import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/auth_models.dart';
import '../../core/services/auth_service.dart';
import 'otp_screen.dart';

class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final _phoneCtrl = TextEditingController();
  final _phoneFocus = FocusNode();
  String _role = 'RIDER';
  bool _loading = false;

  static const _navy = Color(0xFF1A1A2E);
  static const _grey = Color(0xFF999999);

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  String get _e164 => '+91${_phoneCtrl.text.trim()}';

  bool get _canSubmit {
    final digits = _phoneCtrl.text.trim();
    return digits.length == 10 &&
        RegExp(r'^[6-9]\d{9}$').hasMatch(digits) &&
        !_loading;
  }

  Future<void> _sendOtp() async {
    if (!_canSubmit) return;
    _phoneFocus.unfocus();
    setState(() => _loading = true);
    try {
      await AuthService.requestOtp(phone: _e164, role: _role);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(phone: _e164, role: _role),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showError(e.isRateLimited
          ? 'Too many attempts. Please wait and try again.'
          : e.message);
    } catch (_) {
      if (mounted) _showError('Could not reach server. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: _navy,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 40,
              bottom: 40,
              left: 28,
              right: 28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.local_taxi,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(height: 20),
                const Text('QuickRide',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Text('Your ride, your way',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 15)),
              ],
            ),
          ),

          // ── Form ─────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enter your mobile number',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1C1E))),
                  const SizedBox(height: 6),
                  Text("We'll send you a 6-digit OTP to verify",
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 28),

                  // Phone input
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          child: const Text('+91',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1C1C1E))),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _phoneCtrl,
                            focusNode: _phoneFocus,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _sendOtp(),
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1C1C1E),
                                letterSpacing: 2),
                            decoration: InputDecoration(
                              hintText: '98765 43210',
                              hintStyle: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[400],
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.normal),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 18),
                            ),
                          ),
                        ),
                        if (_phoneCtrl.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _phoneCtrl.clear();
                              setState(() {});
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Icon(Icons.cancel,
                                  color: Colors.grey[400], size: 20),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Role selector
                  const Text("I'm a",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1C1C1E))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _RoleCard(
                        label: 'Rider',
                        icon: Icons.person,
                        selected: _role == 'RIDER',
                        onTap: () => setState(() => _role = 'RIDER'),
                      ),
                      const SizedBox(width: 12),
                      _RoleCard(
                        label: 'Driver',
                        icon: Icons.drive_eta,
                        selected: _role == 'DRIVER',
                        onTap: () => setState(() => _role = 'DRIVER'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canSubmit ? _sendOtp : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        disabledBackgroundColor: Colors.grey[200],
                        disabledForegroundColor: _grey,
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
                          : const Text('Send OTP',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Terms
                  Center(
                    child: Text.rich(
                      TextSpan(
                        text: 'By continuing you agree to our ',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        children: const [
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(
                                color: Color(0xFF1A1A2E),
                                fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: ' & '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                                color: Color(0xFF1A1A2E),
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Role selector card ─────────────────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
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
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFF1A1A2E)
                  : const Color(0xFFE0E0E0),
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 28,
                  color: selected ? Colors.white : const Color(0xFF666666)),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : const Color(0xFF1C1C1E))),
            ],
          ),
        ),
      ),
    );
  }
}
