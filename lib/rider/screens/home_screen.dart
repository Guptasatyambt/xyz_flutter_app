import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../../core/models/geo_models.dart';
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/geo_service.dart';
import '../../core/services/notification_service.dart';
import 'search_screen.dart';
import 'ride_estimate_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  RideSelection? _selection;
  double? _currentLat;
  double? _currentLng;
  String _currentAddress = 'Locating…';
  UserModel? _user;
  int _unreadNotifCount = 0;

  static const _quickPlaces = <_QuickPlace>[
    _QuickPlace('Home', '123 Green Park', Icons.home, 28.5594, 77.2001),
    _QuickPlace('Work', '456 Tech Hub', Icons.work, 28.4595, 77.0266),
    _QuickPlace('Airport', 'IGI T-2', Icons.flight, 28.5562, 77.0999),
    _QuickPlace('Mall', 'City Centre', Icons.shopping_cart, 28.5275, 77.2193),
  ];

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadUser();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final result = await NotificationService.getNotifications(
          unreadOnly: true, limit: 99);
      if (mounted) setState(() => _unreadNotifCount = result.items.length);
    } catch (_) {}
  }

  Future<void> _loadUser() async {
    try {
      final user = await AuthService.getMe();
      if (mounted) setState(() => _user = user);
    } catch (_) {}
  }

  Future<void> _initLocation() async {
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      if (mounted) setState(() => _currentAddress = 'Location services off');
      return;
    }
    var perm = await geo.Geolocator.checkPermission();
    if (perm == geo.LocationPermission.denied) {
      perm = await geo.Geolocator.requestPermission();
    }
    if (perm == geo.LocationPermission.denied ||
        perm == geo.LocationPermission.deniedForever) {
      if (mounted) setState(() => _currentAddress = 'Location permission denied');
      return;
    }
    try {
      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
            accuracy: geo.LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _currentLat = pos.latitude;
        _currentLng = pos.longitude;
      });
      try {
        final rev = await GeoService.reverseGeocode(pos.latitude, pos.longitude);
        if (mounted) setState(() => _currentAddress = rev.formatted ?? 'Your location');
      } catch (_) {
        if (mounted) setState(() => _currentAddress = 'Your location');
      }
    } catch (_) {
      if (mounted) setState(() => _currentAddress = 'Could not get location');
    }
  }

  Future<void> _openSearch() async {
    final result = await Navigator.push<RideSelection>(
      context,
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          currentAddress: _currentAddress,
          currentLat: _currentLat,
          currentLng: _currentLng,
        ),
      ),
    );
    if (result != null && mounted) setState(() => _selection = result);
  }

  void _selectQuickPlace(_QuickPlace p) {
    setState(() {
      _selection = RideSelection(
        source: GeocodedPlace(
          formatted: _currentAddress,
          lat: _currentLat ?? 28.6139,
          lng: _currentLng ?? 77.2090,
        ),
        destination: GeocodedPlace(
          formatted: p.address,
          lat: p.lat,
          lng: p.lng,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // ── Current location row ─────────────────────────────────
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentAddress,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF757575)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Search card ──────────────────────────────────────────
                    GestureDetector(
                      onTap: _openSearch,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.07),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A2E),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.search,
                                  color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                _selection == null
                                    ? 'Where to?'
                                    : _selection!.destination.formatted,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: _selection == null
                                      ? FontWeight.normal
                                      : FontWeight.w600,
                                  color: _selection == null
                                      ? const Color(0xFF9E9E9E)
                                      : const Color(0xFF1A1A2E),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_selection != null)
                              GestureDetector(
                                onTap: () => setState(() => _selection = null),
                                child: const Icon(Icons.close,
                                    color: Color(0xFF9E9E9E), size: 18),
                              )
                            else
                              const Icon(Icons.arrow_forward_ios,
                                  color: Color(0xFF9E9E9E), size: 14),
                          ],
                        ),
                      ),
                    ),

                    // ── If destination selected: show source too ──────────────
                    if (_selection != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.radio_button_checked,
                                color: Color(0xFF2E7D32), size: 16),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _selection!.source.formatted,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF2E7D32)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ── Quick places ─────────────────────────────────────────
                    const Text(
                      'Quick Places',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF424242),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 3.2,
                      children: _quickPlaces
                          .map((p) => _QuickPlaceChip(
                                place: p,
                                onTap: () => _selectQuickPlace(p),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),

            // ── Book button (sticky at bottom) ─────────────────────────────
            _buildBookButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final greeting = _greetingText();
    final name = _user?.fullName?.split(' ').first ?? '';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? '$greeting, $name!' : greeting,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Where would you like to go?',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const NotificationsScreen()),
              );
              _loadUnreadCount();
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_outlined,
                      size: 22, color: Color(0xFF1A1A2E)),
                ),
                if (_unreadNotifCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE53935),
                        shape: BoxShape.circle,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        _unreadNotifCount > 99
                            ? '99+'
                            : '$_unreadNotifCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookButton() {
    final canBook = _selection != null;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: canBook
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RideEstimateScreen(
                        originLat: _selection!.source.lat,
                        originLng: _selection!.source.lng,
                        originAddress: _selection!.source.formatted,
                        dest: _selection!.destination,
                      ),
                    ),
                  )
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A1A2E),
            disabledBackgroundColor: Colors.grey[200],
            disabledForegroundColor: Colors.grey[400],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: Text(
            canBook ? 'Book Ride' : 'Enter destination to continue',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  String _greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good evening';
  }
}

// ── Supporting widgets ─────────────────────────────────────────────────────────

class _QuickPlaceChip extends StatelessWidget {
  final _QuickPlace place;
  final VoidCallback onTap;
  const _QuickPlaceChip({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(place.icon, size: 14, color: const Color(0xFF1A1A2E)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    place.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                  Text(
                    place.address,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF999999)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickPlace {
  final String name;
  final String address;
  final IconData icon;
  final double lat;
  final double lng;
  const _QuickPlace(this.name, this.address, this.icon, this.lat, this.lng);
}
