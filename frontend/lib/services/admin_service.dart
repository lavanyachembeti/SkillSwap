import '../core/constants/app_constants.dart';
import '../models/admin_models.dart';
import 'api_service.dart';

class AdminService {
  final ApiService _apiService;

  AdminService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Fetch live platform statistics from GET /api/admin/dashboard-stats/
  Future<AdminDashboardStatsModel> getDashboardStats() async {
    final response = await _apiService.get(
      AppConstants.adminDashboardStatsEndpoint,
    );
    if (response.data is Map) {
      return AdminDashboardStatsModel.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    }
    throw ApiException('Invalid dashboard statistics response from server.');
  }

  /// Fetch paginated, searchable, filterable users from GET /api/admin/users/
  Future<AdminPaginatedResponse<AdminUserModel>> getUsers({
    String? search,
    String? role,
    String? status,
    bool? isVerified,
    int page = 1,
    int pageSize = 25,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (role != null && role.trim().isNotEmpty && role != 'all') {
      queryParams['role'] = role.trim();
    }
    if (status != null && status.trim().isNotEmpty && status != 'all') {
      queryParams['status'] = status.trim();
    }
    if (isVerified != null) {
      queryParams['is_verified'] = isVerified.toString();
    }

    final response = await _apiService.get(
      AppConstants.adminUsersEndpoint,
      queryParameters: queryParams,
    );
    return AdminPaginatedResponse.fromJson(
      response.data,
      AdminUserModel.fromJson,
    );
  }

  /// Fetch complete user details from GET /api/admin/users/{id}/
  Future<AdminUserModel> getUserDetail(int userId) async {
    final response = await _apiService.get(
      AppConstants.adminUserDetailEndpoint(userId),
    );
    if (response.data is Map) {
      return AdminUserModel.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    }
    throw ApiException('Invalid user detail response.');
  }

  /// Update user profile / role via PUT /api/admin/users/{id}/
  Future<AdminUserModel> updateUser(
    int userId, {
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? bio,
    String? role,
    String? reason,
  }) async {
    final payload = <String, dynamic>{};
    if (firstName != null) payload['first_name'] = firstName.trim();
    if (lastName != null) payload['last_name'] = lastName.trim();
    if (email != null) payload['email'] = email.trim();
    if (phone != null) payload['phone'] = phone.trim();
    if (bio != null) payload['bio'] = bio.trim();
    if (role != null) payload['role'] = role.trim();
    if (reason != null && reason.trim().isNotEmpty) {
      payload['reason'] = reason.trim();
    }

    final response = await _apiService.put(
      AppConstants.adminUserDetailEndpoint(userId),
      data: payload,
    );
    if (response.data is Map) {
      return AdminUserModel.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    }
    throw ApiException('Invalid user update response.');
  }

  /// Verify or revoke user verification via POST /api/admin/users/{id}/verify/
  Future<Map<String, dynamic>> verifyUser(
    int userId, {
    required bool isVerified,
    String? reason,
  }) async {
    final response = await _apiService.post(
      AppConstants.adminUserVerifyEndpoint(userId),
      data: {
        'is_verified': isVerified,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {'is_verified': isVerified};
  }

  /// Update user status (suspend, reactivate, activate, deactivate) via POST /api/admin/users/{id}/status/
  Future<Map<String, dynamic>> updateUserStatus(
    int userId, {
    required String action,
    String? reason,
    int? durationDays,
  }) async {
    final response = await _apiService.post(
      AppConstants.adminUserStatusEndpoint(userId),
      data: {
        'action': action,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        if (durationDays != null && durationDays > 0)
          'duration_days': durationDays,
      },
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {'action': action};
  }

  /// Fetch skills from GET /api/admin/skills/
  Future<AdminPaginatedResponse<AdminSkillModel>> getSkills({
    String? search,
    String? category,
    bool? isActive,
    int page = 1,
    int pageSize = 50,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (category != null && category.trim().isNotEmpty && category != 'all') {
      queryParams['category'] = category.trim();
    }
    if (isActive != null) {
      queryParams['is_active'] = isActive.toString();
    }

    final response = await _apiService.get(
      AppConstants.adminSkillsEndpoint,
      queryParameters: queryParams,
    );
    return AdminPaginatedResponse.fromJson(
      response.data,
      AdminSkillModel.fromJson,
    );
  }

  /// Fetch single skill detail including associated users from GET /api/admin/skills/{id}/
  Future<AdminSkillModel> getSkillDetail(int skillId) async {
    final response = await _apiService.get(
      AppConstants.adminSkillDetailEndpoint(skillId),
    );
    if (response.data is Map) {
      return AdminSkillModel.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    }
    throw ApiException('Invalid skill detail response.');
  }

  /// Create a new skill via POST /api/admin/skills/
  Future<AdminSkillModel> createSkill({
    required String name,
    required String category,
    String description = '',
    bool isActive = true,
  }) async {
    final response = await _apiService.post(
      AppConstants.adminSkillsEndpoint,
      data: {
        'name': name.trim(),
        'category': category.trim().isEmpty ? 'General' : category.trim(),
        'description': description.trim(),
        'is_active': isActive,
      },
    );
    if (response.data is Map) {
      return AdminSkillModel.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    }
    throw ApiException('Failed to create skill.');
  }

  /// Update a skill via PUT /api/admin/skills/{id}/
  Future<AdminSkillModel> updateSkill(
    int skillId, {
    String? name,
    String? category,
    String? description,
    bool? isActive,
    String? reason,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name.trim();
    if (category != null) payload['category'] = category.trim();
    if (description != null) payload['description'] = description.trim();
    if (isActive != null) payload['is_active'] = isActive;
    if (reason != null && reason.trim().isNotEmpty) {
      payload['reason'] = reason.trim();
    }

    final response = await _apiService.put(
      AppConstants.adminSkillDetailEndpoint(skillId),
      data: payload,
    );
    if (response.data is Map) {
      return AdminSkillModel.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    }
    throw ApiException('Failed to update skill.');
  }

  /// Delete unreferenced skill or safely deactivate referenced skill via DELETE /api/admin/skills/{id}/
  Future<Map<String, dynamic>> deleteOrDeactivateSkill(
    int skillId, {
    String? reason,
  }) async {
    final response = await _apiService.delete(
      AppConstants.adminSkillDetailEndpoint(skillId),
      data: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {'action_taken': 'deleted'};
  }

  /// Fetch skill-swap requests from GET /api/admin/requests/
  Future<AdminPaginatedResponse<AdminSkillRequestModel>> getRequests({
    String? search,
    String? status,
    int? userId,
    int page = 1,
    int pageSize = 50,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (status != null && status.trim().isNotEmpty && status != 'all') {
      queryParams['status'] = status.trim();
    }
    if (userId != null) {
      queryParams['user_id'] = userId;
    }

    final response = await _apiService.get(
      AppConstants.adminRequestsEndpoint,
      queryParameters: queryParams,
    );
    return AdminPaginatedResponse.fromJson(
      response.data,
      AdminSkillRequestModel.fromJson,
    );
  }

  /// Override skill-swap request status via POST /api/admin/requests/{id}/status/
  Future<Map<String, dynamic>> updateRequestStatus(
    int requestId, {
    required String status,
    String? reason,
  }) async {
    final response = await _apiService.post(
      AppConstants.adminRequestStatusEndpoint(requestId),
      data: {
        'status': status,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {'status': status};
  }

  /// Fetch conversations from GET /api/admin/conversations/
  Future<AdminPaginatedResponse<AdminConversationModel>> getConversations({
    String? search,
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (status != null && status.trim().isNotEmpty && status != 'all') {
      queryParams['status'] = status.trim();
    }

    final response = await _apiService.get(
      AppConstants.adminConversationsEndpoint,
      queryParameters: queryParams,
    );
    return AdminPaginatedResponse.fromJson(
      response.data,
      AdminConversationModel.fromJson,
    );
  }

  /// Inspect conversation message history for moderation via GET /api/admin/conversations/{id}/messages/
  Future<AdminConversationDetailModel> getConversationMessages(
    int conversationId,
  ) async {
    final response = await _apiService.get(
      AppConstants.adminConversationMessagesEndpoint(conversationId),
    );
    if (response.data is Map) {
      return AdminConversationDetailModel.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    }
    throw ApiException('Invalid conversation messages response.');
  }

  /// Update conversation moderation status via POST /api/admin/conversations/{id}/status/
  Future<AdminConversationModel> updateConversationStatus(
    int conversationId, {
    required String action,
    String? reason,
  }) async {
    final response = await _apiService.post(
      AppConstants.adminConversationStatusEndpoint(conversationId),
      data: {
        'action': action,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    if (response.data is Map) {
      final map = Map<String, dynamic>.from(response.data as Map);
      if (map['conversation'] is Map) {
        return AdminConversationModel.fromJson(
          Map<String, dynamic>.from(map['conversation'] as Map),
        );
      }
      return AdminConversationModel.fromJson(map);
    }
    throw ApiException('Invalid conversation status update response.');
  }

  /// Fetch messaging policy & active restrictions from GET /api/admin/messaging-policy/
  Future<AdminMessagingPolicyEnvelope> getMessagingPolicy() async {
    final response = await _apiService.get(
      AppConstants.adminMessagingPolicyEndpoint,
    );
    if (response.data is Map) {
      return AdminMessagingPolicyEnvelope.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    }
    throw ApiException('Invalid messaging policy response.');
  }

  /// Update messaging policy via PUT /api/admin/messaging-policy/
  Future<AdminMessagingPolicyModel> updateMessagingPolicy({
    required int maxMessagesPerMinute,
    required int maxMessagesPerConversationPerDay,
    required int maxMessagesPerUserPerDay,
    required int warningThresholdPercent,
    required int cooldownMinutes,
    required bool enforceAcceptedRequest,
    required bool enableRateLimiting,
    String? reason,
  }) async {
    final response = await _apiService.put(
      AppConstants.adminMessagingPolicyEndpoint,
      data: {
        'max_messages_per_minute': maxMessagesPerMinute,
        'max_messages_per_conversation_per_day':
            maxMessagesPerConversationPerDay,
        'max_messages_per_user_per_day': maxMessagesPerUserPerDay,
        'warning_threshold_percent': warningThresholdPercent,
        'cooldown_minutes': cooldownMinutes,
        'enforce_accepted_request': enforceAcceptedRequest,
        'enable_rate_limiting': enableRateLimiting,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    if (response.data is Map) {
      final map = Map<String, dynamic>.from(response.data as Map);
      if (map['policy'] is Map) {
        return AdminMessagingPolicyModel.fromJson(
          Map<String, dynamic>.from(map['policy'] as Map),
        );
      }
      return AdminMessagingPolicyModel.fromJson(map);
    }
    throw ApiException('Failed to update messaging policy.');
  }

  /// Create a temporary user messaging restriction via POST /api/admin/messaging-restrictions/
  Future<AdminMessagingRestrictionModel> createMessagingRestriction({
    required int userId,
    required int durationMinutes,
    required String reason,
  }) async {
    final response = await _apiService.post(
      AppConstants.adminMessagingRestrictionsEndpoint,
      data: {
        'user_id': userId,
        'duration_minutes': durationMinutes,
        'reason': reason.trim(),
      },
    );
    if (response.data is Map) {
      return AdminMessagingRestrictionModel.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    }
    throw ApiException('Failed to create messaging restriction.');
  }

  /// Release an active user messaging restriction via POST /api/admin/messaging-restrictions/{id}/release/
  Future<Map<String, dynamic>> releaseMessagingRestriction(
    int restrictionId, {
    String? reason,
  }) async {
    final response = await _apiService.post(
      AppConstants.adminMessagingRestrictionReleaseEndpoint(restrictionId),
      data: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {'id': restrictionId, 'is_active': false};
  }

  /// Fetch moderation reports from GET /api/admin/reports/
  Future<AdminPaginatedResponse<AdminUserReportModel>> getReports({
    String? search,
    String? status,
    String? reason,
    int page = 1,
    int pageSize = 50,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (status != null && status.trim().isNotEmpty && status != 'all') {
      queryParams['status'] = status.trim();
    }
    if (reason != null && reason.trim().isNotEmpty && reason != 'all') {
      queryParams['reason'] = reason.trim();
    }

    final response = await _apiService.get(
      AppConstants.adminReportsEndpoint,
      queryParameters: queryParams,
    );
    return AdminPaginatedResponse.fromJson(
      response.data,
      AdminUserReportModel.fromJson,
    );
  }

  /// Update / resolve / dismiss a report via POST /api/admin/reports/{id}/resolve/
  Future<Map<String, dynamic>> resolveReport(
    int reportId, {
    required String action,
    String? adminNotes,
    bool suspendUser = false,
  }) async {
    final response = await _apiService.post(
      AppConstants.adminReportResolveEndpoint(reportId),
      data: {
        'action': action,
        if (adminNotes != null) 'admin_notes': adminNotes.trim(),
        'suspend_user': suspendUser,
      },
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {'id': reportId, 'status': action};
  }

  /// Fetch audit logs from GET /api/admin/audit-logs/
  Future<AdminPaginatedResponse<AdminAuditLogModel>> getAuditLogs({
    String? search,
    String? action,
    String? targetModel,
    String? targetId,
    String? adminUsername,
    int page = 1,
    int pageSize = 50,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (action != null && action.trim().isNotEmpty && action != 'all') {
      queryParams['action'] = action.trim();
    }
    if (targetModel != null &&
        targetModel.trim().isNotEmpty &&
        targetModel != 'all') {
      queryParams['target_model'] = targetModel.trim();
    }
    if (targetId != null && targetId.trim().isNotEmpty) {
      queryParams['target_id'] = targetId.trim();
    }
    if (adminUsername != null && adminUsername.trim().isNotEmpty) {
      queryParams['admin_username'] = adminUsername.trim();
    }

    final response = await _apiService.get(
      AppConstants.adminAuditLogsEndpoint,
      queryParameters: queryParams,
    );
    return AdminPaginatedResponse.fromJson(
      response.data,
      AdminAuditLogModel.fromJson,
    );
  }
}
