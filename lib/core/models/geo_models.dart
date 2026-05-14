class GeocodedPlace {
  final String formatted;
  final double lat;
  final double lng;

  const GeocodedPlace({
    required this.formatted,
    required this.lat,
    required this.lng,
  });

  factory GeocodedPlace.fromJson(Map<String, dynamic> json) => GeocodedPlace(
        formatted: json['formatted'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );
}

class ReverseGeocodeResult {
  final String? formatted;
  final Map<String, dynamic> components;

  const ReverseGeocodeResult({this.formatted, required this.components});

  factory ReverseGeocodeResult.fromJson(Map<String, dynamic> json) =>
      ReverseGeocodeResult(
        formatted: json['formatted'] as String?,
        components:
            (json['components'] as Map<String, dynamic>?) ?? const {},
      );
}

class NearbyDriver {
  final String driverId;
  final double lat;
  final double lng;
  final double distanceMeters;
  final String vehicleType;

  const NearbyDriver({
    required this.driverId,
    required this.lat,
    required this.lng,
    required this.distanceMeters,
    required this.vehicleType,
  });

  factory NearbyDriver.fromJson(Map<String, dynamic> json) => NearbyDriver(
        driverId: json['driverId'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        distanceMeters: (json['distanceMeters'] as num).toDouble(),
        vehicleType: json['vehicleType'] as String,
      );
}

class FareBreakdown {
  final double base;
  final double distance;
  final double time;
  final double subtotal;
  final double surgeMultiplier;
  final double total;
  final bool minimumApplied;
  final String currency;

  const FareBreakdown({
    required this.base,
    required this.distance,
    required this.time,
    required this.subtotal,
    required this.surgeMultiplier,
    required this.total,
    required this.minimumApplied,
    required this.currency,
  });

  factory FareBreakdown.fromJson(Map<String, dynamic> json) => FareBreakdown(
        base: (json['base'] as num).toDouble(),
        distance: (json['distance'] as num).toDouble(),
        time: (json['time'] as num).toDouble(),
        subtotal: (json['subtotal'] as num).toDouble(),
        surgeMultiplier: (json['surgeMultiplier'] as num).toDouble(),
        total: (json['total'] as num).toDouble(),
        minimumApplied: json['minimumApplied'] as bool,
        currency: json['currency'] as String,
      );
}

class VehicleEstimate {
  final String vehicleType;
  final double distanceMeters;
  final int durationSeconds;
  final FareBreakdown fare;
  final String quote;
  final int expiresAt;

  const VehicleEstimate({
    required this.vehicleType,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.fare,
    required this.quote,
    required this.expiresAt,
  });

  factory VehicleEstimate.fromJson(Map<String, dynamic> json) =>
      VehicleEstimate(
        vehicleType: json['vehicleType'] as String,
        distanceMeters: (json['distanceMeters'] as num).toDouble(),
        durationSeconds: json['durationSeconds'] as int,
        fare: FareBreakdown.fromJson(json['fare'] as Map<String, dynamic>),
        quote: json['quote'] as String,
        expiresAt: json['expiresAt'] as int,
      );

  String get displayName => switch (vehicleType) {
        'BIKE' => 'Bike',
        'AUTO' => 'Auto',
        'CAR_MINI' => 'Mini',
        'CAR_SEDAN' => 'Sedan',
        'CAR_SUV' => 'SUV',
        _ => vehicleType,
      };

  String get etaText {
    final m = (durationSeconds / 60).round();
    return '$m min';
  }

  String get distanceText {
    final km = distanceMeters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }
}
