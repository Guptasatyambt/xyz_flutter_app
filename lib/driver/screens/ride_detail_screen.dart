import 'package:flutter/material.dart';

import '../../core/models/ride_models.dart';

class DriverRideDetailScreen extends StatelessWidget {
  final Ride ride;

  const DriverRideDetailScreen({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Ride Details',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: BackButton(color: const Color(0xFF1A1A2E)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusBanner(ride: ride),
          const SizedBox(height: 16),
          if (ride.riderInfo != null) ...[
            _RiderInfoCard(info: ride.riderInfo!),
            const SizedBox(height: 16),
          ],
          _RouteCard(ride: ride),
          const SizedBox(height: 16),
          _FareCard(ride: ride),
          const SizedBox(height: 16),
          _TimelineCard(ride: ride),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Status banner ──────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final Ride ride;
  const _StatusBanner({required this.ride});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (true) {
      _ when ride.isCompleted => (
          const Color(0xFFE8F5E9),
          const Color(0xFF2E7D32),
          Icons.check_circle_outline,
        ),
      _ when ride.isCancelled => (
          const Color(0xFFFFEBEE),
          const Color(0xFFC62828),
          Icons.cancel_outlined,
        ),
      _ => (
          const Color(0xFFFFF3E0),
          const Color(0xFFE65100),
          Icons.info_outline,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ride.statusLabel,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ride.vehicleDisplayName,
                  style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Rider info card ────────────────────────────────────────────────────────────

class _RiderInfoCard extends StatelessWidget {
  final RiderInfo info;
  const _RiderInfoCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final initials = info.displayName
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF5C6BC0).withValues(alpha: 0.12),
            child: Text(
              initials,
              style: const TextStyle(
                color: Color(0xFF5C6BC0),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info.displayName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Rider',
                style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Route card ─────────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  final Ride ride;
  const _RouteCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _LocationRow(
            icon: Icons.radio_button_checked,
            iconColor: const Color(0xFF5C6BC0),
            label: 'Pickup',
            address: ride.pickupAddress ??
                '${ride.pickupLat.toStringAsFixed(5)}, ${ride.pickupLng.toStringAsFixed(5)}',
          ),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Container(
                height: 22, width: 1.5, color: const Color(0xFFBDBDBD)),
          ),
          _LocationRow(
            icon: Icons.location_on,
            iconColor: const Color(0xFFE53935),
            label: 'Drop',
            address: ride.dropAddress ??
                '${ride.dropLat.toStringAsFixed(5)}, ${ride.dropLng.toStringAsFixed(5)}',
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatChip(
                icon: Icons.straighten,
                label: ride.distanceText,
              ),
              const SizedBox(width: 16),
              _StatChip(
                icon: Icons.access_time,
                label: ride.durationText,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Fare card ──────────────────────────────────────────────────────────────────

class _FareCard extends StatelessWidget {
  final Ride ride;
  const _FareCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    final hasActual = ride.actualFare != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasActual ? 'Final fare' : 'Estimated fare',
                style: const TextStyle(fontSize: 13, color: Color(0xFF757575)),
              ),
              if (!hasActual)
                const Text(
                  'Ride did not complete',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                ),
            ],
          ),
          Text(
            '₹${ride.fareToShow.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Timeline card ──────────────────────────────────────────────────────────────

class _TimelineCard extends StatelessWidget {
  final Ride ride;
  const _TimelineCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    final events = <(String, DateTime?)>[
      ('Requested', ride.requestedAt),
      if (ride.assignedAt != null) ('Assigned', ride.assignedAt),
      if (ride.arrivedAt != null) ('Driver arrived', ride.arrivedAt),
      if (ride.startedAt != null) ('Ride started', ride.startedAt),
      if (ride.completedAt != null) ('Completed', ride.completedAt),
      if (ride.cancelledAt != null) ('Cancelled', ride.cancelledAt),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Timeline',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF424242),
            ),
          ),
          const SizedBox(height: 12),
          ...events.map((e) => _TimelineRow(label: e.$1, time: e.$2!)),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final String label;
  final DateTime time;
  const _TimelineRow({required this.label, required this.time});

  @override
  Widget build(BuildContext context) {
    final formatted =
        '${_pad(time.hour)}:${_pad(time.minute)}  ${time.day}/${time.month}/${time.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF5C6BC0),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF424242)),
            ),
          ),
          Text(
            formatted,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
          ),
        ],
      ),
    );
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}

// ── Shared helpers ─────────────────────────────────────────────────────────────

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String address;

  const _LocationRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
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
                address,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF9E9E9E)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF757575)),
        ),
      ],
    );
  }
}
