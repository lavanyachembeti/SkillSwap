class AdminPaginatedResponse<T> {
  final int count;
  final int page;
  final int pageSize;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;
  final List<T> results;

  const AdminPaginatedResponse({
    required this.count,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
    required this.results,
  });

  factory AdminPaginatedResponse.fromJson(
    dynamic json,
    T Function(Map<String, dynamic>) itemParser,
  ) {
    if (json is List) {
      final items = json
          .whereType<Map>()
          .map((e) => itemParser(Map<String, dynamic>.from(e)))
          .toList();
      return AdminPaginatedResponse<T>(
        count: items.length,
        page: 1,
        pageSize: items.isEmpty ? 50 : items.length,
        totalPages: 1,
        hasNext: false,
        hasPrevious: false,
        results: items,
      );
    }
    if (json is Map) {
      final map = Map<String, dynamic>.from(json);
      final rawList = map['results'] is List ? map['results'] as List : const [];
      final items = rawList
          .whereType<Map>()
          .map((e) => itemParser(Map<String, dynamic>.from(e)))
          .toList();
      return AdminPaginatedResponse<T>(
        count: _toInt(map['count'], items.length),
        page: _toInt(map['page'], 1),
        pageSize: _toInt(map['page_size'], 50),
        totalPages: _toInt(map['total_pages'], 1),
        hasNext: map['has_next'] == true,
        hasPrevious: map['has_previous'] == true,
        results: items,
      );
    }
    return const AdminPaginatedResponse(
      count: 0,
      page: 1,
      pageSize: 50,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      results: [],
    );
  }
}

int _toInt(dynamic val, [int fallback = 0]) {
  if (val is int) return val;
  if (val is num) return val.toInt();
  if (val != null) return int.tryParse(val.toString()) ?? fallback;
  return fallback;
}

String _toStr(dynamic val, [String fallback = '']) {
  if (val == null) return fallback;
  final s = val.toString().trim();
  return s.isEmpty ? fallback : s;
}

class AdminDashboardStatsModel {
  // User statistics
  final int totalUsers;
  final int totalStudents;
  final int totalProfessionals;
  final int totalAdministrators;
  final int activeUsers;
  final int inactiveUsers;
  final int suspendedUsers;
  final int verifiedUsers;
  final int unverifiedUsers;
  final int recentlyRegisteredUsers;
  final List<AdminUserModel> recentUsers;

  // Skill statistics
  final int totalSkills;
  final int activeSkills;
  final int inactiveSkills;
  final int totalUsersTeachingSkills;
  final int totalUsersLearningSkills;

  // Request statistics
  final int totalRequests;
  final int pendingRequests;
  final int acceptedRequests;
  final int rejectedRequests;
  final int cancelledRequests;

  // Chat statistics
  final int totalConversations;
  final int totalMessages;
  final int recentMessages;
  final List<AdminChatMessageModel> recentMessagesList;
  final int reportedConversations;

  // Reports & Audit statistics
  final int totalReports;
  final int pendingReports;
  final int underReviewReports;
  final int resolvedReports;
  final int dismissedReports;
  final int totalAuditLogs;
  final List<AdminAuditLogModel> recentAdminActivities;

  const AdminDashboardStatsModel({
    this.totalUsers = 0,
    this.totalStudents = 0,
    this.totalProfessionals = 0,
    this.totalAdministrators = 0,
    this.activeUsers = 0,
    this.inactiveUsers = 0,
    this.suspendedUsers = 0,
    this.verifiedUsers = 0,
    this.unverifiedUsers = 0,
    this.recentlyRegisteredUsers = 0,
    this.recentUsers = const [],
    this.totalSkills = 0,
    this.activeSkills = 0,
    this.inactiveSkills = 0,
    this.totalUsersTeachingSkills = 0,
    this.totalUsersLearningSkills = 0,
    this.totalRequests = 0,
    this.pendingRequests = 0,
    this.acceptedRequests = 0,
    this.rejectedRequests = 0,
    this.cancelledRequests = 0,
    this.totalConversations = 0,
    this.totalMessages = 0,
    this.recentMessages = 0,
    this.recentMessagesList = const [],
    this.reportedConversations = 0,
    this.totalReports = 0,
    this.pendingReports = 0,
    this.underReviewReports = 0,
    this.resolvedReports = 0,
    this.dismissedReports = 0,
    this.totalAuditLogs = 0,
    this.recentAdminActivities = const [],
  });

