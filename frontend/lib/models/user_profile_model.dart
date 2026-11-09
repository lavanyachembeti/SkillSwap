class UserProfileModel {
  final int? id;
  final String username;
  final String email;
  final String phone;
  final String bio;
  final String role;
  final bool isVerified;
  final bool isStaff;
  final bool isSuperuser;
  final bool isAdmin;
  final bool isSuspended;
  final String accountStatus;

  UserProfileModel({
    this.id,
    required this.username,
    required this.email,
    required this.phone,
    required this.bio,
    required this.role,
    this.isVerified = false,
    this.isStaff = false,
    this.isSuperuser = false,
    this.isAdmin = false,
    this.isSuspended = false,
    this.accountStatus = 'active',
  });

  /// Check whether the user holds administrator access
  bool get isAdministrator =>
      isAdmin ||
      isStaff ||
      isSuperuser ||
      role.trim().toLowerCase() == 'admin';

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    // Defensively handle nested 'user' object if DRF serializer wraps user fields
    final userMap = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : (json['user'] is Map ? Map<String, dynamic>.from(json['user'] as Map) : null);

    final rawUsername = json['username']?.toString() ??
        userMap?['username']?.toString() ??
        '';

    final rawEmail = json['email']?.toString() ??
        userMap?['email']?.toString() ??
        '';

    final rawPhone = json['phone']?.toString() ??
        json['phone_number']?.toString() ??
        userMap?['phone']?.toString() ??
        userMap?['phone_number']?.toString() ??
        '';

    final rawBio = json['bio']?.toString() ??
        userMap?['bio']?.toString() ??
        '';

    final rawRole = json['role']?.toString() ??
        userMap?['role']?.toString() ??
        '';

    final idVal = json['id'] is int
        ? json['id'] as int
        : (userMap?['id'] is int
            ? userMap!['id'] as int
            : int.tryParse(json['id']?.toString() ?? ''));

    final isVerifiedVal = json['is_verified'] == true || userMap?['is_verified'] == true;
    final isStaffVal = json['is_staff'] == true || userMap?['is_staff'] == true;
    final isSuperuserVal = json['is_superuser'] == true || userMap?['is_superuser'] == true;
    final isAdminVal = json['is_admin'] == true || userMap?['is_admin'] == true;
    final isSuspendedVal = json['is_suspended'] == true || userMap?['is_suspended'] == true;
    final rawAccountStatus = json['account_status']?.toString() ??
        userMap?['account_status']?.toString() ??
        'active';

    return UserProfileModel(
      id: idVal,
      username: rawUsername,
      email: rawEmail,
      phone: rawPhone,
      bio: rawBio,
      role: rawRole,
      isVerified: isVerifiedVal,
      isStaff: isStaffVal,
      isSuperuser: isSuperuserVal,
      isAdmin: isAdminVal,
      isSuspended: isSuspendedVal,
      accountStatus: rawAccountStatus,
    );
  }

  UserProfileModel copyWith({
    int? id,
    String? username,
    String? email,
    String? phone,
    String? bio,
    String? role,
    bool? isVerified,
    bool? isStaff,
    bool? isSuperuser,
    bool? isAdmin,
    bool? isSuspended,
    String? accountStatus,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      role: role ?? this.role,
      isVerified: isVerified ?? this.isVerified,
      isStaff: isStaff ?? this.isStaff,
      isSuperuser: isSuperuser ?? this.isSuperuser,
      isAdmin: isAdmin ?? this.isAdmin,
      isSuspended: isSuspended ?? this.isSuspended,
      accountStatus: accountStatus ?? this.accountStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'username': username,
      'email': email,
      'phone': phone,
      'bio': bio,
      'role': role,
      'is_verified': isVerified,
      'is_staff': isStaff,
      'is_superuser': isSuperuser,
      'is_admin': isAdmin,
      'is_suspended': isSuspended,
      'account_status': accountStatus,
    };
  }

  Map<String, dynamic> toUpdatePayload() {
    return {
      'email': email,
      'phone': phone,
      'bio': bio,
    };
  }
}
