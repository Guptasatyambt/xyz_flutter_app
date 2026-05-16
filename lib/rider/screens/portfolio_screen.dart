import 'package:flutter/material.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Portfolio',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wallet_outlined, size: 64, color: Color(0xFFBDBDBD)),
            SizedBox(height: 16),
            Text(
              'Coming Soon',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF424242),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Your rides, rewards and payments\nwill appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
            ),
          ],
        ),
      ),
    );
  }
}