  factory AdminDashboardStatsModel.fromJson(Map<String, dynamic> json) {
    final rawRecentUsers = json['recent_users'] is List
        ? json['recent_users'] as List
        : const [];
    final rawRecentMsgs = json['recent_messages_list'] is List
        ? json['recent_messages_list'] as List
        : const [];
    final rawRecentAudit = json['recent_admin_activities'] is List
        ? json['recent_admin_activities'] as List
        : const [];

    final pendingReq = _toInt(json['pending_requests']);
    final acceptedReq = _toInt(json['accepted_requests']);
    final rejectedReq = _toInt(json['rejected_requests']);
    final cancelledReq = _toInt(json['cancelled_requests']);
    final totalReq = _toInt(
      json['total_requests'],
      pendingReq + acceptedReq + rejectedReq + cancelledReq,
    );

    final totalSk = _toInt(json['total_skills']);
    final inactiveSk = _toInt(json['inactive_skills']);
    final activeSk = _toInt(json['active_skills'], totalSk - inactiveSk);

    return AdminDashboardStatsModel(
      totalUsers: _toInt(json['total_users']),
      totalStudents: _toInt(json['total_students']),
      totalProfessionals: _toInt(json['total_professionals']),
      totalAdministrators: _toInt(json['total_administrators']),
      activeUsers: _toInt(json['active_users']),
      inactiveUsers: _toInt(json['inactive_users']),
      suspendedUsers: _toInt(json['suspended_users']),
      verifiedUsers: _toInt(json['verified_users']),
      unverifiedUsers: _toInt(json['unverified_users']),
      recentlyRegisteredUsers: _toInt(json['recently_registered_users']),
      recentUsers: rawRecentUsers
          .whereType<Map>()
          .map((e) => AdminUserModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      totalSkills: totalSk,
      activeSkills: activeSk,
      inactiveSkills: inactiveSk,
      totalUsersTeachingSkills: _toInt(json['total_users_teaching_skills']),
      totalUsersLearningSkills: _toInt(json['total_users_learning_skills']),
      totalRequests: totalReq,
      pendingRequests: pendingReq,
      acceptedRequests: acceptedReq,
      rejectedRequests: rejectedReq,
      cancelledRequests: cancelledReq,
      totalConversations: _toInt(json['total_conversations']),
      totalMessages: _toInt(json['total_messages']),
      recentMessages: _toInt(json['recent_messages']),
      recentMessagesList: rawRecentMsgs
          .whereType<Map>()
          .map(
            (e) => AdminChatMessageModel.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
      reportedConversations: _toInt(json['reported_conversations']),
      totalReports: _toInt(json['total_reports']),
      pendingReports: _toInt(json['pending_reports']),
      underReviewReports: _toInt(json['under_review_reports']),
      resolvedReports: _toInt(json['resolved_reports']),
      dismissedReports: _toInt(json['dismissed_reports']),
      totalAuditLogs: _toInt(json['total_audit_logs']),
      recentAdminActivities: rawRecentAudit
          .whereType<Map>()
          .map((e) => AdminAuditLogModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class AdminUserSkillItem {
  final int id;
  final int skillId;
  final String name;
  final String category;
  final String proficiency;
  final bool isActive;

  const AdminUserSkillItem({
    required this.id,
    required this.skillId,
    required this.name,
    required this.category,
    required this.proficiency,
    this.isActive = true,
  });

  factory AdminUserSkillItem.fromJson(Map<String, dynamic> json) {
    return AdminUserSkillItem(
      id: _toInt(json['id']),
      skillId: _toInt(json['skill_id']),
      name: _toStr(json['name'], 'Unnamed Skill'),
      category: _toStr(json['category'], 'General'),
      proficiency: _toStr(json['proficiency'], 'Intermediate'),
      isActive: json['is_active'] != false,
    );
  }
}

class AdminUserRequestItem {
  final int id;
  final int? peerUserId;
  final String peerUsername;
  final String requestedSkillName;
  final String? offeredSkillName;
  final String? message;
  final String? learningGoal;
  final String status;
  final String createdAt;

  const AdminUserRequestItem({
    required this.id,
    this.peerUserId,
    required this.peerUsername,
    required this.requestedSkillName,
    this.offeredSkillName,
    this.message,
    this.learningGoal,
    required this.status,
    required this.createdAt,
  });

  factory AdminUserRequestItem.fromJson(Map<String, dynamic> json) {
    final peer = _toStr(
      json['target_username'] ?? json['requester_username'],
      'User',
    );
    return AdminUserRequestItem(
      id: _toInt(json['id']),
      peerUserId: json['target_id'] != null
          ? _toInt(json['target_id'])
          : (json['requester_id'] != null ? _toInt(json['requester_id']) : null),
      peerUsername: peer,
      requestedSkillName: _toStr(json['requested_skill_name'], 'Skill'),
      offeredSkillName: json['offered_skill_name']?.toString(),
      message: json['message']?.toString(),
      learningGoal: json['learning_goal']?.toString(),
      status: _toStr(json['status'], 'pending'),
      createdAt: _toStr(json['created_at']),
    );
  }
}

class AdminUserModel {
  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String fullName;
  final String email;
  final String role;
  final String phone;
  final String bio;
  final String? profileImage;
  final bool isVerified;
  final bool isActive;
  final bool isSuspended;
  final String? suspendedUntil;
  final String? suspensionReason;
  final String accountStatus;
  final bool isStaff;
  final bool isSuperuser;
  final bool isAdmin;
  final String dateJoined;
  final String? lastLogin;
  final String? lastActivity;
  final int skillsTeachingCount;
  final int skillsLearningCount;
  final List<AdminUserSkillItem> skillsTeaching;
  final List<AdminUserSkillItem> skillsLearning;
  final int sentRequestsCount;
  final int receivedRequestsCount;
  final List<AdminUserRequestItem> sentRequests;
  final List<AdminUserRequestItem> receivedRequests;
  final int conversationsCount;
  final int reportsReceivedCount;
  final List<AdminAuditLogModel> accountActivity;

  const AdminUserModel({
    required this.id,
    required this.username,
    this.firstName = '',
    this.lastName = '',
    required this.fullName,
    required this.email,
    required this.role,
    this.phone = '',
    this.bio = '',
    this.profileImage,
    this.isVerified = false,
    this.isActive = true,
    this.isSuspended = false,
    this.suspendedUntil,
    this.suspensionReason,
    this.accountStatus = 'active',
    this.isStaff = false,
    this.isSuperuser = false,
    this.isAdmin = false,
    this.dateJoined = '',
    this.lastLogin,
    this.lastActivity,
    this.skillsTeachingCount = 0,
    this.skillsLearningCount = 0,
    this.skillsTeaching = const [],
    this.skillsLearning = const [],
    this.sentRequestsCount = 0,
    this.receivedRequestsCount = 0,
    this.sentRequests = const [],
    this.receivedRequests = const [],
    this.conversationsCount = 0,
    this.reportsReceivedCount = 0,
    this.accountActivity = const [],
  });

  bool get isAdministrator =>
      isAdmin || isStaff || isSuperuser || role.toLowerCase() == 'admin';

  String get displayRole {
    if (isSuperuser) return 'Super Admin (${role.toUpperCase()})';
    if (isAdministrator && role.toLowerCase() != 'admin') {
      return 'Admin (${role.toUpperCase()})';
    }
    return role.isEmpty
        ? 'Student'
        : '${role[0].toUpperCase()}${role.substring(1)}';
  }

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    final uname = _toStr(json['username'], 'user');
    final fName = _toStr(json['first_name']);
    final lName = _toStr(json['last_name']);
    final computedFull = '$fName $lName'.trim();
    final full = _toStr(
      json['full_name'],
      computedFull.isNotEmpty ? computedFull : uname,
    );

    final teachingList = (json['skills_teaching'] is List
            ? json['skills_teaching'] as List
            : const [])
        .whereType<Map>()
        .map((e) => AdminUserSkillItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final learningList = (json['skills_learning'] is List
            ? json['skills_learning'] as List
            : const [])
        .whereType<Map>()
        .map((e) => AdminUserSkillItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final sentReqList = (json['sent_requests'] is List
            ? json['sent_requests'] as List
            : const [])
        .whereType<Map>()
        .map((e) => AdminUserRequestItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final receivedReqList = (json['received_requests'] is List
            ? json['received_requests'] as List
            : const [])
        .whereType<Map>()
        .map((e) => AdminUserRequestItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final activityList = (json['account_activity'] is List
            ? json['account_activity'] as List
            : const [])
        .whereType<Map>()
        .map((e) => AdminAuditLogModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return AdminUserModel(
      id: _toInt(json['id']),
      username: uname,
      firstName: fName,
      lastName: lName,
      fullName: full,
      email: _toStr(json['email']),
      role: _toStr(json['role'], 'student'),
      phone: _toStr(json['phone']),
      bio: _toStr(json['bio']),
      profileImage: json['profile_image']?.toString(),
      isVerified: json['is_verified'] == true,
      isActive: json['is_active'] != false,
      isSuspended: json['is_suspended'] == true,
      suspendedUntil: json['suspended_until']?.toString(),
      suspensionReason: json['suspension_reason']?.toString(),
      accountStatus: _toStr(json['account_status'], 'active'),
      isStaff: json['is_staff'] == true,
      isSuperuser: json['is_superuser'] == true,
      isAdmin: json['is_admin'] == true,
      dateJoined: _toStr(json['date_joined']),
      lastLogin: json['last_login']?.toString(),
      lastActivity: json['last_activity']?.toString(),
      skillsTeachingCount: _toInt(
        json['skills_teaching_count'],
        teachingList.length,
      ),
      skillsLearningCount: _toInt(
        json['skills_learning_count'],
        learningList.length,
      ),
      skillsTeaching: teachingList,
      skillsLearning: learningList,
      sentRequestsCount: _toInt(json['sent_requests_count'], sentReqList.length),
      receivedRequestsCount: _toInt(
        json['received_requests_count'],
        receivedReqList.length,
      ),
      sentRequests: sentReqList,
      receivedRequests: receivedReqList,
      conversationsCount: _toInt(json['conversations_count']),
      reportsReceivedCount: _toInt(json['reports_received_count']),
      accountActivity: activityList,
    );
  }
}

class AdminSkillUserItem {
  final int id;
  final int userId;
  final String username;
  final String fullName;
  final String email;
  final String role;
  final String proficiency;

  const AdminSkillUserItem({
    required this.id,
    required this.userId,
    required this.username,
    required this.fullName,
    required this.email,
    required this.role,
    required this.proficiency,
  });

  factory AdminSkillUserItem.fromJson(Map<String, dynamic> json) {
    final uname = _toStr(json['username'], 'user');
    return AdminSkillUserItem(
      id: _toInt(json['id']),
      userId: _toInt(json['user_id']),
      username: uname,
      fullName: _toStr(json['full_name'], uname),
      email: _toStr(json['email']),
      role: _toStr(json['role'], 'student'),
      proficiency: _toStr(json['proficiency'], 'Intermediate'),
    );
  }
}

class AdminSkillModel {
  final int id;
  final String name;
  final String description;
  final String category;
  final bool isActive;
  final String createdAt;
  final int teachingUsersCount;
  final int learningUsersCount;
  final int totalUsersCount;
  final int requestsCount;
  final List<AdminSkillUserItem> teachingUsers;
  final List<AdminSkillUserItem> learningUsers;

  const AdminSkillModel({
    required this.id,
    required this.name,
    this.description = '',
    this.category = 'General',
    this.isActive = true,
    this.createdAt = '',
    this.teachingUsersCount = 0,
    this.learningUsersCount = 0,
    this.totalUsersCount = 0,
    this.requestsCount = 0,
    this.teachingUsers = const [],
    this.learningUsers = const [],
  });

  factory AdminSkillModel.fromJson(Map<String, dynamic> json) {
    final teachList = (json['teaching_users'] is List
            ? json['teaching_users'] as List
            : const [])
        .whereType<Map>()
        .map((e) => AdminSkillUserItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final learnList = (json['learning_users'] is List
            ? json['learning_users'] as List
            : const [])
        .whereType<Map>()
        .map((e) => AdminSkillUserItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final tCount = _toInt(json['teaching_users_count'], teachList.length);
    final lCount = _toInt(json['learning_users_count'], learnList.length);

    return AdminSkillModel(
      id: _toInt(json['id']),
      name: _toStr(json['name']),
      description: _toStr(json['description']),
      category: _toStr(json['category'], 'General'),
      isActive: json['is_active'] != false,
      createdAt: _toStr(json['created_at']),
      teachingUsersCount: tCount,
      learningUsersCount: lCount,
      totalUsersCount: _toInt(json['total_users_count'], tCount + lCount),
      requestsCount: _toInt(json['requests_count']),
      teachingUsers: teachList,
      learningUsers: learnList,
    );
  }
}

class AdminSkillRequestModel {
  final int id;
  final int requesterId;
  final String requesterUsername;
  final String requesterFullName;
  final String requesterEmail;
  final String requesterRole;
  final int targetId;
  final String targetUsername;
  final String targetFullName;
  final String targetEmail;
  final String targetRole;
  final int requestedSkillId;
  final String requestedSkillName;
  final String requestedSkillCategory;
  final int? offeredSkillId;
  final String? offeredSkillName;
  final String? offeredSkillCategory;
  final String message;
  final String learningGoal;
  final String status;
  final String createdAt;
  final String updatedAt;

  const AdminSkillRequestModel({
    required this.id,
    required this.requesterId,
    required this.requesterUsername,
    required this.requesterFullName,
    required this.requesterEmail,
    this.requesterRole = 'student',
    required this.targetId,
    required this.targetUsername,
    required this.targetFullName,
    required this.targetEmail,
    this.targetRole = 'student',
    required this.requestedSkillId,
    required this.requestedSkillName,
    this.requestedSkillCategory = 'General',
    this.offeredSkillId,
    this.offeredSkillName,
    this.offeredSkillCategory,
    this.message = '',
    this.learningGoal = '',
    required this.status,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory AdminSkillRequestModel.fromJson(Map<String, dynamic> json) {
    final reqUname = _toStr(json['requester_username'], 'User');
    final tgtUname = _toStr(json['target_username'], 'User');
    return AdminSkillRequestModel(
      id: _toInt(json['id']),
      requesterId: _toInt(json['requester']),
      requesterUsername: reqUname,
      requesterFullName: _toStr(json['requester_full_name'], reqUname),
      requesterEmail: _toStr(json['requester_email']),
      requesterRole: _toStr(json['requester_role'], 'student'),
      targetId: _toInt(json['target']),
      targetUsername: tgtUname,
      targetFullName: _toStr(json['target_full_name'], tgtUname),
      targetEmail: _toStr(json['target_email']),
      targetRole: _toStr(json['target_role'], 'student'),
      requestedSkillId: _toInt(json['requested_skill']),
      requestedSkillName: _toStr(json['requested_skill_name'], 'Skill'),
      requestedSkillCategory: _toStr(
        json['requested_skill_category'],
        'General',
      ),
      offeredSkillId: json['offered_skill'] != null
          ? _toInt(json['offered_skill'])
          : null,
      offeredSkillName: json['offered_skill_name']?.toString(),
      offeredSkillCategory: json['offered_skill_category']?.toString(),
      message: _toStr(json['message']),
      learningGoal: _toStr(json['learning_goal']),
      status: _toStr(json['status'], 'pending'),
      createdAt: _toStr(json['created_at']),
      updatedAt: _toStr(json['updated_at']),
    );
  }
}

class AdminLinkedRequestSummary {
  final int id;
  final String requesterUsername;
  final String targetUsername;
  final String requestedSkillName;
  final String? offeredSkillName;
  final String status;
  final String createdAt;

  const AdminLinkedRequestSummary({
    required this.id,
    required this.requesterUsername,
    required this.targetUsername,
    required this.requestedSkillName,
    this.offeredSkillName,
    required this.status,
    this.createdAt = '',
  });

  factory AdminLinkedRequestSummary.fromJson(Map<String, dynamic> json) {
    return AdminLinkedRequestSummary(
      id: _toInt(json['id']),
      requesterUsername: _toStr(json['requester_username']),
      targetUsername: _toStr(json['target_username']),
      requestedSkillName: _toStr(json['requested_skill_name']),
      offeredSkillName: json['offered_skill_name']?.toString(),
      status: _toStr(json['status'], 'pending'),
      createdAt: _toStr(json['created_at']),
    );
  }
}

class AdminConversationModel {
  final int id;
  final int user1Id;
  final String user1Username;
  final String user1Email;
  final int user2Id;
  final String user2Username;
  final String user2Email;
  final int? skillRequestId;
  final AdminLinkedRequestSummary? linkedRequest;
  final int messagesCount;
  final String? lastMessage;
  final String? lastMessageAt;
  final String conversationStatus;
  final bool canSendMessages;
  final bool hasAcceptedRequest;
  final bool adminAuthorized;
  final bool isLocked;
  final bool isReported;
  final String createdAt;
  final String updatedAt;

  const AdminConversationModel({
    required this.id,
    required this.user1Id,
    required this.user1Username,
    this.user1Email = '',
    required this.user2Id,
    required this.user2Username,
    this.user2Email = '',
    this.skillRequestId,
    this.linkedRequest,
    this.messagesCount = 0,
    this.lastMessage,
    this.lastMessageAt,
    this.conversationStatus = 'active',
    this.canSendMessages = true,
    this.hasAcceptedRequest = false,
    this.adminAuthorized = false,
    this.isLocked = false,
    this.isReported = false,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory AdminConversationModel.fromJson(Map<String, dynamic> json) {
    AdminLinkedRequestSummary? linked;
    if (json['linked_request'] is Map) {
      linked = AdminLinkedRequestSummary.fromJson(
        Map<String, dynamic>.from(json['linked_request'] as Map),
      );
    }
    return AdminConversationModel(
      id: _toInt(json['id']),
      user1Id: _toInt(json['user1']),
      user1Username: _toStr(json['user1_username'], 'User 1'),
      user1Email: _toStr(json['user1_email']),
      user2Id: _toInt(json['user2']),
      user2Username: _toStr(json['user2_username'], 'User 2'),
      user2Email: _toStr(json['user2_email']),
      skillRequestId: json['skill_request'] != null
          ? _toInt(json['skill_request'])
          : null,
      linkedRequest: linked,
      messagesCount: _toInt(json['messages_count']),
      lastMessage: json['last_message']?.toString(),
      lastMessageAt: json['last_message_at']?.toString(),
      conversationStatus: _toStr(json['conversation_status'], 'active'),
      canSendMessages: json['can_send_messages'] != false,
      hasAcceptedRequest: json['has_accepted_request'] == true,
      adminAuthorized: json['admin_authorized'] == true,
      isLocked: json['is_locked'] == true,
      isReported: json['is_reported'] == true,
      createdAt: _toStr(json['created_at']),
      updatedAt: _toStr(json['updated_at']),
    );
  }
}

class AdminChatMessageModel {
  final int id;
  final int conversationId;
  final int senderId;
  final String senderUsername;
  final String message;
  final bool isRead;
  final String createdAt;

  const AdminChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderUsername,
    required this.message,
    this.isRead = false,
    this.createdAt = '',
  });

  factory AdminChatMessageModel.fromJson(Map<String, dynamic> json) {
    return AdminChatMessageModel(
      id: _toInt(json['id']),
      conversationId: _toInt(json['conversation']),
      senderId: _toInt(json['sender']),
      senderUsername: _toStr(json['sender_username'], 'User'),
      message: _toStr(json['message']),
      isRead: json['is_read'] == true,
      createdAt: _toStr(json['created_at']),
    );
  }
}

class AdminConversationDetailModel {
  final int conversationId;
  final String user1;
  final String user2;
  final String conversationStatus;
  final bool canSendMessages;
  final bool hasAcceptedRequest;
  final bool adminAuthorized;
  final bool isLocked;
  final AdminLinkedRequestSummary? linkedRequest;
  final int count;
  final List<AdminChatMessageModel> messages;

  const AdminConversationDetailModel({
    required this.conversationId,
    required this.user1,
    required this.user2,
    this.conversationStatus = 'active',
    this.canSendMessages = true,
    this.hasAcceptedRequest = false,
    this.adminAuthorized = false,
    this.isLocked = false,
    this.linkedRequest,
    required this.count,
    required this.messages,
  });

  factory AdminConversationDetailModel.fromJson(Map<String, dynamic> json) {
    AdminLinkedRequestSummary? linked;
    if (json['linked_request'] is Map) {
      linked = AdminLinkedRequestSummary.fromJson(
        Map<String, dynamic>.from(json['linked_request'] as Map),
      );
    }
    final rawMsgs = json['messages'] is List ? json['messages'] as List : const [];
    final parsedMsgs = rawMsgs
        .whereType<Map>()
        .map((e) => AdminChatMessageModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return AdminConversationDetailModel(
      conversationId: _toInt(json['conversation_id']),
      user1: _toStr(json['user1'], 'User 1'),
      user2: _toStr(json['user2'], 'User 2'),
      conversationStatus: _toStr(json['conversation_status'], 'active'),
      canSendMessages: json['can_send_messages'] != false,
      hasAcceptedRequest: json['has_accepted_request'] == true,
      adminAuthorized: json['admin_authorized'] == true,
      isLocked: json['is_locked'] == true,
      linkedRequest: linked,
      count: _toInt(json['count'], parsedMsgs.length),
      messages: parsedMsgs,
    );
  }
}

class AdminMessagingPolicyModel {
  final int id;
  final int maxMessagesPerMinute;
  final int maxMessagesPerConversationPerDay;
  final int maxMessagesPerUserPerDay;
  final int warningThresholdPercent;
  final int cooldownMinutes;
  final bool enforceAcceptedRequest;
  final bool enableRateLimiting;
  final String? updatedByUsername;
  final String updatedAt;

  const AdminMessagingPolicyModel({
    this.id = 1,
    this.maxMessagesPerMinute = 5,
    this.maxMessagesPerConversationPerDay = 50,
    this.maxMessagesPerUserPerDay = 100,
    this.warningThresholdPercent = 80,
    this.cooldownMinutes = 15,
    this.enforceAcceptedRequest = true,
    this.enableRateLimiting = true,
    this.updatedByUsername,
    this.updatedAt = '',
  });

  factory AdminMessagingPolicyModel.fromJson(Map<String, dynamic> json) {
    return AdminMessagingPolicyModel(
      id: _toInt(json['id'], 1),
      maxMessagesPerMinute: _toInt(json['max_messages_per_minute'], 5),
      maxMessagesPerConversationPerDay: _toInt(
        json['max_messages_per_conversation_per_day'],
        50,
      ),
      maxMessagesPerUserPerDay: _toInt(json['max_messages_per_user_per_day'], 100),
      warningThresholdPercent: _toInt(json['warning_threshold_percent'], 80),
      cooldownMinutes: _toInt(json['cooldown_minutes'], 15),
      enforceAcceptedRequest: json['enforce_accepted_request'] != false,
      enableRateLimiting: json['enable_rate_limiting'] != false,
      updatedByUsername: json['updated_by_username']?.toString(),
      updatedAt: _toStr(json['updated_at']),
    );
  }
}

class AdminMessagingRestrictionModel {
  final int id;
  final int userId;
  final String username;
  final String userEmail;
  final int? conversationId;
  final String restrictionType;
  final String reason;
  final bool isActive;
  final bool isCurrentlyActive;
  final String? expiresAt;
  final String? createdByUsername;
  final String createdAt;

  const AdminMessagingRestrictionModel({
    required this.id,
    required this.userId,
    required this.username,
    this.userEmail = '',
    this.conversationId,
    this.restrictionType = 'cooldown',
    this.reason = '',
    this.isActive = true,
    this.isCurrentlyActive = true,
    this.expiresAt,
    this.createdByUsername,
    this.createdAt = '',
  });

  factory AdminMessagingRestrictionModel.fromJson(Map<String, dynamic> json) {
    return AdminMessagingRestrictionModel(
      id: _toInt(json['id']),
      userId: _toInt(json['user']),
      username: _toStr(json['username'], 'user'),
      userEmail: _toStr(json['user_email']),
      conversationId: json['conversation'] != null
          ? _toInt(json['conversation'])
          : null,
      restrictionType: _toStr(json['restriction_type'], 'cooldown'),
      reason: _toStr(json['reason']),
      isActive: json['is_active'] != false,
      isCurrentlyActive: json['is_currently_active'] != false,
      expiresAt: json['expires_at']?.toString(),
      createdByUsername: json['created_by_username']?.toString(),
      createdAt: _toStr(json['created_at']),
    );
  }
}

class AdminMessagingPolicyEnvelope {
  final AdminMessagingPolicyModel policy;
  final int activeRestrictionsCount;
  final List<AdminMessagingRestrictionModel> activeRestrictions;

  const AdminMessagingPolicyEnvelope({
    required this.policy,
    this.activeRestrictionsCount = 0,
    this.activeRestrictions = const [],
  });

  factory AdminMessagingPolicyEnvelope.fromJson(Map<String, dynamic> json) {
    final policyMap = json['policy'] is Map
        ? Map<String, dynamic>.from(json['policy'] as Map)
        : json;
    final rawRestr = json['active_restrictions'] is List
        ? json['active_restrictions'] as List
        : const [];
    final parsedRestr = rawRestr
        .whereType<Map>()
        .map(
          (e) => AdminMessagingRestrictionModel.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();

    return AdminMessagingPolicyEnvelope(
      policy: AdminMessagingPolicyModel.fromJson(policyMap),
      activeRestrictionsCount: _toInt(
        json['active_restrictions_count'],
        parsedRestr.length,
      ),
      activeRestrictions: parsedRestr,
    );
  }
}

class AdminUserReportModel {
  final int id;
  final int reporterId;
  final String reporterUsername;
  final String reporterEmail;
  final int reportedUserId;
  final String reportedUsername;
  final String reportedUserEmail;
  final String reportedUserRole;
  final bool reportedUserIsSuspended;
  final String reportedUserStatus;
  final String reason;
  final String description;
  final String status;
  final String adminNotes;
  final String? resolvedByUsername;
  final String? resolvedAt;
  final String createdAt;

  const AdminUserReportModel({
    required this.id,
    required this.reporterId,
    required this.reporterUsername,
    this.reporterEmail = '',
    required this.reportedUserId,
    required this.reportedUsername,
    this.reportedUserEmail = '',
    this.reportedUserRole = 'student',
    this.reportedUserIsSuspended = false,
    this.reportedUserStatus = 'active',
    required this.reason,
    this.description = '',
    required this.status,
    this.adminNotes = '',
    this.resolvedByUsername,
    this.resolvedAt,
    this.createdAt = '',
  });

  factory AdminUserReportModel.fromJson(Map<String, dynamic> json) {
    return AdminUserReportModel(
      id: _toInt(json['id']),
      reporterId: _toInt(json['reporter']),
      reporterUsername: _toStr(json['reporter_username'], 'User'),
      reporterEmail: _toStr(json['reporter_email']),
      reportedUserId: _toInt(json['reported_user']),
      reportedUsername: _toStr(json['reported_username'], 'User'),
      reportedUserEmail: _toStr(json['reported_user_email']),
      reportedUserRole: _toStr(json['reported_user_role'], 'student'),
      reportedUserIsSuspended: json['reported_user_is_suspended'] == true,
      reportedUserStatus: _toStr(json['reported_user_status'], 'active'),
      reason: _toStr(json['reason'], 'other'),
      description: _toStr(json['description']),
      status: _toStr(json['status'], 'pending'),
      adminNotes: _toStr(json['admin_notes']),
      resolvedByUsername: json['resolved_by_username']?.toString(),
      resolvedAt: json['resolved_at']?.toString(),
      createdAt: _toStr(json['created_at']),
    );
  }
}

class AdminAuditLogModel {
  final int id;
  final int? adminUserId;
  final String adminUsername;
  final String action;
  final String targetModel;
  final String? targetId;
  final String? targetRepr;
  final Map<String, dynamic>? previousValue;
  final Map<String, dynamic>? newValue;
  final String reason;
  final String description;
  final String status;
  final String? ipAddress;
  final String createdAt;

  const AdminAuditLogModel({
    required this.id,
    this.adminUserId,
    required this.adminUsername,
    required this.action,
    required this.targetModel,
    this.targetId,
    this.targetRepr,
    this.previousValue,
    this.newValue,
    this.reason = '',
    this.description = '',
    this.status = 'success',
    this.ipAddress,
    this.createdAt = '',
  });

  factory AdminAuditLogModel.fromJson(Map<String, dynamic> json) {
    final act = _toStr(json['action'], 'admin_action');
    final tgtModel = _toStr(json['target_model'], 'Record');
    final tgtId = json['target_id']?.toString();
    final tgtRepr = json['target_repr']?.toString();
    final rsn = _toStr(json['reason']);
    final fallbackDesc = rsn.isNotEmpty
        ? '$act on ${tgtRepr ?? "$tgtModel #${tgtId ?? ""}"} — $rsn'
        : '$act on ${tgtRepr ?? "$tgtModel #${tgtId ?? ""}"}';

    return AdminAuditLogModel(
      id: _toInt(json['id']),
      adminUserId: json['admin_user'] != null ? _toInt(json['admin_user']) : null,
      adminUsername: _toStr(json['admin_username'], 'admin'),
      action: act,
      targetModel: tgtModel,
      targetId: tgtId,
      targetRepr: tgtRepr,
      previousValue: json['previous_value'] is Map
          ? Map<String, dynamic>.from(json['previous_value'] as Map)
          : null,
      newValue: json['new_value'] is Map
          ? Map<String, dynamic>.from(json['new_value'] as Map)
          : null,
      reason: rsn,
      description: _toStr(json['description'], fallbackDesc),
      status: _toStr(json['status'], 'success'),
      ipAddress: json['ip_address']?.toString(),
      createdAt: _toStr(json['created_at']),
    );
  }
}
