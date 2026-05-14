class Ride {
  final String id;
  final String riderId;
  final String? driverId;
  final String? vehicleId;
  final String status;
  final String vehicleType;
  final double pickupLat;
  final double pickupLng;
  final String? pickupAddress;
  final double dropLat;
  final double dropLng;
  final String? dropAddress;
  final int estimatedDistanceMeters;
  final int estimatedDurationSeconds;
  final double estimatedFare;
  final double surgeMultiplier;
  final int? actualDistanceMeters;
  final int? actualDurationSeconds;
  final double? actualFare;
  final String? cancelReason;
  final String? cancelNote;
  final DateTime requestedAt;
  final DateTime? assignedAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  const Ride({
    required this.id,
    required this.riderId,
    this.driverId,
    this.vehicleId,
    required this.status,
    required this.vehicleType,
    required this.pickupLat,
    required this.pickupLng,
    this.pickupAddress,
    required this.dropLat,
    required this.dropLng,
    this.dropAddress,
    required this.estimatedDistanceMeters,
    required this.estimatedDurationSeconds,
    required this.estimatedFare,
    required this.surgeMultiplier,
    this.actualDistanceMeters,
    this.actualDurationSeconds,
    this.actualFare,
    this.cancelReason,
    this.cancelNote,
    required this.requestedAt,
    this.assignedAt,
    this.arrivedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
  });

  factory Ride.fromJson(Map<String, dynamic> j) => Ride(
        id: j['id'] as String,
        riderId: j['riderId'] as String,
        driverId: j['driverId'] as String?,
        vehicleId: j['vehicleId'] as String?,
        status: j['status'] as String,
        vehicleType: j['vehicleType'] as String,
        pickupLat: (j['pickupLat'] as num).toDouble(),
        pickupLng: (j['pickupLng'] as num).toDouble(),
        pickupAddress: j['pickupAddress'] as String?,
        dropLat: (j['dropLat'] as num).toDouble(),
        dropLng: (j['dropLng'] as num).toDouble(),
        dropAddress: j['dropAddress'] as String?,
        estimatedDistanceMeters: j['estimatedDistanceMeters'] as int,
        estimatedDurationSeconds: j['estimatedDurationSeconds'] as int,
        estimatedFare: (j['estimatedFare'] as num).toDouble(),
        surgeMultiplier:
            (j['surgeMultiplier'] as num? ?? 1).toDouble(),
        actualDistanceMeters: j['actualDistanceMeters'] as int?,
        actualDurationSeconds: j['actualDurationSeconds'] as int?,
        actualFare: (j['actualFare'] as num?)?.toDouble(),
        cancelReason: j['cancelReason'] as String?,
        cancelNote: j['cancelNote'] as String?,
        requestedAt: DateTime.parse(j['requestedAt'] as String),
        assignedAt: j['assignedAt'] != null
            ? DateTime.parse(j['assignedAt'] as String)
            : null,
        arrivedAt: j['arrivedAt'] != null
            ? DateTime.parse(j['arrivedAt'] as String)
            : null,
        startedAt: j['startedAt'] != null
            ? DateTime.parse(j['startedAt'] as String)
            : null,
        completedAt: j['completedAt'] != null
            ? DateTime.parse(j['completedAt'] as String)
            : null,
        cancelledAt: j['cancelledAt'] != null
            ? DateTime.parse(j['cancelledAt'] as String)
            : null,
      );

  /// `ride:state` socket event payload — uses nested `pickup`/`drop` objects
  /// instead of flat lat/lng/address keys, and may omit some fields (rider/
  /// requestedAt etc. that aren't relevant for a state update). Falls back to
  /// the current ride object's values when fields are absent.
  ///
  /// Pass the [current] ride if you have one, so we can preserve fields that
  /// the socket payload doesn't include (e.g. `riderId`, `requestedAt`).
  factory Ride.fromSocketJson(Map<String, dynamic> j, {Ride? current}) {
    final pickup = j['pickup'] as Map<String, dynamic>?;
    final drop = j['drop'] as Map<String, dynamic>?;
    DateTime? parseDate(dynamic v) =>
        v == null ? null : (v is DateTime ? v : DateTime.parse(v as String));
    return Ride(
      id: j['id'] as String? ?? current!.id,
      riderId: j['riderId'] as String? ?? current!.riderId,
      driverId: (j['driverId'] as String?) ?? current?.driverId,
      vehicleId: (j['vehicleId'] as String?) ?? current?.vehicleId,
      status: j['status'] as String,
      vehicleType: j['vehicleType'] as String? ?? current!.vehicleType,
      pickupLat: pickup != null
          ? (pickup['lat'] as num).toDouble()
          : current!.pickupLat,
      pickupLng: pickup != null
          ? (pickup['lng'] as num).toDouble()
          : current!.pickupLng,
      pickupAddress:
          (pickup?['address'] as String?) ?? current?.pickupAddress,
      dropLat:
          drop != null ? (drop['lat'] as num).toDouble() : current!.dropLat,
      dropLng:
          drop != null ? (drop['lng'] as num).toDouble() : current!.dropLng,
      dropAddress: (drop?['address'] as String?) ?? current?.dropAddress,
      estimatedDistanceMeters: (j['estimatedDistanceMeters'] as num?)?.toInt() ??
          current!.estimatedDistanceMeters,
      estimatedDurationSeconds: (j['estimatedDurationSeconds'] as num?)?.toInt() ??
          current!.estimatedDurationSeconds,
      estimatedFare: (j['estimatedFare'] as num?)?.toDouble() ??
          current!.estimatedFare,
      surgeMultiplier:
          (j['surgeMultiplier'] as num?)?.toDouble() ??
              current?.surgeMultiplier ??
              1.0,
      actualDistanceMeters: (j['actualDistanceMeters'] as num?)?.toInt() ??
          current?.actualDistanceMeters,
      actualDurationSeconds: (j['actualDurationSeconds'] as num?)?.toInt() ??
          current?.actualDurationSeconds,
      actualFare:
          (j['actualFare'] as num?)?.toDouble() ?? current?.actualFare,
      cancelReason: (j['cancelReason'] as String?) ?? current?.cancelReason,
      cancelNote: (j['cancelNote'] as String?) ?? current?.cancelNote,
      requestedAt: parseDate(j['requestedAt']) ?? current!.requestedAt,
      assignedAt: parseDate(j['assignedAt']) ?? current?.assignedAt,
      arrivedAt: parseDate(j['arrivedAt']) ?? current?.arrivedAt,
      startedAt: parseDate(j['startedAt']) ?? current?.startedAt,
      completedAt: parseDate(j['completedAt']) ?? current?.completedAt,
      cancelledAt: parseDate(j['cancelledAt']) ?? current?.cancelledAt,
    );
  }

  // ── Status helpers ─────────────────────────────────────────────────────────

  bool get isActive => const {
        'REQUESTED',
        'SEARCHING',
        'DRIVER_ARRIVING',
        'DRIVER_ARRIVED',
        'IN_PROGRESS',
      }.contains(status);

  bool get isTerminal => const {
        'COMPLETED',
        'CANCELLED_BY_RIDER',
        'CANCELLED_BY_DRIVER',
        'NO_DRIVERS_FOUND',
        'FAILED',
      }.contains(status);

  bool get canCancel => const {
        'REQUESTED',
        'SEARCHING',
        'DRIVER_ARRIVING',
      }.contains(status);

  bool get isCompleted => status == 'COMPLETED';

  bool get isCancelled =>
      status == 'CANCELLED_BY_RIDER' || status == 'CANCELLED_BY_DRIVER';

  // ── Display helpers ────────────────────────────────────────────────────────

  double get fareToShow => actualFare ?? estimatedFare;

  String get distanceText {
    final m = actualDistanceMeters ?? estimatedDistanceMeters;
    return '${(m / 1000).toStringAsFixed(1)} km';
  }

  String get durationText {
    final s = actualDurationSeconds ?? estimatedDurationSeconds;
    return '${(s / 60).round()} min';
  }

  String get vehicleDisplayName => switch (vehicleType) {
        'BIKE' => 'Bike',
        'AUTO' => 'Auto',
        'CAR_MINI' => 'Mini',
        'CAR_SEDAN' => 'Sedan',
        'CAR_SUV' => 'SUV',
        _ => vehicleType,
      };

  String get statusLabel => switch (status) {
        'REQUESTED' => 'Requested',
        'SEARCHING' => 'Finding driver',
        'DRIVER_ARRIVING' => 'Driver on the way',
        'DRIVER_ARRIVED' => 'Driver arrived',
        'IN_PROGRESS' => 'In progress',
        'COMPLETED' => 'Completed',
        'CANCELLED_BY_RIDER' => 'Cancelled',
        'CANCELLED_BY_DRIVER' => 'Cancelled by driver',
        'NO_DRIVERS_FOUND' => 'No drivers found',
        'FAILED' => 'Failed',
        _ => status,
      };

  String get statusDescription => switch (status) {
        'REQUESTED' || 'SEARCHING' =>
          'Looking for a nearby driver…',
        'DRIVER_ARRIVING' =>
          'Your driver is on the way to your pickup.',
        'DRIVER_ARRIVED' =>
          'Your driver has arrived at the pickup point.',
        'IN_PROGRESS' => 'Enjoy your ride!',
        'COMPLETED' => 'You have reached your destination.',
        'CANCELLED_BY_RIDER' => 'You cancelled this ride.',
        'CANCELLED_BY_DRIVER' => 'The driver cancelled this ride.',
        'NO_DRIVERS_FOUND' =>
          'No drivers were available. Please try again.',
        _ => 'Something went wrong.',
      };

  // Step index for the progress bar (0-indexed, -1 for terminal non-complete)
  int get stepIndex => switch (status) {
        'REQUESTED' || 'SEARCHING' => 0,
        'DRIVER_ARRIVING' => 1,
        'DRIVER_ARRIVED' => 2,
        'IN_PROGRESS' => 3,
        'COMPLETED' => 4,
        _ => -1,
      };
}

// ── Notification model ─────────────────────────────────────────────────────────

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String type;
  final String status;
  final String? rideId;
  final DateTime? readAt;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.status,
    this.rideId,
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => status == 'READ' || readAt != null;

  factory NotificationItem.fromJson(Map<String, dynamic> j) =>
      NotificationItem(
        id: j['id'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        type: j['type'] as String,
        status: j['status'] as String,
        rideId: j['rideId'] as String?,
        readAt: j['readAt'] != null
            ? DateTime.parse(j['readAt'] as String)
            : null,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
