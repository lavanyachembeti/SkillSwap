import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/models/admin_models.dart';
import 'package:frontend/models/user_profile_model.dart';
import 'package:frontend/navigation/app_router.dart';
import 'package:frontend/screens/admin/admin_dashboard_screen.dart';
import 'package:frontend/services/admin_service.dart';
import 'package:frontend/services/profile_service.dart';
import 'package:frontend/services/storage_service.dart';

class FakeStorageService extends StorageService {
  bool cleared = false;
  @override
  Future<void> clearTokens() async {
    cleared = true;
  }
}

class FakeProfileService extends ProfileService {
  UserProfileModel profile;
  FakeProfileService(this.profile);

  @override
  Future<UserProfileModel> getProfile() async => profile;

  @override
  Future<UserProfileModel> updateProfile({
    required String email,
    required String phone,
    required String bio,
  }) async {
    profile = profile.copyWith(email: email, phone: phone, bio: bio);
    return profile;
  }
}

class FakeAdminService extends AdminService {
  int verifyCalls = 0;
  int statusCalls = 0;
  int skillCreateCalls = 0;
  int requestStatusCalls = 0;
  int reportResolveCalls = 0;
  int policyUpdateCalls = 0;

  @override
  Future<AdminDashboardStatsModel> getDashboardStats() async {
    return AdminDashboardStatsModel.fromJson({
      'total_users': 14,
      'total_students': 9,
      'total_professionals': 4,
      'total_administrators': 2,
      'active_users': 12,
      'inactive_users': 1,
      'suspended_users': 1,
      'verified_users': 10,
      'unverified_users': 4,
      'recently_registered_users': 3,
      'recent_users': [
        {
          'id': 101,
          'username': 'alice_student',
          'first_name': 'Alice',
          'last_name': 'Walker',
          'full_name': 'Alice Walker',
          'email': 'alice@example.com',
          'role': 'student',
          'phone': '+1234567890',
          'is_verified': false,
          'is_active': true,
          'is_suspended': false,
          'account_status': 'pending_verification',
          'date_joined': '2026-11-01T10:00:00Z',
        },
      ],
      'total_skills': 8,
      'active_skills': 7,
      'inactive_skills': 1,
      'total_users_teaching_skills': 6,
      'total_users_learning_skills': 11,
      'total_requests': 15,
      'pending_requests': 4,
      'accepted_requests': 8,
      'rejected_requests': 2,
      'cancelled_requests': 1,
      'total_conversations': 6,
      'total_messages': 42,
      'recent_messages': 12,
      'reported_conversations': 1,
      'total_reports': 3,
      'pending_reports': 2,
      'under_review_reports': 0,
      'resolved_reports': 1,
      'dismissed_reports': 0,
      'total_audit_logs': 19,
      'recent_admin_activities': [
        {
          'id': 501,
          'admin_username': 'lavanya',
          'action': 'user_verify',
          'target_model': 'User',
          'target_id': '102',
          'target_repr': 'bob_pro',
          'reason': 'Verified professional credentials',
          'description':
              'user_verify on bob_pro — Verified professional credentials',
          'status': 'success',
          'created_at': '2026-11-05T09:30:00Z',
        },
      ],
    });
  }

