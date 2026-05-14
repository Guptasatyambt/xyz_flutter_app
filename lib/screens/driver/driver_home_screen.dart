import 'package:flutter/material.dart';
import '../../core/models/driver_models.dart';
import '../../core/services/driver_service.dart';
import '../../core/services/driver_presence_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/navigation/app_navigator.dart';
import '../../screens/auth/phone_entry_screen.dart';
import 'vehicle_management_screen.dart';
import 'kyc_screen.dart';
import 'driver_ride_history_screen.dart';
import 'driver_profile_screen.dart';
import 'driver_online_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  DriverProfile? _profile;
  List<DriverVehicle> _vehicles = [];
  String? _selectedVehicleId;
  bool _loading = true;
  bool _togglingOnline = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        DriverService.getProfile(),
        DriverService.listVehicles(),
      ]);
      final profile = results[0] as DriverProfile;
      final vehicles = results[1] as List<DriverVehicle>;
      setState(() {
        _profile = profile;
        _vehicles = vehicles;
        if (_selectedVehicleId == null && vehicles.isNotEmpty) {
          _selectedVehicleId = vehicles.first.id;
        }
      });
      if (profile.isOnline && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _openOnlineScreen());
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _openOnlineScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DriverOnlineScreen()),
    ).then((_) => _load());
  }

  Future<void> _toggleOnline() async {
    if (_profile == null || _togglingOnline) return;
    if (_profile!.isOnline) {
      _openOnlineScreen();
      return;
    }
    if (_selectedVehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a vehicle first')),
      );
      return;
    }
    setState(() => _togglingOnline = true);
    try {
      final granted = await DriverPresenceService.ensurePermission();
      if (!granted) {
        throw const PresenceException(
            'Location permission is required to go online');
      }
      final pos = await DriverPresenceService.currentPosition();
      await DriverPresenceService.goOnline(
        vehicleId: _selectedVehicleId!,
        lat: pos.latitude,
        lng: pos.longitude,
      );
      DriverPresenceService.startLocationStream();
      if (mounted) _openOnlineScreen();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _togglingOnline = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PhoneEntryScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Driver Dashboard',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Color(0xFF1A1A2E)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DriverRideHistoryScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF1A1A2E)),
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildKycBanner(),
                      const SizedBox(height: 12),
                      _buildOnlineCard(),
                      const SizedBox(height: 16),
                      _buildStatsRow(),
                      const SizedBox(height: 16),
                      _buildNavGrid(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildKycBanner() {
    final p = _profile!;
    if (p.isApproved) return const SizedBox.shrink();

    Color bg;
    Color fg;
    IconData icon;
    String message;

    if (p.isRejected) {
      bg = const Color(0xFFFFEBEE);
      fg = const Color(0xFFC62828);
      icon = Icons.cancel_outlined;
      message = p.rejectionReason != null
          ? 'KYC Rejected: ${p.rejectionReason}'
          : 'KYC Rejected. Please re-upload your documents.';
    } else if (p.isUnderReview) {
      bg = const Color(0xFFFFF8E1);
      fg = const Color(0xFFF57F17);
      icon = Icons.hourglass_top;
      message = 'Your documents are under review. We\'ll notify you soon.';
    } else if (p.isDocsSubmitted) {
      bg = const Color(0xFFE3F2FD);
      fg = const Color(0xFF1565C0);
      icon = Icons.upload_file;
      message = 'Documents submitted. Awaiting review.';
    } else {
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFE65100);
      icon = Icons.info_outline;
      message = 'Complete KYC to start accepting rides.';
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const KycScreen()),
      ).then((_) => _load()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: fg, fontSize: 13),
              ),
            ),
            Icon(Icons.chevron_right, color: fg, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineCard() {
    final p = _profile!;
    final isOnline = p.isOnline;
    final canGoOnline = p.isApproved;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOnline ? 'You\'re Online' : 'You\'re Offline',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isOnline
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF616161),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isOnline
                        ? 'Ready to accept rides'
                        : canGoOnline
                            ? 'Go online to start earning'
                            : 'Complete KYC to go online',
                    style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
                  ),
                ],
              ),
              _togglingOnline
                  ? const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : GestureDetector(
                      onTap: canGoOnline ? _toggleOnline : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 56,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isOnline
                              ? const Color(0xFF4CAF50)
                              : canGoOnline
                                  ? const Color(0xFFBDBDBD)
                                  : const Color(0xFFE0E0E0),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          alignment: isOnline
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.all(3),
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
            ],
          ),
          if (!isOnline && canGoOnline && _vehicles.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Select vehicle',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF424242),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedVehicleId,
                  isExpanded: true,
                  onChanged: (v) => setState(() => _selectedVehicleId = v),
                  items: _vehicles
                      .map(
                        (v) => DropdownMenuItem(
                          value: v.id,
                          child: Row(
                            children: [
                              Icon(v.typeIcon, size: 18, color: const Color(0xFF424242)),
                              const SizedBox(width: 8),
                              Text(
                                '${v.typeLabel} • ${v.plateNumber}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final p = _profile!;
    return Row(
      children: [
        _StatCard(label: 'Rating', value: p.rating.toStringAsFixed(1), icon: Icons.star),
        const SizedBox(width: 12),
        _StatCard(label: 'Rides', value: '${p.totalRides}', icon: Icons.directions_car),
        const SizedBox(width: 12),
        _StatCard(
          label: 'Completion',
          value: '${p.completionRate.toStringAsFixed(0)}%',
          icon: Icons.check_circle_outline,
        ),
      ],
    );
  }

  Widget _buildNavGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      children: [
        _NavCard(
          icon: Icons.directions_car,
          label: 'My Vehicles',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VehicleManagementScreen()),
          ).then((_) => _load()),
        ),
        _NavCard(
          icon: Icons.verified_user_outlined,
          label: 'KYC / Documents',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const KycScreen()),
          ).then((_) => _load()),
        ),
        _NavCard(
          icon: Icons.history,
          label: 'Ride History',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const DriverRideHistoryScreen(),
            ),
          ),
        ),
        _NavCard(
          icon: Icons.account_circle_outlined,
          label: 'Profile',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DriverProfileScreen()),
          ).then((_) => _load()),
        ),
      ],
    );
  }
}

// ── Stat card ──────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
            Icon(icon, size: 20, color: const Color(0xFF5C6BC0)),
            const SizedBox(height: 4),
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
              style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Nav card ──────────────────────────────────────────────────────────────────

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE7F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF5C6BC0)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
