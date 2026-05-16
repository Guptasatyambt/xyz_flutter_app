import 'package:flutter/material.dart';
import '../../core/models/auth_models.dart';
import '../services/rating_service.dart';

class RatingScreen extends StatefulWidget {
  final String rideId;
  const RatingScreen({super.key, required this.rideId});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  static const _navy = Color(0xFF1A1A2E);

  int _stars = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  static const _labels = ['Terrible', 'Bad', 'Okay', 'Good', 'Excellent'];

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a star rating'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _submitting = true);
    try {
      final comment = _commentCtrl.text.trim();
      await RatingService.submitRating(
        rideId: widget.rideId,
        stars: _stars,
        comment: comment.isEmpty ? null : comment,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                children: [
                  _buildStarRow(),
                  const SizedBox(height: 36),
                  _buildCommentField(),
                  const SizedBox(height: 32),
                  _buildSubmitButton(),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed:
                        _submitting ? null : () => Navigator.pop(context, false),
                    child: const Text('Skip for now',
                        style:
                            TextStyle(color: Color(0xFF999999), fontSize: 15)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: _navy,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 32,
        left: 20,
        right: 20,
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.pop(context, false),
              icon: const Icon(Icons.close, color: Colors.white),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: const Icon(Icons.star_rounded,
                color: Colors.amber, size: 44),
          ),
          const SizedBox(height: 18),
          const Text('Rate your ride',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Your feedback helps us improve',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildStarRow() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final filled = i < _stars;
            return GestureDetector(
              onTap: () => setState(() => _stars = i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    filled
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    key: ValueKey(filled),
                    size: 52,
                    color: filled
                        ? Colors.amber[600]
                        : const Color(0xFFDDDDDD),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        AnimatedOpacity(
          opacity: _stars > 0 ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            _stars > 0 ? _labels[_stars - 1] : '',
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF333333)),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Leave a comment (optional)',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF666666))),
        const SizedBox(height: 8),
        TextField(
          controller: _commentCtrl,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'Tell us about your experience…',
            hintStyle:
                const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF8F8F8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: _navy.withValues(alpha: 0.4)),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            counterStyle: const TextStyle(
                color: Color(0xFFBBBBBB), fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final canSubmit = _stars > 0 && !_submitting;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canSubmit ? _submit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFDDDDDD),
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 17),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _submitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
            : const Text('Submit Rating',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
