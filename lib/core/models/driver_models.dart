import 'package:flutter/material.dart';

// ── DriverProfile ──────────────────────────────────────────────────────────────

class DriverProfile {
  final String id;
  final String userId;
  final String kycStatus;
  final double rating;
  final int ratingCount;
  final int totalRides;
  final int acceptedOffers;
  final int rejectedOffers;
  final int cancelledRides;
  final bool isOnline;
  final String? rejectionReason;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DriverProfile({
    required this.id,
    required this.userId,
    required this.kycStatus,
    required this.rating,
    required this.ratingCount,
    required this.totalRides,
    required this.acceptedOffers,
    required this.rejectedOffers,
    required this.cancelledRides,
    required this.isOnline,
    this.rejectionReason,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> j) => DriverProfile(
        id: j['id'] as String,
        userId: j['userId'] as String,
        kycStatus: j['kycStatus'] as String,
        rating: (j['rating'] as num? ?? 5.0).toDouble(),
        ratingCount: j['ratingCount'] as int? ?? 0,
        totalRides: j['totalRides'] as int? ?? 0,
        acceptedOffers: j['acceptedOffers'] as int? ?? 0,
        rejectedOffers: j['rejectedOffers'] as int? ?? 0,
        cancelledRides: j['cancelledRides'] as int? ?? 0,
        isOnline: j['isOnline'] as bool? ?? false,
        rejectionReason: j['rejectionReason'] as String?,
        reviewedAt: j['reviewedAt'] != null
            ? DateTime.parse(j['reviewedAt'] as String)
            : null,
        createdAt: j['createdAt'] != null
            ? DateTime.parse(j['createdAt'] as String)
            : DateTime.now(),
        updatedAt: j['updatedAt'] != null
            ? DateTime.parse(j['updatedAt'] as String)
            : DateTime.now(),
      );

  bool get isApproved => kycStatus == 'APPROVED';
  bool get isPending => kycStatus == 'PENDING';
  bool get isDocsSubmitted => kycStatus == 'DOCS_SUBMITTED';
  bool get isUnderReview => kycStatus == 'UNDER_REVIEW';
  bool get isRejected => kycStatus == 'REJECTED';

  double get completionRate {
    if (acceptedOffers == 0) return 100.0;
    return ((totalRides / acceptedOffers) * 100).clamp(0, 100);
  }

  String get kycStatusLabel => switch (kycStatus) {
        'PENDING' => 'Pending',
        'DOCS_SUBMITTED' => 'Docs Submitted',
        'UNDER_REVIEW' => 'Under Review',
        'APPROVED' => 'Approved',
        'REJECTED' => 'Rejected',
        _ => kycStatus,
      };
}

// ── DriverVehicle ──────────────────────────────────────────────────────────────

class DriverVehicle {
  final String id;
  final String driverProfileId;
  final String type;
  final String make;
  final String model;
  final int year;
  final String plateNumber;
  final String? color;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DriverVehicle({
    required this.id,
    required this.driverProfileId,
    required this.type,
    required this.make,
    required this.model,
    required this.year,
    required this.plateNumber,
    this.color,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DriverVehicle.fromJson(Map<String, dynamic> j) => DriverVehicle(
        id: j['id'] as String,
        driverProfileId: j['driverProfileId'] as String,
        type: j['type'] as String,
        make: j['make'] as String,
        model: j['model'] as String,
        year: j['year'] as int,
        plateNumber: j['plateNumber'] as String,
        color: j['color'] as String?,
        isActive: j['isActive'] as bool? ?? true,
        createdAt: j['createdAt'] != null
            ? DateTime.parse(j['createdAt'] as String)
            : DateTime.now(),
        updatedAt: j['updatedAt'] != null
            ? DateTime.parse(j['updatedAt'] as String)
            : DateTime.now(),
      );

  String get typeLabel => switch (type) {
        'BIKE' => 'Bike',
        'AUTO' => 'Auto',
        'CAR_MINI' => 'Mini',
        'CAR_SEDAN' => 'Sedan',
        'CAR_SUV' => 'SUV',
        _ => type,
      };

  IconData get typeIcon => switch (type) {
        'BIKE' => Icons.two_wheeler,
        'AUTO' => Icons.electric_rickshaw,
        'CAR_MINI' => Icons.directions_car,
        'CAR_SEDAN' => Icons.drive_eta,
        'CAR_SUV' => Icons.airport_shuttle,
        _ => Icons.directions_car,
      };
}

// ── DriverDocument ─────────────────────────────────────────────────────────────

class DriverDocument {
  final String id;
  final String driverProfileId;
  final String type;
  final String status;
  final String mimeType;
  final int sizeBytes;
  final String? rejectionReason;
  final DateTime? expiresAt;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final String? url;

  const DriverDocument({
    required this.id,
    required this.driverProfileId,
    required this.type,
    required this.status,
    required this.mimeType,
    required this.sizeBytes,
    this.rejectionReason,
    this.expiresAt,
    this.reviewedAt,
    required this.createdAt,
    this.url,
  });

  factory DriverDocument.fromJson(Map<String, dynamic> j) => DriverDocument(
        id: j['id'] as String,
        driverProfileId: j['driverProfileId'] as String,
        type: j['type'] as String,
        status: j['status'] as String,
        mimeType: j['mimeType'] as String? ?? '',
        sizeBytes: j['sizeBytes'] as int? ?? 0,
        rejectionReason: j['rejectionReason'] as String?,
        expiresAt: j['expiresAt'] != null
            ? DateTime.parse(j['expiresAt'] as String)
            : null,
        reviewedAt: j['reviewedAt'] != null
            ? DateTime.parse(j['reviewedAt'] as String)
            : null,
        createdAt: j['createdAt'] != null
            ? DateTime.parse(j['createdAt'] as String)
            : DateTime.now(),
        url: j['url'] as String?,
      );

  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
  bool get isPending => status == 'PENDING';

  String get typeLabel => switch (type) {
        'DRIVING_LICENSE' => 'Driving License',
        'AADHAAR' => 'Aadhaar Card',
        'PAN' => 'PAN Card',
        'VEHICLE_RC' => 'Vehicle RC',
        'VEHICLE_INSURANCE' => 'Vehicle Insurance',
        'PROFILE_PHOTO' => 'Profile Photo',
        _ => type,
      };

  bool get isRequired => const {
        'DRIVING_LICENSE',
        'AADHAAR',
        'PAN',
        'PROFILE_PHOTO',
      }.contains(type);
}

// ── Required document types ────────────────────────────────────────────────────

const kRequiredDocTypes = [
  'DRIVING_LICENSE',
  'AADHAAR',
  'PAN',
  'PROFILE_PHOTO',
];

const kAllDocTypes = [
  'DRIVING_LICENSE',
  'AADHAAR',
  'PAN',
  'PROFILE_PHOTO',
  'VEHICLE_RC',
  'VEHICLE_INSURANCE',
];

const kVehicleTypes = ['BIKE', 'AUTO', 'CAR_MINI', 'CAR_SEDAN', 'CAR_SUV'];
