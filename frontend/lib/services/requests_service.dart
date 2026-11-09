import '../core/constants/app_constants.dart';
import '../models/skill_request_model.dart';
import 'api_service.dart';

class RequestsService {
  final ApiService _apiService;

  RequestsService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Fetch incoming and sent requests from `GET /api/requests/`
  Future<SkillRequestsResponse> getRequests() async {
    try {
      final response = await _apiService.get(AppConstants.requestsEndpoint);
      return SkillRequestsResponse.fromJson(response.data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to load skill requests: $e');
    }
  }

  /// Accept an incoming request via `PUT /api/requests/<id>/` with status: "accepted"
  Future<SkillRequestModel> acceptRequest(int requestId) async {
    return updateRequestStatus(requestId, 'accepted');
  }

  /// Reject an incoming request via `PUT /api/requests/<id>/` with status: "rejected"
  Future<SkillRequestModel> rejectRequest(int requestId) async {
    return updateRequestStatus(requestId, 'rejected');
  }

  /// Update request status via `PUT /api/requests/<id>/`
  Future<SkillRequestModel> updateRequestStatus(int requestId, String status) async {
    try {
      final endpoint = AppConstants.requestActionEndpoint(requestId);
      final response = await _apiService.put(
        endpoint,
        data: {'status': status},
      );

      if (response.data is Map) {
        return SkillRequestModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      throw ApiException('Invalid server response format.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to update request status: $e');
    }
  }

  /// Create and send a new skill swap request via `POST /api/requests/`
  Future<SkillRequestModel> sendRequest({
    required int targetUserId,
    required int requestedSkillId,
    int? offeredSkillId,
    String? message,
    String? learningGoal,
  }) async {
    final payload = <String, dynamic>{
      'target': targetUserId,
      'requested_skill': requestedSkillId,
    };
    if (offeredSkillId != null) {
      payload['offered_skill'] = offeredSkillId;
    }
    if (message != null && message.trim().isNotEmpty) {
      payload['message'] = message.trim();
    }
    if (learningGoal != null && learningGoal.trim().isNotEmpty) {
      payload['learning_goal'] = learningGoal.trim();
    }

    try {
      final response = await _apiService.post(
        AppConstants.requestsEndpoint,
        data: payload,
      );

      if (response.data is Map) {
        return SkillRequestModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      throw ApiException('Invalid server response format.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to send skill request: $e');
    }
  }
}
