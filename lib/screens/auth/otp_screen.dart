import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/auth_models.dart';
import '../../core/services/auth_service.dart';
import '../../core/socket/socket_manager.dart';
import '../home_screen.dart';
import '../driver/driver_home_screen.dart';
import 'profile_setup_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  final String role;

  const OtpScreen({super.key, required this.phone, required this.role});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _navy  = Color(0xFF1A1A2E);
  static const _boxes = 6;

  late final List<TextEditingController> _ctrl =
      List.generate(_boxes, (_) => TextEditingController());
  late final List<FocusNode> _focus =
      List.generate(_boxes, (_) => FocusNode());

  bool _loading = false;
  bool _navigated = false;
  int _secondsLeft = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focus[0].requestFocus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrl) { c.dispose(); }
    for (final f in _focus) { f.dispose(); }
    super.dispose();
  }

  // ── Timer ──────────────────────────────────────────────────────────────────

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  // ── OTP helpers ────────────────────────────────────────────────────────────

  String get _otp => _ctrl.map((c) => c.text).join();

  void _clearBoxes() {
    for (final c in _ctrl) { c.clear(); }
    _focus[0].requestFocus();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _loading) return;
    setState(() => _loading = true);
    try {
      await AuthService.requestOtp(phone: widget.phone, role: widget.role);
      if (!mounted) return;
      _clearBoxes();
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(_snack('OTP resent successfully'));
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) _showError('Could not reach server.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    final otp = _otp;
    if (otp.length != _boxes || _loading || _navigated) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final result = await AuthService.verifyOtp(
        phone: widget.phone,
        role: widget.role,
        otp: otp,
      );
      if (!mounted) return;
      _navigated = true;
      final isDriver = result.user.role == 'DRIVER';
      if (result.isNewUser) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(
                builder: (_) => ProfileSetupScreen(user: result.user)));
      } else if (isDriver) {
        unawaited(SocketManager.instance.connectDriver());
        Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
            (_) => false);
      } else {
        unawaited(SocketManager.instance.connectRider());
        Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (_) => false);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _clearBoxes();
      _showError(e.isRateLimited
          ? 'Too many attempts. Please request a new OTP.'
          : e.isUnauthorized
              ? 'Incorrect OTP. Please try again.'
              : e.message);
    } catch (e) {
      if (mounted) _showError('Verification failed. Please try again.');
    } finally {
      if (mounted && !_navigated) setState(() => _loading = false);
    }
  }

  // ── Snackbars ──────────────────────────────────────────────────────────────

  SnackBar _snack(String msg) => SnackBar(
        content: Text(msg),
        backgroundColor: _navy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red[700],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final maskedPhone =
        '${widget.phone.substring(0, 3)} ***** ${widget.phone.substring(widget.phone.length - 2)}';

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                const Text('Verify your number',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text.rich(TextSpan(
                  text: 'OTP sent to ',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 14),
                  children: [
                    TextSpan(
                      text: maskedPhone,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                )),
              ],
            ),
          ),

          // ── Body ───────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enter OTP',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1C1C1E))),
                  const SizedBox(height: 20),

                  // ── 6 OTP boxes ────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(_boxes, (i) => _OtpBox(
                      controller: _ctrl[i],
                      focusNode: _focus[i],
                      onChanged: (val) {
                        if (val.isNotEmpty && i < _boxes - 1) {
                          _focus[i + 1].requestFocus();
                        }
                        setState(() {});
                        if (_otp.length == _boxes && !_loading) _verify();
                      },
                      onBackspace: i > 0
                          ? () => _focus[i - 1].requestFocus()
                          : null,
                    )),
                  ),
                  const SizedBox(height: 28),

                  // ── Resend row ─────────────────────────────────────────────
                  Center(
                    child: _secondsLeft > 0
                        ? Text(
                            'Resend OTP in ${_secondsLeft}s',
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xFF999999)),
                          )
                        : GestureDetector(
                            onTap: _resend,
                            child: const Text(
                              'Resend OTP',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A2E)),
                            ),
                          ),
                  ),
                  const SizedBox(height: 36),

                  // ── Verify button ──────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _otp.length == _boxes && !_loading ? _verify : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        disabledBackgroundColor: Colors.grey[200],
                        disabledForegroundColor: const Color(0xFF999999),
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
                          : const Text('Verify OTP',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text('Wrong number? Change it',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              decoration: TextDecoration.underline)),
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

// ── Single OTP box ─────────────────────────────────────────────────────────────

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback? onBackspace;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 56,
      child: Focus(
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              controller.text.isEmpty) {
            onBackspace?.call();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: onChanged,
          style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C1E)),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF1A1A2E), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}
