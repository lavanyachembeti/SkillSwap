import 'package:flutter/foundation.dart';

class AppConstants {
  AppConstants._();

  /// Optional compile-time override via `--dart-define=API_BASE_URL=https://...`
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Base URL configured via `API_BASE_URL` for production deployments,
  /// defaulting to local development URLs when not provided:
  /// - Web / Chrome: http://127.0.0.1:8000
  /// - Android Emulator: http://10.0.2.2:8000
  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }
    return kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';
  }

  /// WebSocket Base URL derived from [baseUrl], converting `https://` to `wss://`
  /// and `http://` to `ws://`.
  static String get wsBaseUrl => wsBaseUrlFor(baseUrl);

  /// Converts an HTTP/HTTPS base URL to its corresponding WS/WSS base URL.
  static String wsBaseUrlFor(String httpBaseUrl) {
    final trimmed = httpBaseUrl.trim().endsWith('/')
        ? httpBaseUrl.trim().substring(0, httpBaseUrl.trim().length - 1)
        : httpBaseUrl.trim();
    if (trimmed.startsWith('https://')) {
      return 'wss://${trimmed.substring(8)}';
    }
    if (trimmed.startsWith('http://')) {
      return 'ws://${trimmed.substring(7)}';
    }
    return trimmed;
  }

  /// WebSocket endpoint URL for a specific chat conversation.
  static String chatWebSocketUrl(
    int conversationId, {
    String? token,
    String? overrideBaseUrl,
  }) {
    final resolvedWsBase = overrideBaseUrl != null
        ? wsBaseUrlFor(overrideBaseUrl)
        : wsBaseUrl;
    final endpoint = '$resolvedWsBase/ws/chat/$conversationId/';
    if (token != null && token.trim().isNotEmpty) {
      return '$endpoint?token=${Uri.encodeQueryComponent(token.trim())}';
    }
    return endpoint;
  }

  /// Authentication Endpoints
  static const String registerEndpoint = '/api/auth/register/';
  static const String loginEndpoint = '/api/auth/login/';
  static const String refreshEndpoint = '/api/auth/token/refresh/';
  static const String profileEndpoint = '/api/auth/profile/';

  /// Skills Endpoints
  static const String skillsEndpoint = '/api/skills/';
  static const String mySkillsEndpoint = '/api/skills/my-skills/';

  /// Discovery Endpoints
  static const String discoveryUsersEndpoint = '/api/discovery/users/';

  /// Requests Endpoints
  static const String requestsEndpoint = '/api/requests/';
  static String requestActionEndpoint(int id) => '/api/requests/$id/';

  /// Chat Endpoints
  static const String conversationsEndpoint = '/api/chat/conversations/';
  static String conversationMessagesEndpoint(int id) =>
      '/api/chat/conversations/$id/messages/';

  /// Admin Portal Endpoints
  static const String adminDashboardStatsEndpoint = '/api/admin/dashboard-stats/';
  static const String adminUsersEndpoint = '/api/admin/users/';
  static String adminUserDetailEndpoint(int id) => '/api/admin/users/$id/';
  static String adminUserVerifyEndpoint(int id) => '/api/admin/users/$id/verify/';
  static String adminUserStatusEndpoint(int id) => '/api/admin/users/$id/status/';
  static const String adminSkillsEndpoint = '/api/admin/skills/';
  static String adminSkillDetailEndpoint(int id) => '/api/admin/skills/$id/';
  static const String adminRequestsEndpoint = '/api/admin/requests/';
  static String adminRequestStatusEndpoint(int id) =>
      '/api/admin/requests/$id/status/';
  static const String adminConversationsEndpoint = '/api/admin/conversations/';
  static String adminConversationMessagesEndpoint(int id) =>
      '/api/admin/conversations/$id/messages/';
  static String adminConversationStatusEndpoint(int id) =>
      '/api/admin/conversations/$id/status/';
  static const String adminMessagingPolicyEndpoint =
      '/api/admin/messaging-policy/';
  static const String adminMessagingRestrictionsEndpoint =
      '/api/admin/messaging-restrictions/';
  static String adminMessagingRestrictionReleaseEndpoint(int id) =>
      '/api/admin/messaging-restrictions/$id/release/';
  static const String adminReportsEndpoint = '/api/admin/reports/';
  static String adminReportResolveEndpoint(int id) =>
      '/api/admin/reports/$id/resolve/';
  static const String adminAuditLogsEndpoint = '/api/admin/audit-logs/';

  /// Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
}
