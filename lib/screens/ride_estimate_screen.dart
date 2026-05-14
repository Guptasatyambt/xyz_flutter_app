import 'package:flutter/material.dart';
import '../core/models/auth_models.dart';
import '../core/models/geo_models.dart';
import '../core/services/geo_service.dart';
import '../core/services/ride_service.dart';
import 'active_ride_screen.dart';

class RideEstimateScreen extends StatefulWidget {
  final double originLat;
  final double originLng;
  final String originAddress;
  final GeocodedPlace dest;

  const RideEstimateScreen({
    super.key,
    required this.originLat,
    required this.originLng,
    required this.originAddress,
    required this.dest,
  });

  @override
  State<RideEstimateScreen> createState() => _RideEstimateScreenState();
}

class _RideEstimateScreenState extends State<RideEstimateScreen> {
  static const _navy = Color(0xFF1A1A2E);

  List<VehicleEstimate>? _estimates;
  String? _error;
  bool _loading = true;
  bool _booking = false;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadEstimates();
  }

  Future<void> _loadEstimates() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await GeoService.estimateAll(
        originLat: widget.originLat,
        originLng: widget.originLng,
        destLat: widget.dest.lat,
        destLng: widget.dest.lng,
      );
      if (!mounted) return;
      setState(() {
        _estimates = items;
        _loading = false;
        // Default to CAR_MINI (index 2) if available
        _selectedIndex =
            items.indexWhere((e) => e.vehicleType == 'CAR_MINI').let((i) =>
                i >= 0 ? i : 0);
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
        _error = 'Could not reach server.';
        _loading = false;
      });
    }
  }

  Future<void> _book() async {
    final est = _estimates?[_selectedIndex];
    if (est == null || _booking) return;
    setState(() => _booking = true);
    try {
      final ride = await RideService.bookRide(
        quote: est.quote,
        pickupAddress: widget.originAddress,
        dropAddress: widget.dest.formatted,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => ActiveRideScreen(initialRide: ride)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _booking = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (_) {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final est = _estimates;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: _navy,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 24,
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
                const SizedBox(height: 10),
                const Text(
                  'Choose Your Ride',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                if (est != null)
                  Text(
                    '${est[_selectedIndex].distanceText}  ·  ${est[_selectedIndex].etaText} away',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13),
                  ),
                const SizedBox(height: 16),
                _RouteRow(
                  origin: widget.originAddress,
                  dest: widget.dest.formatted,
                ),
              ],
            ),
          ),

          // ── Body ───────────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _navy))
                : _error != null
                    ? _buildError()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        itemCount: est!.length,
                        itemBuilder: (_, i) => _VehicleCard(
                          estimate: est[i],
                          isSelected: _selectedIndex == i,
                          onTap: () => setState(() => _selectedIndex = i),
                        ),
                      ),
          ),

          // ── Book button ─────────────────────────────────────────────────────
          if (!_loading && _error == null && est != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _booking ? null : _book,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _navy,
                      disabledForegroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _booking
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white))
                        : Text(
                            'Book ${est[_selectedIndex].displayName}  ·  ₹${est[_selectedIndex].fare.total.round()}',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(_error!,
              style: const TextStyle(color: Color(0xFF999999), fontSize: 15)),
          const SizedBox(height: 20),
          TextButton(
            onPressed: _loadEstimates,
            child: const Text('Retry',
                style: TextStyle(
                    color: _navy, fontWeight: FontWeight.w600, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

// ── Route row ──────────────────────────────────────────────────────────────────

class _RouteRow extends StatelessWidget {
  final String origin;
  final String dest;

  const _RouteRow({required this.origin, required this.dest});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50), shape: BoxShape.circle),
              ),
              Container(
                  width: 1,
                  height: 22,
                  color: Colors.white.withValues(alpha: 0.3)),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  origin,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Text(
                  dest,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Vehicle card ───────────────────────────────────────────────────────────────

class _VehicleCard extends StatelessWidget {
  final VehicleEstimate estimate;
  final bool isSelected;
  final VoidCallback onTap;

  const _VehicleCard({
    required this.estimate,
    required this.isSelected,
    required this.onTap,
  });

  static IconData _iconFor(String type) => switch (type) {
        'BIKE' => Icons.two_wheeler,
        'AUTO' => Icons.electric_rickshaw,
        'CAR_MINI' => Icons.directions_car,
        'CAR_SEDAN' => Icons.drive_eta,
        'CAR_SUV' => Icons.airport_shuttle,
        _ => Icons.directions_car,
      };

  @override
  Widget build(BuildContext context) {
    final hasSurge = estimate.fare.surgeMultiplier > 1.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1A1A2E)
                : const Color(0xFFE8E8E8),
            width: isSelected ? 0 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color:
                        const Color(0xFF1A1A2E).withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            // ── Icon box ───────────────────────────────────────────────────
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconFor(estimate.vehicleType),
                size: 26,
                color: isSelected ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(width: 14),

            // ── Name + details ─────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        estimate.displayName,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF1C1C1E)),
                      ),
                      if (hasSurge) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35)
                                .withValues(alpha: isSelected ? 0.25 : 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${estimate.fare.surgeMultiplier.toStringAsFixed(1)}× surge',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? const Color(0xFFFFB380)
                                    : const Color(0xFFFF6B35)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${estimate.distanceText}  ·  ${estimate.etaText}',
                    style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.6)
                            : const Color(0xFF999999)),
                  ),
                ],
              ),
            ),

            // ── Price ──────────────────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${estimate.fare.total.round()}',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF1C1C1E)),
                ),
                if (estimate.fare.minimumApplied)
                  Text(
                    'min fare',
                    style: TextStyle(
                        fontSize: 10,
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.5)
                            : const Color(0xFFAAAAAA)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Extension helper ───────────────────────────────────────────────────────────

extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
