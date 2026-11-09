import '../core/constants/app_constants.dart';
import '../models/user_profile_model.dart';
import 'api_service.dart';

class ProfileService {
  final ApiService _apiService;

  ProfileService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Fetch user profile from GET /api/auth/profile/
  Future<UserProfileModel> getProfile() async {
    try {
      final response = await _apiService.get(AppConstants.profileEndpoint);
      return _parseProfileResponse(response.data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to load user profile: $e');
    }
  }

  /// Update user profile via PUT /api/auth/profile/
  Future<UserProfileModel> updateProfile({
    required String email,
    required String phone,
    required String bio,
  }) async {
    final payload = {
      'email': email.trim(),
      'phone': phone.trim(),
      'bio': bio.trim(),
    };

    try {
      final response = await _apiService.put(
        AppConstants.profileEndpoint,
        data: payload,
      );

      if (response.data != null && response.data is Map) {
        return _parseProfileResponse(response.data);
      }

      // If backend returns 200/204 without body, return model reflecting updated fields
      return UserProfileModel(
        username: '',
        email: email.trim(),
        phone: phone.trim(),
        bio: bio.trim(),
        role: '',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to update profile: $e');
    }
  }

  /// Internal helper to defensively parse user profile response
  UserProfileModel _parseProfileResponse(dynamic data) {
    if (data is List && data.isNotEmpty) {
      return _parseProfileResponse(data.first);
    }
    if (data is Map) {
      if (data['results'] is List && (data['results'] as List).isNotEmpty) {
        return _parseProfileResponse((data['results'] as List).first);
      }
      if (data['data'] != null && data['data'] is Map) {
        return _parseProfileResponse(data['data']);
      }
      if (data['profile'] != null && data['profile'] is Map) {
        return _parseProfileResponse(data['profile']);
      }
      return UserProfileModel.fromJson(Map<String, dynamic>.from(data));
    }
    throw ApiException('Invalid profile response data from server.');
  }
}
