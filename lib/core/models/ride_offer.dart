/// Payload of the `ride:offer` socket event emitted to a specific driver by
/// the matching worker. See backend `src/modules/rides/matching.worker.ts`.
///
/// The offer has a 15-second server-side TTL — drivers must accept/reject
/// before [expiresAt] or the backend marks it TIMED_OUT.
class RideOffer {
  final String offerId;
  final String rideId;
  final DateTime expiresAt;
  final double pickupLat;
  final double pickupLng;
  final String? pickupAddress;
  final double dropLat;
  final double dropLng;
  final String? dropAddress;
  final String vehicleType;
  final double estimatedFare;
  final int estimatedDistanceMeters;
  final int estimatedDurationSeconds;

  const RideOffer({
    required this.offerId,
    required this.rideId,
    required this.expiresAt,
    required this.pickupLat,
    required this.pickupLng,
    this.pickupAddress,
    required this.dropLat,
    required this.dropLng,
    this.dropAddress,
    required this.vehicleType,
    required this.estimatedFare,
    required this.estimatedDistanceMeters,
    required this.estimatedDurationSeconds,
  });

  factory RideOffer.fromJson(Map<String, dynamic> j) {
    final pickup = j['pickup'] as Map<String, dynamic>;
    final drop = j['drop'] as Map<String, dynamic>;
    return RideOffer(
      offerId: j['offerId'] as String,
      rideId: j['rideId'] as String,
      expiresAt: DateTime.parse(j['expiresAt'] as String),
      pickupLat: (pickup['lat'] as num).toDouble(),
      pickupLng: (pickup['lng'] as num).toDouble(),
      pickupAddress: pickup['address'] as String?,
      dropLat: (drop['lat'] as num).toDouble(),
      dropLng: (drop['lng'] as num).toDouble(),
      dropAddress: drop['address'] as String?,
      vehicleType: j['vehicleType'] as String,
      estimatedFare: (j['estimatedFare'] as num).toDouble(),
      estimatedDistanceMeters: (j['estimatedDistanceMeters'] as num).toInt(),
      estimatedDurationSeconds: (j['estimatedDurationSeconds'] as num).toInt(),
    );
  }

  Duration remaining() {
    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  String get vehicleDisplayName => switch (vehicleType) {
        'BIKE' => 'Bike',
        'AUTO' => 'Auto',
        'CAR_MINI' => 'Mini',
        'CAR_SEDAN' => 'Sedan',
        'CAR_SUV' => 'SUV',
        _ => vehicleType,
      };

  String get distanceText => '${(estimatedDistanceMeters / 1000).toStringAsFixed(1)} km';
  String get durationText => '${(estimatedDurationSeconds / 60).round()} min';
}
