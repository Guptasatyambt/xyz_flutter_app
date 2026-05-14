import '../api/api_client.dart';
import '../api/api_endpoints.dart';

class RatingService {
  static Future<void> submitRating({
    required String rideId,
    required int stars,
    String? comment,
  }) async {
    final trimmed = comment?.trim();
    final res = await ApiClient.post(
      ApiEndpoints.rideRatings(rideId),
      body: {
        'stars': stars,
        'comment': ?trimmed,
      },
      auth: true,
    );
    if (res.statusCode != 201) throw ApiClient.parseError(res);
  }
}
