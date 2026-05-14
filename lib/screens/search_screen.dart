import 'dart:async';
import 'package:flutter/material.dart';
import '../core/models/geo_models.dart';
import '../core/services/geo_service.dart';

class SearchScreen extends StatefulWidget {
  final String currentAddress;

  const SearchScreen({super.key, this.currentAddress = 'Your location'});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  String _query = '';
  bool _geocoding = false;
  List<GeocodedPlace>? _geocodeResults;
  Timer? _debounce;

  // ── Static favourites ──────────────────────────────────────────────────────

  static const _recentPlaces = <_StaticPlace>[
    _StaticPlace('Home', '123 Green Park, New Delhi',
        Icons.home, true, 28.5594, 77.2001),
    _StaticPlace('Work', '456 Tech Hub, Gurgaon',
        Icons.work, true, 28.4595, 77.0266),
    _StaticPlace('IGI Airport T-2', 'NH 48, Aerocity, Delhi',
        Icons.flight, true, 28.5562, 77.0999),
    _StaticPlace('Select City Walk', 'A3, District Centre, Saket',
        Icons.shopping_cart, true, 28.5275, 77.2193),
    _StaticPlace('AIIMS Delhi', 'Ansari Nagar East, New Delhi',
        Icons.local_hospital, true, 28.5672, 77.2100),
  ];

  static const _popularPlaces = <_StaticPlace>[
    _StaticPlace('Connaught Place', 'Rajiv Chowk, New Delhi 110001',
        Icons.location_city, false, 28.6315, 77.2167),
    _StaticPlace('India Gate', 'Rajpath, New Delhi 110003',
        Icons.flag, false, 28.6129, 77.2295),
    _StaticPlace('Nizamuddin Station', 'Hazrat Nizamuddin, Delhi',
        Icons.train, false, 28.5888, 77.2550),
    _StaticPlace('Cyber City', 'DLF Phase 2, Gurgaon 122002',
        Icons.business, false, 28.4966, 77.0886),
    _StaticPlace('Noida Sector 62', 'Sector 62, Noida, UP 201309',
        Icons.apartment, false, 28.6274, 77.3695),
  ];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  void _onChanged(String val) {
    setState(() {
      _query = val;
      if (val.length < 2) {
        _geocodeResults = null;
        _geocoding = false;
      }
    });
    _debounce?.cancel();
    if (val.length >= 2) {
      _debounce =
          Timer(const Duration(milliseconds: 400), () => _geocode(val));
    }
  }

  Future<void> _geocode(String q) async {
    if (!mounted) return;
    setState(() => _geocoding = true);
    try {
      final results = await GeoService.geocode(q);
      if (!mounted) return;
      setState(() {
        _geocodeResults = results;
        _geocoding = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _geocodeResults = [];
        _geocoding = false;
      });
    }
  }

  // ── Selection ──────────────────────────────────────────────────────────────

  void _selectStatic(_StaticPlace p) {
    Navigator.pop(
      context,
      GeocodedPlace(
          formatted: '${p.name} — ${p.address}', lat: p.lat, lng: p.lng),
    );
  }

  void _selectGeocoded(GeocodedPlace p) => Navigator.pop(context, p);

  // ── List items builder ─────────────────────────────────────────────────────

  List<Object> get _listItems {
    if (_query.isEmpty) {
      return [
        'RECENT PLACES',
        ..._recentPlaces,
        'POPULAR DESTINATIONS',
        ..._popularPlaces,
      ];
    }
    if (_geocodeResults != null && _geocodeResults!.isNotEmpty) {
      return ['SEARCH RESULTS', ..._geocodeResults!];
    }
    // Fallback: filter static while waiting for API / no results
    final q = _query.toLowerCase();
    return [
      ..._recentPlaces,
      ..._popularPlaces,
    ].where((p) =>
        p.name.toLowerCase().contains(q) ||
        p.address.toLowerCase().contains(q)).toList();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final items = _listItems;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1C1C1E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Where to?',
          style: TextStyle(
              color: Color(0xFF1C1C1E),
              fontSize: 18,
              fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                // From
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50),
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.currentAddress,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF666666)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Dotted connector
                Padding(
                  padding:
                      const EdgeInsets.only(left: 20, top: 4, bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(
                      4,
                      (_) => Container(
                        width: 2,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 1),
                        color: Colors.grey[300],
                      ),
                    ),
                  ),
                ),

                // To input
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF1A1A2E), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: Color(0xFF1A1A2E), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          onChanged: _onChanged,
                          style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1C1C1E),
                              fontWeight: FontWeight.w500),
                          decoration: const InputDecoration(
                            hintText: 'Search destination...',
                            hintStyle: TextStyle(
                                color: Color(0xFF999999), fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      if (_geocoding)
                        const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF1A1A2E)))
                      else if (_query.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _controller.clear();
                            setState(() {
                              _query = '';
                              _geocodeResults = null;
                            });
                          },
                          child: const Icon(Icons.close,
                              color: Color(0xFF999999), size: 18),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFEEEEEE)),

          Expanded(
            child: items.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      if (item is String) {
                        return _SectionHeader(title: item);
                      }
                      if (item is _StaticPlace) {
                        return _StaticPlaceTile(
                          place: item,
                          onTap: () => _selectStatic(item),
                        );
                      }
                      final geo = item as GeocodedPlace;
                      return _GeocodedTile(
                        place: geo,
                        onTap: () => _selectGeocoded(geo),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No results for "$_query"',
            style:
                const TextStyle(color: Color(0xFF999999), fontSize: 15),
          ),
          const SizedBox(height: 8),
          const Text('Try a different search term',
              style:
                  TextStyle(color: Color(0xFFBBBBBB), fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Data & widgets ────────────────────────────────────────────────────────────

class _StaticPlace {
  final String name;
  final String address;
  final IconData icon;
  final bool isRecent;
  final double lat;
  final double lng;

  const _StaticPlace(
      this.name, this.address, this.icon, this.isRecent, this.lat, this.lng);
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFFAAAAAA),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _StaticPlaceTile extends StatelessWidget {
  final _StaticPlace place;
  final VoidCallback onTap;
  const _StaticPlaceTile({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(place.icon, size: 20, color: const Color(0xFF1A1A2E)),
      ),
      title: Text(place.name,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      subtitle: Text(place.address,
          style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      trailing: Icon(
        place.isRecent ? Icons.history : Icons.star_outline,
        size: 18,
        color: Colors.grey[300],
      ),
    );
  }
}

class _GeocodedTile extends StatelessWidget {
  final GeocodedPlace place;
  final VoidCallback onTap;
  const _GeocodedTile({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.location_on,
            size: 20, color: Color(0xFF1A1A2E)),
      ),
      title: Text(
        place.formatted,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.north_east, size: 16, color: Color(0xFFCCCCCC)),
    );
  }
}
