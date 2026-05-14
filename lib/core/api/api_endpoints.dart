class ApiEndpoints {
  // Android emulator  → 10.0.2.2 maps to host localhost
  // Physical device   → replace with your machine's LAN IP (e.g. 192.168.1.x)
  static const String baseUrl = 'https://xyz-aj1a.onrender.com';

  // Auth
  static const String otpRequest = '/v1/auth/otp/request';
  static const String otpVerify = '/v1/auth/otp/verify';
  static const String authRefresh = '/v1/auth/refresh';
  static const String authLogout = '/v1/auth/logout';

  // Users
  static const String userMe = '/v1/users/me';

  // Geo
  static const String geoNearby      = '/v1/geo/nearby';
  static const String geoEstimate    = '/v1/geo/estimate';
  static const String geoEstimateAll = '/v1/geo/estimate/all';
  static const String geoGeocode     = '/v1/geo/geocode';
  static const String geoReverse     = '/v1/geo/reverse';
  static const String geoRoute       = '/v1/geo/route';

  // Drivers
  static const String driverMe        = '/v1/drivers/me';
  static const String driverOnline    = '/v1/drivers/me/online';
  static const String driverOffline   = '/v1/drivers/me/offline';
  static const String driverVehicles  = '/v1/drivers/me/vehicles';
  static String driverVehicle(String id) => '/v1/drivers/me/vehicles/$id';
  static const String driverDocuments = '/v1/drivers/me/documents';

  // Driver rides
  static const String driverRides                        = '/v1/driver-rides';
  static String driverRideById(String id)       => '/v1/driver-rides/$id';
  static String driverRideAccept(String id)     => '/v1/driver-rides/$id/accept';
  static String driverRideReject(String id)     => '/v1/driver-rides/$id/reject';
  static String driverRideArrived(String id)    => '/v1/driver-rides/$id/arrived';
  static String driverRideStart(String id)      => '/v1/driver-rides/$id/start';
  static String driverRideComplete(String id)   => '/v1/driver-rides/$id/complete';
  static String driverRideCancel(String id)     => '/v1/driver-rides/$id/cancel';

  // Rides
  static const String rides = '/v1/rides';
  static String rideById(String id)     => '/v1/rides/$id';
  static String rideCancel(String id)   => '/v1/rides/$id/cancel';

  // Ratings
  static String rideRatings(String rideId) => '/v1/ratings/rides/$rideId';

  // Notifications
  static const String notifications        = '/v1/notifications';
  static const String notificationsReadAll = '/v1/notifications/read-all';
  static String notificationRead(String id) => '/v1/notifications/$id/read';
}