  @override
  Future<AdminPaginatedResponse<AdminUserModel>> getUsers({
    String? search,
    String? role,
    String? status,
    bool? isVerified,
    int page = 1,
    int pageSize = 25,
  }) async {
    final all = [
      AdminUserModel.fromJson({
        'id': 101,
        'username': 'alice_student',
        'first_name': 'Alice',
        'last_name': 'Walker',
        'full_name': 'Alice Walker',
        'email': 'alice@example.com',
        'role': 'student',
        'phone': '+1234567890',
        'is_verified': false,
        'is_active': true,
        'is_suspended': false,
        'account_status': 'pending_verification',
        'date_joined': '2026-11-01T10:00:00Z',
      }),
      AdminUserModel.fromJson({
        'id': 102,
        'username': 'bob_pro',
        'first_name': 'Bob',
        'last_name': 'Martin',
        'full_name': 'Bob Martin',
        'email': 'bob@example.com',
        'role': 'professional',
        'phone': '+1987654321',
        'is_verified': true,
        'is_active': true,
        'is_suspended': false,
        'account_status': 'active',
        'date_joined': '2026-10-20T10:00:00Z',
      }),
    ];
    final filtered = all.where((u) {
      if (role != null && role.isNotEmpty && u.role != role) return false;
      if (search != null &&
          search.isNotEmpty &&
          !u.username.toLowerCase().contains(search.toLowerCase()) &&
          !u.fullName.toLowerCase().contains(search.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return AdminPaginatedResponse(
      count: filtered.length,
      page: 1,
      pageSize: 20,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      results: filtered,
    );
  }

  @override
  Future<AdminUserModel> getUserDetail(int userId) async {
    return AdminUserModel.fromJson({
      'id': userId,
      'username': 'alice_student',
      'first_name': 'Alice',
      'last_name': 'Walker',
      'full_name': 'Alice Walker',
      'email': 'alice@example.com',
      'role': 'student',
      'phone': '+1234567890',
      'bio': 'CS student learning Flutter',
      'is_verified': false,
      'is_active': true,
      'is_suspended': false,
      'account_status': 'pending_verification',
      'date_joined': '2026-11-01T10:00:00Z',
      'skills_teaching': [
        {
          'id': 1,
          'skill_id': 10,
          'name': 'Python',
          'category': 'Tech',
          'proficiency': 'Advanced',
        },
      ],
      'skills_learning': [
        {
          'id': 2,
          'skill_id': 11,
          'name': 'Flutter',
          'category': 'Mobile',
          'proficiency': 'Beginner',
        },
      ],
      'sent_requests_count': 1,
      'received_requests_count': 0,
      'sent_requests': [
        {
          'id': 301,
          'target_id': 102,
          'target_username': 'bob_pro',
          'requested_skill_name': 'Flutter',
          'offered_skill_name': 'Python',
          'status': 'pending',
          'created_at': '2026-11-02T10:00:00Z',
        },
      ],
      'received_requests': [],
      'conversations_count': 1,
      'reports_received_count': 0,
      'account_activity': [],
    });
  }

  @override
  Future<Map<String, dynamic>> verifyUser(
    int userId, {
    required bool isVerified,
    String? reason,
  }) async {
    verifyCalls++;
    return {'id': userId, 'is_verified': isVerified};
  }

  @override
  Future<Map<String, dynamic>> updateUserStatus(
    int userId, {
    required String action,
    String? reason,
    int? durationDays,
  }) async {
    statusCalls++;
    return {'id': userId, 'action': action};
  }

  @override
  Future<AdminPaginatedResponse<AdminSkillModel>> getSkills({
    String? search,
    String? category,
    bool? isActive,
    int page = 1,
    int pageSize = 50,
  }) async {
    return AdminPaginatedResponse(
      count: 1,
      page: 1,
      pageSize: 50,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      results: [
        AdminSkillModel.fromJson({
          'id': 10,
          'name': 'Python Programming',
          'category': 'Technology',
          'description': 'Backend & Data Science',
          'is_active': true,
          'teaching_users_count': 1,
          'learning_users_count': 1,
          'requests_count': 2,
          'teaching_users': [
            {
              'id': 1,
              'user_id': 102,
              'username': 'bob_pro',
              'full_name': 'Bob Martin',
              'email': 'bob@example.com',
              'role': 'professional',
              'proficiency': 'Expert',
            },
          ],
          'learning_users': [
            {
              'id': 2,
              'user_id': 101,
              'username': 'alice_student',
              'full_name': 'Alice Walker',
              'email': 'alice@example.com',
              'role': 'student',
              'proficiency': 'Beginner',
            },
          ],
        }),
      ],
    );
  }

  @override
  Future<AdminSkillModel> createSkill({
    required String name,
    required String category,
    String description = '',
    bool isActive = true,
  }) async {
    skillCreateCalls++;
    return AdminSkillModel(
      id: 99,
      name: name,
      category: category,
      description: description,
      isActive: isActive,
    );
  }

  @override
  Future<AdminPaginatedResponse<AdminSkillRequestModel>> getRequests({
    String? search,
    String? status,
    int? userId,
    int page = 1,
    int pageSize = 50,
  }) async {
    return AdminPaginatedResponse(
      count: 1,
      page: 1,
      pageSize: 30,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      results: [
        AdminSkillRequestModel.fromJson({
          'id': 301,
          'requester': 101,
          'requester_username': 'alice_student',
          'requester_full_name': 'Alice Walker',
          'requester_email': 'alice@example.com',
          'target': 102,
          'target_username': 'bob_pro',
          'target_full_name': 'Bob Martin',
          'target_email': 'bob@example.com',
          'requested_skill': 10,
          'requested_skill_name': 'Python Programming',
          'offered_skill': 11,
          'offered_skill_name': 'UI Design',
          'message': 'Would love to swap Python for UI Design!',
          'learning_goal': 'Build Django APIs',
          'status': 'pending',
          'created_at': '2026-11-04T12:00:00Z',
        }),
      ],
    );
  }

  @override
  Future<Map<String, dynamic>> updateRequestStatus(
    int requestId, {
    required String status,
    String? reason,
  }) async {
    requestStatusCalls++;
    return {'id': requestId, 'status': status};
  }

  @override
  Future<AdminPaginatedResponse<AdminConversationModel>> getConversations({
    String? search,
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async {
    return AdminPaginatedResponse(
      count: 1,
      page: 1,
      pageSize: 30,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      results: [
        AdminConversationModel.fromJson({
          'id': 401,
          'user1': 101,
          'user1_username': 'alice_student',
          'user2': 102,
          'user2_username': 'bob_pro',
          'messages_count': 3,
          'last_message': 'See you at 5 PM!',
          'conversation_status': 'active',
          'has_accepted_request': true,
        }),
      ],
    );
  }

  @override
  Future<AdminPaginatedResponse<AdminUserReportModel>> getReports({
    String? search,
    String? status,
    String? reason,
    int page = 1,
    int pageSize = 50,
  }) async {
    return AdminPaginatedResponse(
      count: 1,
      page: 1,
      pageSize: 30,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      results: [
        AdminUserReportModel.fromJson({
          'id': 601,
          'reporter': 101,
          'reporter_username': 'alice_student',
          'reported_user': 102,
          'reported_username': 'bob_pro',
          'reason': 'spam',
          'description': 'Unsolicited links',
          'status': 'pending',
          'admin_notes': '',
          'created_at': '2026-11-04T15:00:00Z',
        }),
      ],
    );
  }

  @override
  Future<AdminPaginatedResponse<AdminAuditLogModel>> getAuditLogs({
    String? search,
    String? action,
    String? targetModel,
    String? targetId,
    String? adminUsername,
    int page = 1,
    int pageSize = 50,
  }) async {
    return AdminPaginatedResponse(
      count: 1,
      page: 1,
      pageSize: 40,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      results: [
        AdminAuditLogModel.fromJson({
          'id': 501,
          'admin_username': 'lavanya',
          'action': 'user_verify',
          'target_model': 'User',
          'target_id': '102',
          'target_repr': 'bob_pro',
          'reason': 'Verified professional credentials',
          'status': 'success',
          'created_at': '2026-11-05T09:30:00Z',
        }),
      ],
    );
  }

  @override
  Future<AdminMessagingPolicyEnvelope> getMessagingPolicy() async {
    return AdminMessagingPolicyEnvelope.fromJson({
      'policy': {
        'id': 1,
        'max_messages_per_minute': 5,
        'max_messages_per_conversation_per_day': 50,
        'max_messages_per_user_per_day': 100,
        'warning_threshold_percent': 80,
        'cooldown_minutes': 15,
        'enforce_accepted_request': true,
        'enable_rate_limiting': true,
      },
      'active_restrictions_count': 0,
      'active_restrictions': [],
    });
  }

  @override
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
    policyUpdateCalls++;
    return AdminMessagingPolicyModel(
      maxMessagesPerMinute: maxMessagesPerMinute,
      maxMessagesPerConversationPerDay: maxMessagesPerConversationPerDay,
      maxMessagesPerUserPerDay: maxMessagesPerUserPerDay,
      warningThresholdPercent: warningThresholdPercent,
      cooldownMinutes: cooldownMinutes,
      enforceAcceptedRequest: enforceAcceptedRequest,
      enableRateLimiting: enableRateLimiting,
    );
  }
}

void main() {
  final lavanyaProfile = UserProfileModel(
    id: 1,
    username: 'lavanya',
    email: 'lavanya@skillswap.com',
    phone: '+919999999999',
    bio: 'Platform Super Administrator',
    role: 'student',
    isStaff: true,
    isSuperuser: true,
    isAdmin: true,
    isVerified: true,
  );

  final normalStudentProfile = UserProfileModel(
    id: 2,
    username: 'normal_student',
    email: 'student@skillswap.com',
    phone: '',
    bio: '',
    role: 'student',
    isStaff: false,
    isSuperuser: false,
    isAdmin: false,
  );

  group('Admin Portal Authorization, Navigation & Functionality Tests', () {
    testWidgets(
      'denies normal student access and clears tokens with restriction banner',
      (tester) async {
        final storage = FakeStorageService();
        await tester.pumpWidget(
          MaterialApp(
            routes: {
              AppRouter.login: (_) => const Scaffold(body: Text('Login Page')),
            },
            home: AdminDashboardScreen(
              profileService: FakeProfileService(normalStudentProfile),
              storageService: storage,
              adminService: FakeAdminService(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Administrator Access Restricted'), findsOneWidget);
        expect(
          find.text('Access Denied: You do not have administrator permissions.'),
          findsOneWidget,
        );
        expect(storage.cleared, isTrue);
      },
    );

    testWidgets(
      'allows lavanya superuser (role=student, isStaff=true, isSuperuser=true) and renders live stats',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: AdminDashboardScreen(
              profileService: FakeProfileService(lavanyaProfile),
              storageService: FakeStorageService(),
              adminService: FakeAdminService(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Welcome, lavanya!'), findsOneWidget);
        expect(find.text('14'), findsWidgets); // total_users
        expect(find.text('9'), findsWidgets); // total_students
        expect(find.text('Alice Walker (@alice_student)'), findsOneWidget);
        expect(
          find.text(
            'user_verify on bob_pro — Verified professional credentials',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'navigates across all 9 admin sections and executes user, skill, request, and policy actions',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final adminService = FakeAdminService();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: AdminDashboardScreen(
              profileService: FakeProfileService(lavanyaProfile),
              storageService: FakeStorageService(),
              adminService: adminService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Navigate to User Management
        await tester.tap(find.text('User Management').first);
        await tester.pumpAndSettle();
        expect(find.text('Alice Walker'), findsOneWidget);
        expect(find.text('Bob Martin'), findsOneWidget);

        // Verify user action from table
        final verifyBtn = find.byTooltip('Verify Account').first;
        await tester.ensureVisible(verifyBtn);
        await tester.pumpAndSettle();
        await tester.tap(verifyBtn);
        await tester.pumpAndSettle();
        expect(adminService.verifyCalls, equals(1));

        // 2. Navigate to Skill Management
        await tester.tap(find.text('Skill Management').first);
        await tester.pumpAndSettle();
        expect(find.textContaining('Python Programming'), findsOneWidget);

        // 3. Navigate to Skill-Swap Requests
        await tester.tap(find.text('Skill-Swap Requests').first);
        await tester.pumpAndSettle();
        expect(find.text('Request #301'), findsOneWidget);
        await tester.tap(find.text('Accept').first);
        await tester.pumpAndSettle();
        expect(adminService.requestStatusCalls, equals(1));

        // 4. Navigate to Chat Management
        await tester.tap(find.text('Chat Management').first);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Conversation #401: @alice_student & @bob_pro'),
          findsOneWidget,
        );

        // 5. Navigate to Reports & Moderation
        await tester.tap(find.text('Reports & Moderation').first);
        await tester.pumpAndSettle();
        expect(find.text('Report #601'), findsOneWidget);

        // 6. Navigate to Audit Logs
        await tester.tap(find.text('Audit Logs').first);
        await tester.pumpAndSettle();
        expect(find.textContaining('user_verify'), findsWidgets);

        // 7. Navigate to Messaging Policies
        await tester.tap(find.text('Messaging Policies').first);
        await tester.pumpAndSettle();
        expect(
          find.text('Messaging Policies & Rate Limits'),
          findsOneWidget,
        );
        await tester.tap(find.text('Save Policy Settings'));
        await tester.pumpAndSettle();
        expect(adminService.policyUpdateCalls, equals(1));

        // 8. Navigate to Admin Settings
        await tester.tap(find.text('Admin Settings').first);
        await tester.pumpAndSettle();
        expect(
          find.text('Admin Settings & Security Profile'),
          findsOneWidget,
        );

        // 9. Repeatedly switch back and forth across sidebar sections
        await tester.tap(find.text('Skill Management').first);
        await tester.pumpAndSettle();
        expect(find.textContaining('Python Programming'), findsOneWidget);

        await tester.tap(find.text('Chat Management').first);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Conversation #401: @alice_student & @bob_pro'),
          findsOneWidget,
        );

        await tester.tap(find.text('Reports & Moderation').first);
        await tester.pumpAndSettle();
        expect(find.text('Report #601'), findsOneWidget);

        await tester.tap(find.text('Overview').first);
        await tester.pumpAndSettle();
        expect(find.text('Welcome, lavanya!'), findsOneWidget);
      },
    );

    testWidgets(
      'preserves User Profile Details popup (all 4 tabs, edit, verify, suspend, close) under AppTheme.lightTheme',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final adminService = FakeAdminService();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: AdminDashboardScreen(
              profileService: FakeProfileService(lavanyaProfile),
              storageService: FakeStorageService(),
              adminService: adminService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to User Management and open User Profile Details popup
        await tester.tap(find.text('User Management').first);
        await tester.pumpAndSettle();
        final viewProfileBtn =
            find.byTooltip('View Complete Profile & Details').first;
        await tester.ensureVisible(viewProfileBtn);
        await tester.pumpAndSettle();
        await tester.tap(viewProfileBtn);
        await tester.pumpAndSettle();

        // Verify all 4 tabs and controls exist
        expect(find.text('Profile & Actions'), findsOneWidget);
        expect(find.textContaining('Skills ('), findsOneWidget);
        expect(find.textContaining('Requests ('), findsOneWidget);
        expect(find.textContaining('Activity ('), findsOneWidget);
        expect(find.text('Edit Profile Information'), findsOneWidget);
        expect(find.text('Save Changes'), findsOneWidget);
        expect(find.text('Verify Account'), findsOneWidget);
        expect(find.text('Suspend Account'), findsOneWidget);
        expect(find.text('Close'), findsOneWidget);

        // Switch through tabs inside the popup
        await tester.tap(find.textContaining('Skills ('));
        await tester.pumpAndSettle();
        expect(find.textContaining('Teaching Skills'), findsOneWidget);

        await tester.tap(find.textContaining('Requests ('));
        await tester.pumpAndSettle();
        expect(find.textContaining('Sent Requests'), findsOneWidget);

        await tester.tap(find.textContaining('Activity ('));
        await tester.pumpAndSettle();
        expect(
          find.text('No administrative actions recorded for this account yet.'),
          findsOneWidget,
        );

        // Close popup
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.text('Edit Profile Information'), findsNothing);
      },
    );

    testWidgets(
      'renders responsively on mobile viewport (360x800) with navigation drawer and zero overflow',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: AdminDashboardScreen(
              profileService: FakeProfileService(lavanyaProfile),
              storageService: FakeStorageService(),
              adminService: FakeAdminService(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Welcome, lavanya!'), findsOneWidget);

        // Open mobile drawer
        await tester.tap(find.byTooltip('Open Navigation Menu'));
        await tester.pumpAndSettle();
        expect(find.text('MANAGEMENT CONSOLE'), findsOneWidget);

        await tester.tap(
          find.descendant(
            of: find.byType(Drawer),
            matching: find.text('User Management'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Alice Walker (@alice_student)'),
          findsOneWidget,
        );
      },
    );
  });
}
