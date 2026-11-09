import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../models/user_profile_model.dart';
import '../../navigation/app_router.dart';
import '../../services/admin_service.dart';
import '../../services/profile_service.dart';
import '../../services/storage_service.dart';
import 'admin_portal_dialogs.dart';
import 'admin_portal_widgets.dart';

enum AdminPortalSection {
  overview,
  users,
  skills,
  requests,
  chat,
  reports,
  auditLogs,
  messagingPolicies,
  adminSettings,
}

class AdminDashboardScreen extends StatefulWidget {
  final ProfileService? profileService;
  final StorageService? storageService;
  final AdminService? adminService;
  final AdminPortalSection initialSection;

  const AdminDashboardScreen({
    super.key,
    this.profileService,
    this.storageService,
    this.adminService,
    this.initialSection = AdminPortalSection.overview,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final ProfileService _profileService;
  late final StorageService _storageService;
  late final AdminService _adminService;

  late AdminPortalSection _currentSection;
  bool _isSidebarCollapsed = false;

  // Auth & Profile state
  UserProfileModel? _profile;
  bool _isAuthLoading = true;
  String? _authErrorMessage;

  // Overview stats state
  AdminDashboardStatsModel _stats = const AdminDashboardStatsModel();
  bool _isStatsLoading = false;
  String? _statsError;

  // 2. User Management state
  final TextEditingController _userSearchCtrl = TextEditingController();
  String _userFilterChip = 'all'; // all, student, professional, admin, active, inactive, suspended, verified, unverified
  AdminPaginatedResponse<AdminUserModel>? _usersPage;
  bool _isUsersLoading = false;
  String? _usersError;
  int _usersCurrentPage = 1;

  // 3. Skill Management state
  final TextEditingController _skillSearchCtrl = TextEditingController();
  String _skillStatusFilter = 'all'; // all, active, inactive
  AdminPaginatedResponse<AdminSkillModel>? _skillsPage;
  bool _isSkillsLoading = false;
  String? _skillsError;
  int _skillsCurrentPage = 1;

  // 4. Skill-Swap Requests state
  final TextEditingController _requestSearchCtrl = TextEditingController();
  String _requestStatusFilter = 'all'; // all, pending, accepted, rejected, cancelled
  AdminPaginatedResponse<AdminSkillRequestModel>? _requestsPage;
  bool _isRequestsLoading = false;
  String? _requestsError;
  int _requestsCurrentPage = 1;

  // 5. Chat Management state
  final TextEditingController _chatSearchCtrl = TextEditingController();
  String _chatStatusFilter = 'all'; // all, reported, restricted, authorized_legacy
  AdminPaginatedResponse<AdminConversationModel>? _conversationsPage;
  bool _isConversationsLoading = false;
  String? _conversationsError;
  int _conversationsCurrentPage = 1;

  // 6. Reports & Moderation state
  final TextEditingController _reportSearchCtrl = TextEditingController();
  String _reportStatusFilter = 'all'; // all, pending, under_review, resolved, dismissed
  String _reportReasonFilter = 'all';
  AdminPaginatedResponse<AdminUserReportModel>? _reportsPage;
  bool _isReportsLoading = false;
  String? _reportsError;
  int _reportsCurrentPage = 1;

  // 7. Audit Logs state
  final TextEditingController _auditSearchCtrl = TextEditingController();
  String _auditModelFilter = 'all';
  AdminPaginatedResponse<AdminAuditLogModel>? _auditLogsPage;
  bool _isAuditLoading = false;
  String? _auditError;
  int _auditCurrentPage = 1;

  // 8. Messaging Policy state
  AdminMessagingPolicyEnvelope? _policyEnvelope;
  bool _isPolicyLoading = false;
  bool _isPolicySaving = false;
  String? _policyError;
  final TextEditingController _maxPerMinCtrl = TextEditingController(text: '5');
  final TextEditingController _maxPerConvDayCtrl = TextEditingController(
    text: '50',
  );
  final TextEditingController _maxPerUserDayCtrl = TextEditingController(
    text: '100',
  );
  final TextEditingController _warningPercentCtrl = TextEditingController(
    text: '80',
  );
  final TextEditingController _cooldownMinCtrl = TextEditingController(
    text: '15',
  );
  bool _enforceAcceptedReq = true;
  bool _enableRateLimiting = true;

  // 9. Admin Settings state
  final TextEditingController _adminEmailCtrl = TextEditingController();
  final TextEditingController _adminPhoneCtrl = TextEditingController();
  final TextEditingController _adminBioCtrl = TextEditingController();
  bool _isSavingAdminProfile = false;

  @override
  void initState() {
    super.initState();
    _currentSection = widget.initialSection;
    _profileService = widget.profileService ?? ProfileService();
    _storageService = widget.storageService ?? StorageService();
    _adminService = widget.adminService ?? AdminService();
    _loadAdminData();
  }

  @override
  void dispose() {
    _userSearchCtrl.dispose();
    _skillSearchCtrl.dispose();
    _requestSearchCtrl.dispose();
    _chatSearchCtrl.dispose();
    _reportSearchCtrl.dispose();
    _auditSearchCtrl.dispose();
    _maxPerMinCtrl.dispose();
    _maxPerConvDayCtrl.dispose();
    _maxPerUserDayCtrl.dispose();
    _warningPercentCtrl.dispose();
    _cooldownMinCtrl.dispose();
    _adminEmailCtrl.dispose();
    _adminPhoneCtrl.dispose();
    _adminBioCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    setState(() {
      _isAuthLoading = true;
      _authErrorMessage = null;
    });

    try {
      final profile = await _profileService.getProfile();
      if (!profile.isAdministrator) {
        await _storageService.clearTokens();
        if (mounted) {
          setState(() {
            _authErrorMessage =
                'Access Denied: You do not have administrator permissions.';
            _isAuthLoading = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _profile = profile;
          _adminEmailCtrl.text = profile.email;
          _adminPhoneCtrl.text = profile.phone;
          _adminBioCtrl.text = profile.bio;
          _isAuthLoading = false;
        });
        _loadStats();
        _loadSectionData(_currentSection);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _authErrorMessage =
              'Failed to verify administrator status. Please login again.';
          _isAuthLoading = false;
        });
      }
    }
  }

  void _navigateToSection(
    AdminPortalSection section, {
    String? userFilter,
    String? skillFilter,
    String? requestFilter,
    String? chatFilter,
    String? reportFilter,
  }) {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    setState(() {
      _currentSection = section;
      if (userFilter != null) {
        _userFilterChip = userFilter;
        _usersCurrentPage = 1;
      }
      if (skillFilter != null) {
        _skillStatusFilter = skillFilter;
        _skillsCurrentPage = 1;
      }
      if (requestFilter != null) {
        _requestStatusFilter = requestFilter;
        _requestsCurrentPage = 1;
      }
      if (chatFilter != null) {
        _chatStatusFilter = chatFilter;
        _conversationsCurrentPage = 1;
      }
      if (reportFilter != null) {
        _reportStatusFilter = reportFilter;
        _reportsCurrentPage = 1;
      }
    });
    _loadSectionData(section);
  }

  Future<void> _refreshCurrentView() async {
    await _loadStats();
    if (_currentSection != AdminPortalSection.overview) {
      await _loadSectionData(_currentSection);
    }
  }

  Future<void> _loadSectionData(AdminPortalSection section) async {
    switch (section) {
      case AdminPortalSection.overview:
        await _loadStats();
        break;
      case AdminPortalSection.users:
        await _loadUsers(page: _usersCurrentPage);
        break;
      case AdminPortalSection.skills:
        await _loadSkills(page: _skillsCurrentPage);
        break;
      case AdminPortalSection.requests:
        await _loadRequests(page: _requestsCurrentPage);
        break;
      case AdminPortalSection.chat:
        await _loadConversations(page: _conversationsCurrentPage);
        break;
      case AdminPortalSection.reports:
        await _loadReports(page: _reportsCurrentPage);
        break;
      case AdminPortalSection.auditLogs:
        await _loadAuditLogs(page: _auditCurrentPage);
        break;
      case AdminPortalSection.messagingPolicies:
        await _loadMessagingPolicy();
        break;
      case AdminPortalSection.adminSettings:
        break;
    }
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() {
      _isStatsLoading = true;
      _statsError = null;
    });
    try {
      final stats = await _adminService.getDashboardStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _isStatsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statsError = e.toString();
        _isStatsLoading = false;
      });
    }
  }

  Future<void> _loadUsers({int page = 1}) async {
    if (!mounted) return;
    setState(() {
      _isUsersLoading = true;
      _usersError = null;
      _usersCurrentPage = page;
    });

    String? roleParam;
    String? statusParam;
    bool? verifiedParam;

    switch (_userFilterChip) {
      case 'student':
      case 'professional':
      case 'admin':
        roleParam = _userFilterChip;
        break;
      case 'active':
      case 'inactive':
      case 'suspended':
        statusParam = _userFilterChip;
        break;
      case 'verified':
        verifiedParam = true;
        break;
      case 'unverified':
        verifiedParam = false;
        break;
    }

    try {
      final res = await _adminService.getUsers(
        search: _userSearchCtrl.text,
        role: roleParam,
        status: statusParam,
        isVerified: verifiedParam,
        page: page,
        pageSize: 20,
      );
      if (!mounted) return;
      setState(() {
        _usersPage = res;
        _isUsersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usersError = e.toString();
        _isUsersLoading = false;
      });
    }
  }

  Future<void> _loadSkills({int page = 1}) async {
    if (!mounted) return;
    setState(() {
      _isSkillsLoading = true;
      _skillsError = null;
      _skillsCurrentPage = page;
    });

    bool? isActive;
    if (_skillStatusFilter == 'active') isActive = true;
    if (_skillStatusFilter == 'inactive') isActive = false;

    try {
      final res = await _adminService.getSkills(
        search: _skillSearchCtrl.text,
        isActive: isActive,
        page: page,
        pageSize: 50,
      );
      if (!mounted) return;
      setState(() {
        _skillsPage = res;
        _isSkillsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _skillsError = e.toString();
        _isSkillsLoading = false;
      });
    }
  }

  Future<void> _loadRequests({int page = 1}) async {
    if (!mounted) return;
    setState(() {
      _isRequestsLoading = true;
      _requestsError = null;
      _requestsCurrentPage = page;
    });

    try {
      final res = await _adminService.getRequests(
        search: _requestSearchCtrl.text,
        status: _requestStatusFilter,
        page: page,
        pageSize: 30,
      );
      if (!mounted) return;
      setState(() {
        _requestsPage = res;
        _isRequestsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _requestsError = e.toString();
        _isRequestsLoading = false;
      });
    }
  }

  Future<void> _loadConversations({int page = 1}) async {
    if (!mounted) return;
    setState(() {
      _isConversationsLoading = true;
      _conversationsError = null;
      _conversationsCurrentPage = page;
    });

    try {
      final res = await _adminService.getConversations(
        search: _chatSearchCtrl.text,
        status: _chatStatusFilter,
        page: page,
        pageSize: 30,
      );
      if (!mounted) return;
      setState(() {
        _conversationsPage = res;
        _isConversationsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _conversationsError = e.toString();
        _isConversationsLoading = false;
      });
    }
  }

  Future<void> _loadReports({int page = 1}) async {
    if (!mounted) return;
    setState(() {
      _isReportsLoading = true;
      _reportsError = null;
      _reportsCurrentPage = page;
    });

    try {
      final res = await _adminService.getReports(
        search: _reportSearchCtrl.text,
        status: _reportStatusFilter,
        reason: _reportReasonFilter,
        page: page,
        pageSize: 30,
      );
      if (!mounted) return;
      setState(() {
        _reportsPage = res;
        _isReportsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reportsError = e.toString();
        _isReportsLoading = false;
      });
    }
  }

  Future<void> _loadAuditLogs({int page = 1}) async {
    if (!mounted) return;
    setState(() {
      _isAuditLoading = true;
      _auditError = null;
      _auditCurrentPage = page;
    });

    try {
      final res = await _adminService.getAuditLogs(
        search: _auditSearchCtrl.text,
        targetModel: _auditModelFilter,
        page: page,
        pageSize: 40,
      );
      if (!mounted) return;
      setState(() {
        _auditLogsPage = res;
        _isAuditLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _auditError = e.toString();
        _isAuditLoading = false;
      });
    }
  }

  Future<void> _loadMessagingPolicy() async {
    if (!mounted) return;
    setState(() {
      _isPolicyLoading = true;
      _policyError = null;
    });

    try {
      final env = await _adminService.getMessagingPolicy();
      if (!mounted) return;
      setState(() {
        _policyEnvelope = env;
        _maxPerMinCtrl.text = '${env.policy.maxMessagesPerMinute}';
        _maxPerConvDayCtrl.text =
            '${env.policy.maxMessagesPerConversationPerDay}';
        _maxPerUserDayCtrl.text = '${env.policy.maxMessagesPerUserPerDay}';
        _warningPercentCtrl.text = '${env.policy.warningThresholdPercent}';
        _cooldownMinCtrl.text = '${env.policy.cooldownMinutes}';
        _enforceAcceptedReq = env.policy.enforceAcceptedRequest;
        _enableRateLimiting = env.policy.enableRateLimiting;
        _isPolicyLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _policyError = e.toString();
        _isPolicyLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    await _storageService.clearTokens();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.login,
      (route) => false,
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 960;
    final isTablet = width >= 600 && width < 960;

    if (_isAuthLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }

    if (_authErrorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: _buildTopBar(isDesktop: isDesktop, isTablet: isTablet),
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.gpp_bad_rounded,
                  color: Color(0xFFEF4444),
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Administrator Access Restricted',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _authErrorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Return to Login'),
                  onPressed: _handleLogout,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final baseTheme = Theme.of(context);
    final adminPortalTheme = baseTheme.copyWith(
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          side: const BorderSide(color: Color(0xFF475569)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );

    return Theme(
      data: adminPortalTheme,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFF0F172A),
        appBar: _buildTopBar(isDesktop: isDesktop, isTablet: isTablet),
        drawer: isDesktop
            ? null
            : Drawer(
                backgroundColor: const Color(0xFF1E293B),
                child: SafeArea(
                  child: _buildSidebarNavigation(isCollapsed: false),
                ),
              ),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isDesktop)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isSidebarCollapsed ? 74 : 256,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  border: Border(right: BorderSide(color: Color(0xFF334155))),
                ),
                child: _buildSidebarNavigation(
                  isCollapsed: _isSidebarCollapsed,
                ),
              ),
            Expanded(
              child: KeyedSubtree(
                key: ValueKey<AdminPortalSection>(_currentSection),
                child: _buildActiveSectionContent(
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildTopBar({
    required bool isDesktop,
    required bool isTablet,
  }) {
    return AppBar(
      backgroundColor: const Color(0xFF1E293B),
      elevation: 0,
      leading: isDesktop
          ? IconButton(
              tooltip:
                  _isSidebarCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar',
              icon: Icon(
                _isSidebarCollapsed
                    ? Icons.menu_open_rounded
                    : Icons.menu_rounded,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
              },
            )
          : IconButton(
              tooltip: 'Open Navigation Menu',
              icon: const Icon(Icons.menu_rounded, color: Colors.white),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
      titleSpacing: 4,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Flexible(
            child: Text(
              'SkillSwap Admin',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF312E81),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF818CF8)),
            ),
            child: const Text(
              'PORTAL',
              style: TextStyle(
                color: Color(0xFFC7D2FE),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh Live Data',
          onPressed: _refreshCurrentView,
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFFCBD5E1)),
        ),
        if (_profile != null)
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _navigateToSection(AdminPortalSection.adminSettings),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFF6366F1),
                    child: Text(
                      _profile!.username.isNotEmpty
                          ? _profile!.username[0].toUpperCase()
                          : 'A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isDesktop || isTablet) ...[
                    const SizedBox(width: 8),
                    Text(
                      _profile!.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        IconButton(
          tooltip: 'Logout',
          icon: const Icon(Icons.logout_rounded, color: Color(0xFF94A3B8)),
          onPressed: _handleLogout,
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _buildSidebarNavigation({required bool isCollapsed}) {
    final navItems = <({
      AdminPortalSection section,
      IconData icon,
      String label,
      int? badge
    })>[
      (
        section: AdminPortalSection.overview,
        icon: Icons.dashboard_rounded,
        label: 'Overview',
        badge: null,
      ),
      (
        section: AdminPortalSection.users,
        icon: Icons.people_alt_rounded,
        label: 'User Management',
        badge: _stats.unverifiedUsers > 0 ? _stats.unverifiedUsers : null,
      ),
      (
        section: AdminPortalSection.skills,
        icon: Icons.auto_awesome_mosaic_rounded,
        label: 'Skill Management',
        badge: null,
      ),
      (
        section: AdminPortalSection.requests,
        icon: Icons.swap_horiz_rounded,
        label: 'Skill-Swap Requests',
        badge: _stats.pendingRequests > 0 ? _stats.pendingRequests : null,
      ),
      (
        section: AdminPortalSection.chat,
        icon: Icons.forum_rounded,
        label: 'Chat Management',
        badge: _stats.reportedConversations > 0
            ? _stats.reportedConversations
            : null,
      ),
      (
        section: AdminPortalSection.reports,
        icon: Icons.gavel_rounded,
        label: 'Reports & Moderation',
        badge: _stats.pendingReports > 0 ? _stats.pendingReports : null,
      ),
      (
        section: AdminPortalSection.auditLogs,
        icon: Icons.security_rounded,
        label: 'Audit Logs',
        badge: null,
      ),
      (
        section: AdminPortalSection.messagingPolicies,
        icon: Icons.tune_rounded,
        label: 'Messaging Policies',
        badge: null,
      ),
      (
        section: AdminPortalSection.adminSettings,
        icon: Icons.settings_rounded,
        label: 'Admin Settings',
        badge: null,
      ),
    ];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            children: [
              if (!isCollapsed)
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 4, 12, 10),
                  child: Text(
                    'MANAGEMENT CONSOLE',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ...navItems.map((item) {
                final isSelected = _currentSection == item.section;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: isSelected
                        ? const Color(0xFF6366F1).withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _navigateToSection(item.section),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCollapsed ? 0 : 12,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(
                                  color: const Color(0xFF6366F1).withValues(
                                    alpha: 0.5,
                                  ),
                                )
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: isCollapsed
                              ? MainAxisAlignment.center
                              : MainAxisAlignment.start,
                          children: [
                            Icon(
                              item.icon,
                              size: 20,
                              color: isSelected
                                  ? const Color(0xFF818CF8)
                                  : const Color(0xFF94A3B8),
                            ),
                            if (!isCollapsed) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.label,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFFCBD5E1),
                                    fontSize: 13.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (item.badge != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${item.badge}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        if (!isCollapsed && _profile != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(top: BorderSide(color: Color(0xFF334155))),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF10B981),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${_profile!.username}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _profile!.isSuperuser
                            ? 'Super Administrator'
                            : 'Authorized Admin',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActiveSectionContent({
    required bool isDesktop,
    required bool isTablet,
  }) {
    switch (_currentSection) {
      case AdminPortalSection.overview:
        return _buildOverviewSection(isDesktop: isDesktop, isTablet: isTablet);
      case AdminPortalSection.users:
        return _buildUsersSection(isDesktop: isDesktop, isTablet: isTablet);
      case AdminPortalSection.skills:
        return _buildSkillsSection(isDesktop: isDesktop, isTablet: isTablet);
      case AdminPortalSection.requests:
        return _buildRequestsSection(isDesktop: isDesktop, isTablet: isTablet);
      case AdminPortalSection.chat:
        return _buildChatSection(isDesktop: isDesktop, isTablet: isTablet);
      case AdminPortalSection.reports:
        return _buildReportsSection(isDesktop: isDesktop, isTablet: isTablet);
      case AdminPortalSection.auditLogs:
        return _buildAuditLogsSection(isDesktop: isDesktop, isTablet: isTablet);
      case AdminPortalSection.messagingPolicies:
        return _buildMessagingPoliciesSection(
          isDesktop: isDesktop,
          isTablet: isTablet,
        );
      case AdminPortalSection.adminSettings:
        return _buildAdminSettingsSection(
          isDesktop: isDesktop,
          isTablet: isTablet,
        );
    }
  }

  // ---------------------------------------------------------------------------
  // 1. OVERVIEW SECTION
  // ---------------------------------------------------------------------------

  Widget _buildOverviewSection({
    required bool isDesktop,
    required bool isTablet,
  }) {
    final horizontalPad = isDesktop ? 28.0 : (isTablet ? 20.0 : 14.0);
    final gridCols = isDesktop ? 5 : (isTablet ? 3 : 2);

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome & Quick Action Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF4338CA)),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, ${_profile?.username ?? "Administrator"}!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Live SkillSwap Administrative Control Center. Click any metric card below to open the filtered management view.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isStatsLoading ? null : _loadStats,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    icon: _isStatsLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.sync_rounded, size: 18),
                    label: const Text('Refresh Stats'),
                  ),
                ],
              ),
            ),

            if (_statsError != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEF4444)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFCA5A5),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Unable to fetch latest statistics: $_statsError',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadStats,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 22),

            // Quick Admin Controls Cards (Interactive & backward-compatible)
            const Text(
              'Admin Controls',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            GridView(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isDesktop ? 3 : (isTablet ? 3 : 1),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                mainAxisExtent: 168,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildInteractiveModuleCard(
                  icon: Icons.people_alt_rounded,
                  color: const Color(0xFF38BDF8),
                  title: 'User Management',
                  description:
                      'Search, filter, inspect profiles, verify accounts, and manage suspensions (${_stats.totalUsers} users).',
                  onTap: () => _navigateToSection(AdminPortalSection.users),
                ),
                _buildInteractiveModuleCard(
                  icon: Icons.verified_user_rounded,
                  color: const Color(0xFF34D399),
                  title: 'Skill Approvals',
                  description:
                      'Manage skill catalog (${_stats.totalSkills} skills) and review swap requests (${_stats.pendingRequests} pending).',
                  onTap: () => _navigateToSection(AdminPortalSection.skills),
                ),
                _buildInteractiveModuleCard(
                  icon: Icons.security_rounded,
                  color: const Color(0xFFA78BFA),
                  title: 'Audit & Security Logs',
                  description:
                      'Inspect immutable administrative actions (${_stats.totalAuditLogs} events) and moderation reports.',
                  onTap: () => _navigateToSection(AdminPortalSection.auditLogs),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // USER STATISTICS
            _buildSectionCategoryHeader(
              'User Statistics',
              'Click any metric to filter User Management',
              onViewAll: () => _navigateToSection(AdminPortalSection.users),
            ),
            const SizedBox(height: 10),
            GridView(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: gridCols,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 132,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                AdminStatMetricCard(
                  title: 'Total Registered',
                  value: '${_stats.totalUsers}',
                  subtitle: 'All accounts',
                  icon: Icons.groups_rounded,
                  color: const Color(0xFF6366F1),
                  onTap: () => _navigateToSection(
                    AdminPortalSection.users,
                    userFilter: 'all',
                  ),
                ),
                AdminStatMetricCard(
                  title: 'Students',
                  value: '${_stats.totalStudents}',
                  subtitle: 'Role: student',
                  icon: Icons.school_rounded,
                  color: const Color(0xFF38BDF8),
                  onTap: () => _navigateToSection(
                    AdminPortalSection.users,
                    userFilter: 'student',
                  ),
                ),
                AdminStatMetricCard(
                  title: 'Professionals',
                  value: '${_stats.totalProfessionals}',
                  subtitle: 'Role: professional',
                  icon: Icons.work_outline_rounded,
                  color: const Color(0xFF10B981),
                  onTap: () => _navigateToSection(
                    AdminPortalSection.users,
                    userFilter: 'professional',
                  ),
                ),
                AdminStatMetricCard(
                  title: 'Administrators',
                  value: '${_stats.totalAdministrators}',
                  subtitle: 'Admin / Staff / Super',
                  icon: Icons.admin_panel_settings_rounded,
                  color: const Color(0xFFA78BFA),
                  onTap: () => _navigateToSection(
                    AdminPortalSection.users,
                    userFilter: 'admin',
                  ),
                ),
                AdminStatMetricCard(
                  title: 'Active Users',
                  value: '${_stats.activeUsers}',
                  subtitle: 'Currently active',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF34D399),
                  onTap: () => _navigateToSection(
                    AdminPortalSection.users,
                    userFilter: 'active',
                  ),
                ),
                AdminStatMetricCard(
                  title: 'Inactive Users',
                  value: '${_stats.inactiveUsers}',
                  subtitle: 'Disabled sessions',
                  icon: Icons.pause_circle_outline_rounded,
                  color: const Color(0xFF94A3B8),
                  onTap: () => _navigateToSection(
                    AdminPortalSection.users,
                    userFilter: 'inactive',
                  ),
                ),
                AdminStatMetricCard(
                  title: 'Suspended Users',
                  value: '${_stats.suspendedUsers}',
                  subtitle: 'Moderation holds',
                  icon: Icons.block_rounded,
                  color: const Color(0xFFEF4444),
                  onTap: () => _navigateToSection(
                    AdminPortalSection.users,
                    userFilter: 'suspended',
                  ),
                ),
                AdminStatMetricCard(
                  title: 'Verified Users',
                  value: '${_stats.verifiedUsers}',
                  subtitle: 'Identity verified',
                  icon: Icons.verified_rounded,
                  color: const Color(0xFF0EA5E9),
                  onTap: () => _navigateToSection(
                    AdminPortalSection.users,
                    userFilter: 'verified',
                  ),
                ),
                AdminStatMetricCard(
                  title: 'Unverified Users',
                  value: '${_stats.unverifiedUsers}',
                  subtitle: 'Awaiting review',
                  icon: Icons.pending_actions_rounded,
                  color: const Color(0xFFF59E0B),
                  onTap: () => _navigateToSection(
                    AdminPortalSection.users,
                    userFilter: 'unverified',
                  ),
                ),
                AdminStatMetricCard(
                  title: 'Recent Signups',
                  value: '${_stats.recentlyRegisteredUsers}',
                  subtitle: 'Last 7 days',
                  icon: Icons.person_add_alt_1_rounded,
                  color: const Color(0xFFEC4899),
                  onTap: () => _navigateToSection(
                    AdminPortalSection.users,
                    userFilter: 'all',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // SKILL & REQUEST STATISTICS
            _buildSectionCategoryHeader(
              'Skill & Swap Request Statistics',
              'Live catalog usage and exchange metrics',
              onViewAll: () => _navigateToSection(AdminPortalSection.requests),
            ),
            const SizedBox(height: 10),
            GridView(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: gridCols,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 132,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                AdminStatMetricCard(
                  title: 'Total Skills',
                  value: '${_stats.totalSkills}',
                  subtitle: 'Master catalog',
                  icon: Icons.category_rounded,
                  color: const Color(0xFF6366F1),
                  onTap: () => _navigateToSection(
                    AdminPortalSection.skills,
                    skillFilter: 'all',
                  ),
                ),
                AdminStatMetricCard(
                  title: 'Active Skills',
                  value: '${_stats.activeSkills}',
                  subtitle: 'Available to users',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF10B981),
                  onTap: () => _navigateToSection(
                    AdminPortalSection.skills,
                    skillFilter: 'active',
                  ),
                ),
                AdminStatMetricCard(
                  title: 'Inactive Skills',
                  value: '${_stats.inactiveSkills}',
                  subtitle: 'Deactivated skills',
                  icon: Icons.visibility_off_rounded,
                  color: const Color(0xFF94A3B8),
                  onTap: () => _navigateToSection(
                    AdminPortalSection.skills,
                    skillFilter: 'inactive',
                  ),
                ),
                AdminStatMetricCard(
                  title: 'Users Teaching',
                  value: '${_stats.totalUsersTeachingSkills}',
                  subtitle: 'Active mentors',
                  icon: Icons.record_voice_over_rounded,
                  color: const Color(0xFF38BDF8),
                  onTap: () => _navigateToSection(AdminPortalSection.skills),
                ),
                AdminStatMetricCard(
                  title: 'Users Learning',
                  value: '${_stats.totalUsersLearningSkills}',
                  subtitle: 'Active learners',
                  icon: Icons.menu_book_rounded,
                  color: const Color(0xFFA78BFA),
                  onTap: () => _navigateToSection(AdminPortalSection.skills),
                ),
                AdminStatMetricCard(
                  title: 'Total Requests',
                  value: '${_stats.totalRequests}',
                  subtitle: 'All swap requests',
                  icon: Icons.swap_calls_rounded,
                  color: const Color(0xFF818CF8),
                  onTap: () => _navigateToSection(
                    AdminPortalSection.requests,
                    requestFilter: 'all',
                  ),
                ),
                AdminStatMetricCard(
                  title: 'Pending Requests',
                  value: '${_stats.pendingRequests}',
                  subtitle: 'Awaiting response',
                  icon: Icons.hourglass_top_rounded,
                  color: const Color(0xFFF59E0B),
                  onTap: () => _navigateToSection(
                    AdminPortalSection.requests,
                    requestFilter: 'pending',
                  ),
                ),
                AdminStatMetricCard(
                  title: 'Accepted Requests',
                  value: '${_stats.acceptedRequests}',
                  subtitle: 'Active exchanges',
                  icon: Icons.handshake_rounded,
                  color: const Color(0xFF10B981),
                  onTap: () => _navigateToSection(
                    AdminPortalSection.requests,
                    requestFilter: 'accepted',
                  ),
                ),
                AdminStatMetricCard(
                  title: 'Rejected Requests',
                  value: '${_stats.rejectedRequests}',
                  subtitle: 'Declined swaps',
                  icon: Icons.cancel_outlined,
                  color: const Color(0xFFEF4444),
                  onTap: () => _navigateToSection(
                    AdminPortalSection.requests,
                    requestFilter: 'rejected',
                  ),
                ),
                AdminStatMetricCard(
                  title: 'Cancelled Requests',
                  value: '${_stats.cancelledRequests}',
                  subtitle: 'Withdrawn swaps',
                  icon: Icons.remove_circle_outline_rounded,
                  color: const Color(0xFF64748B),
                  onTap: () => _navigateToSection(
                    AdminPortalSection.requests,
                    requestFilter: 'cancelled',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // CHAT, REPORTS & SECURITY STATISTICS
            _buildSectionCategoryHeader(
              'Chat, Moderation & Audit Statistics',
              'Conversations, user reports, and security events',
              onViewAll: () => _navigateToSection(AdminPortalSection.reports),
            ),
            const SizedBox(height: 10),
            GridView(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isDesktop ? 4 : (isTablet ? 3 : 2),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 132,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                AdminStatMetricCard(
                  title: 'Conversations',
                  value: '${_stats.totalConversations}',
                  subtitle: 'Total chat rooms',
                  icon: Icons.chat_bubble_outline_rounded,
                  color: const Color(0xFF38BDF8),
                  onTap: () => _navigateToSection(
                    AdminPortalSection.chat,
                    chatFilter: 'all',
                  ),
                ),
                AdminStatMetricCard(
                  title: 'Total Messages',
                  value: '${_stats.totalMessages}',
                  subtitle: '${_stats.recentMessages} in last 7d',
                  icon: Icons.mark_chat_read_rounded,
                  color: const Color(0xFF6366F1),
                  onTap: () => _navigateToSection(AdminPortalSection.chat),
                ),
                AdminStatMetricCard(
                  title: 'Reported Chats',
                  value: '${_stats.reportedConversations}',
                  subtitle: 'Flagged / restricted',
                  icon: Icons.report_gmailerrorred_rounded,
                  color: const Color(0xFFEF4444),
                  onTap: () => _navigateToSection(
                    AdminPortalSection.chat,
                    chatFilter: 'reported',
                  ),
                ),
                AdminStatMetricCard(
                  title: 'Pending Reports',
                  value: '${_stats.pendingReports}',
                  subtitle: '${_stats.underReviewReports} under review',
                  icon: Icons.flag_rounded,
                  color: const Color(0xFFF59E0B),
                  onTap: () => _navigateToSection(
                    AdminPortalSection.reports,
                    reportFilter: 'pending',
                  ),
                ),
                AdminStatMetricCard(
                  title: 'Resolved Reports',
                  value: '${_stats.resolvedReports}',
                  subtitle: '${_stats.dismissedReports} dismissed',
                  icon: Icons.task_alt_rounded,
                  color: const Color(0xFF10B981),
                  onTap: () => _navigateToSection(
                    AdminPortalSection.reports,
                    reportFilter: 'resolved',
                  ),
                ),
                AdminStatMetricCard(
                  title: 'Audit Log Events',
                  value: '${_stats.totalAuditLogs}',
                  subtitle: 'Immutable records',
                  icon: Icons.policy_rounded,
                  color: const Color(0xFFA78BFA),
                  onTap: () => _navigateToSection(AdminPortalSection.auditLogs),
                ),
              ],
            ),

            const SizedBox(height: 26),

            // RECENTLY REGISTERED USERS & RECENT ADMIN ACTIVITIES
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildRecentUsersPanel()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildRecentAuditPanel()),
                ],
              )
            else ...[
              _buildRecentUsersPanel(),
              const SizedBox(height: 16),
              _buildRecentAuditPanel(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveModuleCard({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFF64748B),
                    size: 18,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentUsersPanel() {
    return Material(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Recently Registered Users',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _navigateToSection(AdminPortalSection.users),
                  child: const Text('Manage All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_stats.recentUsers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No registered users found.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              )
            else
              ..._stats.recentUsers.map(
                (u) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF312E81),
                    child: Text(
                      u.username.isNotEmpty ? u.username[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    '${u.fullName} (@${u.username})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${u.email} • ${u.displayRole}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11.5,
                    ),
                  ),
                  trailing: AdminStatusBadge.forAccountStatus(u.accountStatus),
                  onTap: () => _openUserDetailModal(u.id, initialUser: u),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAuditPanel() {
    return Material(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Recent Administrative Activities',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      _navigateToSection(AdminPortalSection.auditLogs),
                  child: const Text('Full Log'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_stats.recentAdminActivities.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No administrative actions logged yet.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              )
            else
              ..._stats.recentAdminActivities.map(
                (log) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.shield_outlined,
                    color: Color(0xFFA78BFA),
                    size: 18,
                  ),
                  title: Text(
                    log.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'By @${log.adminUsername} • ${formatAdminTimestamp(log.createdAt)}',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCategoryHeader(
    String title,
    String subtitle, {
    VoidCallback? onViewAll,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (onViewAll != null)
          TextButton.icon(
            onPressed: onViewAll,
            icon: const Icon(Icons.open_in_new_rounded, size: 15),
            label: const Text('Open Section'),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. USER MANAGEMENT SECTION
  // ---------------------------------------------------------------------------

  Future<void> _openUserDetailModal(
    int userId, {
    AdminUserModel? initialUser,
  }) async {
    final changed = await showAdminUserDetailDialog(
      context,
      userId: userId,
      adminService: _adminService,
      initialUser: initialUser,
    );
    if (changed == true) {
      _loadUsers(page: _usersCurrentPage);
      _loadStats();
    }
  }

  Future<void> _quickVerifyUser(AdminUserModel user) async {
    try {
      final nextState = !user.isVerified;
      await _adminService.verifyUser(
        user.id,
        isVerified: nextState,
        reason: nextState
            ? 'Verified by admin from User Management table'
            : 'Verification revoked by admin from User Management table',
      );
      _showSnack(
        nextState
            ? 'Verified @${user.username}.'
            : 'Revoked verification for @${user.username}.',
      );
      _loadUsers(page: _usersCurrentPage);
      _loadStats();
    } catch (e) {
      _showSnack('Failed to update verification: $e', isError: true);
    }
  }

  Future<void> _quickSuspendOrReactivateUser(AdminUserModel user) async {
    if (user.isSuspended || !user.isActive) {
      try {
        await _adminService.updateUserStatus(
          user.id,
          action: 'reactivate',
          reason: 'Reactivated from User Management table',
        );
        _showSnack('Reactivated @${user.username}.');
        _loadUsers(page: _usersCurrentPage);
        _loadStats();
      } catch (e) {
        _showSnack('Failed to reactivate: $e', isError: true);
      }
    } else {
      final res = await showAdminSuspendUserDialog(
        context,
        username: user.username,
      );
      if (res == null) return;
      try {
        await _adminService.updateUserStatus(
          user.id,
          action: 'suspend',
          reason: res['reason'] as String,
          durationDays: res['duration_days'] as int?,
        );
        _showSnack('Suspended @${user.username}.');
        _loadUsers(page: _usersCurrentPage);
        _loadStats();
      } catch (e) {
        _showSnack('Failed to suspend user: $e', isError: true);
      }
    }
  }

  Widget _buildUsersSection({
    required bool isDesktop,
    required bool isTablet,
  }) {
    final filterOptions = <({String key, String label})>[
      (key: 'all', label: 'All Users'),
      (key: 'student', label: 'Students'),
      (key: 'professional', label: 'Professionals'),
      (key: 'admin', label: 'Administrators'),
      (key: 'active', label: 'Active'),
      (key: 'inactive', label: 'Inactive'),
      (key: 'suspended', label: 'Suspended'),
      (key: 'verified', label: 'Verified'),
      (key: 'unverified', label: 'Unverified'),
    ];

    final users = _usersPage?.results ?? const [];

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageTitleBar(
            title: 'User Management',
            subtitle:
                'Search, filter, inspect full profiles, verify accounts, and manage suspensions.',
            onRefresh: () => _loadUsers(page: _usersCurrentPage),
          ),
          const SizedBox(height: 16),

          // Search & Filter Toolbar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _userSearchCtrl,
                        style: const TextStyle(color: Colors.white),
                        onSubmitted: (_) => _loadUsers(page: 1),
                        decoration: InputDecoration(
                          hintText:
                              'Search by username, full name, email, or phone...',
                          hintStyle: const TextStyle(color: Color(0xFF64748B)),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF94A3B8),
                          ),
                          suffixIcon: _userSearchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  onPressed: () {
                                    _userSearchCtrl.clear();
                                    _loadUsers(page: 1);
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => _loadUsers(page: 1),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: const Text('Search'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: filterOptions.map((f) {
                    final selected = _userFilterChip == f.key;
                    return ChoiceChip(
                      label: Text(f.label),
                      selected: selected,
                      selectedColor: const Color(0xFF6366F1),
                      backgroundColor: const Color(0xFF0F172A),
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.white
                            : const Color(0xFFCBD5E1),
                        fontSize: 12.5,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) {
                        setState(() => _userFilterChip = f.key);
                        _loadUsers(page: 1);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_isUsersLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              ),
            )
          else if (_usersError != null)
            AdminEmptyOrErrorState(
              icon: Icons.error_outline_rounded,
              title: 'Failed to Load Users',
              subtitle: _usersError!,
              actionLabel: 'Retry',
              onAction: () => _loadUsers(page: _usersCurrentPage),
              isError: true,
            )
          else if (users.isEmpty)
            AdminEmptyOrErrorState(
              icon: Icons.person_search_rounded,
              title: 'No Matching Users Found',
              subtitle:
                  'Try clearing your search query or switching the active filter.',
              actionLabel: 'Reset Filters',
              onAction: () {
                _userSearchCtrl.clear();
                setState(() => _userFilterChip = 'all');
                _loadUsers(page: 1);
              },
            )
          else ...[
            if (isDesktop)
              _buildDesktopUsersTable(users)
            else
              _buildMobileUserCards(users),
            const SizedBox(height: 16),
            if (_usersPage != null)
              AdminPaginationFooter(
                count: _usersPage!.count,
                page: _usersPage!.page,
                totalPages: _usersPage!.totalPages,
                hasPrevious: _usersPage!.hasPrevious,
                hasNext: _usersPage!.hasNext,
                onPrevious: () => _loadUsers(page: _usersCurrentPage - 1),
                onNext: () => _loadUsers(page: _usersCurrentPage + 1),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopUsersTable(List<AdminUserModel> users) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFF0F172A)),
          columnSpacing: 16,
          horizontalMargin: 14,
          dataRowMinHeight: 56,
          dataRowMaxHeight: 68,
          columns: const [
            DataColumn(
              label: Text('ID', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            DataColumn(
              label: Text(
                'User / Full Name',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
            DataColumn(
              label: Text(
                'Email & Phone',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
            DataColumn(
              label: Text('Role', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            DataColumn(
              label: Text('Status', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            DataColumn(
              label: Text(
                'Verification',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
            DataColumn(
              label: Text(
                'Joined / Activity',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
            DataColumn(
              label: Text(
                'Actions',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
          ],
          rows: users.map((u) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    '#${u.id}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(
                  InkWell(
                    onTap: () => _openUserDetailModal(u.id, initialUser: u),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          u.fullName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                        Text(
                          '@${u.username}',
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        u.email,
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        u.phone.isEmpty ? 'No phone' : u.phone,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Text(
                    u.displayRole,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  ),
                ),
                DataCell(AdminStatusBadge.forAccountStatus(u.accountStatus)),
                DataCell(
                  AdminStatusBadge(
                    label: u.isVerified ? 'Verified' : 'Unverified',
                    color: u.isVerified
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFFF59E0B),
                    icon: u.isVerified
                        ? Icons.verified_rounded
                        : Icons.hourglass_empty_rounded,
                  ),
                ),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Joined: ${formatAdminShortDate(u.dateJoined)}',
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 11.5,
                        ),
                      ),
                      Text(
                        'Active: ${formatAdminShortDate(u.lastActivity ?? u.lastLogin)}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'View Complete Profile & Details',
                        icon: const Icon(
                          Icons.visibility_rounded,
                          color: Color(0xFF38BDF8),
                          size: 19,
                        ),
                        onPressed: () =>
                            _openUserDetailModal(u.id, initialUser: u),
                      ),
                      IconButton(
                        tooltip: u.isVerified
                            ? 'Revoke Verification'
                            : 'Verify Account',
                        icon: Icon(
                          u.isVerified
                              ? Icons.unpublished_outlined
                              : Icons.verified_user_rounded,
                          color: u.isVerified
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF10B981),
                          size: 19,
                        ),
                        onPressed: () => _quickVerifyUser(u),
                      ),
                      IconButton(
                        tooltip: (u.isSuspended || !u.isActive)
                            ? 'Reactivate Account'
                            : 'Suspend Account',
                        icon: Icon(
                          (u.isSuspended || !u.isActive)
                              ? Icons.restore_rounded
                              : Icons.block_rounded,
                          color: (u.isSuspended || !u.isActive)
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          size: 19,
                        ),
                        onPressed: () => _quickSuspendOrReactivateUser(u),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMobileUserCards(List<AdminUserModel> users) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: users.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final u = users[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF6366F1),
                    child: Text(
                      u.username.isNotEmpty ? u.username[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${u.id} • ${u.fullName} (@${u.username})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${u.email} • ${u.displayRole}',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  AdminStatusBadge.forAccountStatus(u.accountStatus),
                  AdminStatusBadge(
                    label: u.isVerified ? 'Verified' : 'Unverified',
                    color: u.isVerified
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFFF59E0B),
                  ),
                  if (u.phone.isNotEmpty)
                    AdminStatusBadge(
                      label: u.phone,
                      color: const Color(0xFF94A3B8),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Joined: ${formatAdminShortDate(u.dateJoined)} • Last Login: ${formatAdminTimestamp(u.lastLogin)}',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
              ),
              const Divider(color: Color(0xFF334155), height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        _openUserDetailModal(u.id, initialUser: u),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF475569)),
                    ),
                    icon: const Icon(Icons.visibility_rounded, size: 16),
                    label: const Text('Details'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _quickVerifyUser(u),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF38BDF8),
                      side: const BorderSide(color: Color(0xFF38BDF8)),
                    ),
                    icon: Icon(
                      u.isVerified
                          ? Icons.unpublished_rounded
                          : Icons.verified_user_rounded,
                      size: 16,
                    ),
                    label: Text(u.isVerified ? 'Unverify' : 'Verify'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _quickSuspendOrReactivateUser(u),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: (u.isSuspended || !u.isActive)
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      side: BorderSide(
                        color: (u.isSuspended || !u.isActive)
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                    icon: Icon(
                      (u.isSuspended || !u.isActive)
                          ? Icons.restore_rounded
                          : Icons.block_rounded,
                      size: 16,
                    ),
                    label: Text(
                      (u.isSuspended || !u.isActive)
                          ? 'Reactivate'
                          : 'Suspend',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 3. SKILL MANAGEMENT SECTION
  // ---------------------------------------------------------------------------

  Future<void> _handleAddOrEditSkill({AdminSkillModel? existing}) async {
    final res = await showAdminSkillFormDialog(
      context,
      existingSkill: existing,
    );
    if (res == null) return;
    try {
      if (existing == null) {
        await _adminService.createSkill(
          name: res['name'] as String,
          category: res['category'] as String,
          description: res['description'] as String,
          isActive: res['is_active'] as bool,
        );
        _showSnack('Skill "${res['name']}" added to catalog.');
      } else {
        await _adminService.updateSkill(
          existing.id,
          name: res['name'] as String,
          category: res['category'] as String,
          description: res['description'] as String,
          isActive: res['is_active'] as bool,
        );
        _showSnack('Skill "${res['name']}" updated.');
      }
      _loadSkills(page: _skillsCurrentPage);
      _loadStats();
    } catch (e) {
      _showSnack('Skill operation failed: $e', isError: true);
    }
  }

  Future<void> _handleToggleSkillActive(AdminSkillModel skill) async {
    try {
      await _adminService.updateSkill(
        skill.id,
        isActive: !skill.isActive,
        reason: skill.isActive
            ? 'Deactivated from Skill Management'
            : 'Activated from Skill Management',
      );
      _showSnack(
        !skill.isActive
            ? 'Activated "${skill.name}".'
            : 'Deactivated "${skill.name}".',
      );
      _loadSkills(page: _skillsCurrentPage);
      _loadStats();
    } catch (e) {
      _showSnack('Failed to toggle skill status: $e', isError: true);
    }
  }

  Future<void> _handleDeleteOrDeactivateSkill(AdminSkillModel skill) async {
    try {
      final res = await _adminService.deleteOrDeactivateSkill(
        skill.id,
        reason: 'Requested removal from Admin Skill Management',
      );
      final msg =
          res['message']?.toString() ?? 'Skill "${skill.name}" processed.';
      _showSnack(msg);
      _loadSkills(page: _skillsCurrentPage);
      _loadStats();
    } catch (e) {
      _showSnack('Failed to remove skill: $e', isError: true);
    }
  }

  Widget _buildSkillsSection({
    required bool isDesktop,
    required bool isTablet,
  }) {
    final skills = _skillsPage?.results ?? const [];

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skill Management',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage the master skill catalog, inspect associated teachers/learners, and safely toggle active status.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _handleAddOrEditSkill(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add New Skill'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search & Filter
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _skillSearchCtrl,
                        style: const TextStyle(color: Colors.white),
                        onSubmitted: (_) => _loadSkills(page: 1),
                        decoration: InputDecoration(
                          hintText:
                              'Search skills by name, category, or description...',
                          hintStyle: const TextStyle(color: Color(0xFF64748B)),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF94A3B8),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => _loadSkills(page: 1),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                      child: const Text('Search'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ('all', 'All Skills'),
                    ('active', 'Active Skills'),
                    ('inactive', 'Inactive Skills'),
                  ].map((item) {
                    final selected = _skillStatusFilter == item.$1;
                    return ChoiceChip(
                      label: Text(item.$2),
                      selected: selected,
                      selectedColor: const Color(0xFF6366F1),
                      backgroundColor: const Color(0xFF0F172A),
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.white
                            : const Color(0xFFCBD5E1),
                        fontSize: 12.5,
                      ),
                      onSelected: (_) {
                        setState(() => _skillStatusFilter = item.$1);
                        _loadSkills(page: 1);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_isSkillsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              ),
            )
          else if (_skillsError != null)
            AdminEmptyOrErrorState(
              icon: Icons.error_outline_rounded,
              title: 'Failed to Load Skills',
              subtitle: _skillsError!,
              actionLabel: 'Retry',
              onAction: () => _loadSkills(page: _skillsCurrentPage),
              isError: true,
            )
          else if (skills.isEmpty)
            AdminEmptyOrErrorState(
              icon: Icons.category_outlined,
              title: 'No Skills Found',
              subtitle: 'Add a new skill or adjust your active filters.',
              actionLabel: 'Add Skill',
              onAction: () => _handleAddOrEditSkill(),
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: skills.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final s = skills[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '#${s.id} • ${s.name}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                AdminStatusBadge(
                                  label: s.category,
                                  color: const Color(0xFF38BDF8),
                                ),
                                AdminStatusBadge(
                                  label: s.isActive ? 'Active' : 'Inactive',
                                  color: s.isActive
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF94A3B8),
                                  icon: s.isActive
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.pause_circle_outline_rounded,
                                ),
                              ],
                            ),
                            if (s.description.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                s.description,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              'Teaching: ${s.teachingUsersCount} users • Learning: ${s.learningUsersCount} users • Swap Requests: ${s.requestsCount}',
                              style: const TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => showAdminSkillUsersDialog(
                              context,
                              skill: s,
                              onInspectUser: (uid) => _openUserDetailModal(uid),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF38BDF8),
                              side: const BorderSide(color: Color(0xFF38BDF8)),
                            ),
                            icon: const Icon(Icons.people_outline_rounded, size: 16),
                            label: Text(
                              'Users (${s.teachingUsersCount + s.learningUsersCount})',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _handleAddOrEditSkill(existing: s),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF475569)),
                            ),
                            icon: const Icon(Icons.edit_rounded, size: 16),
                            label: const Text('Edit'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _handleToggleSkillActive(s),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: s.isActive
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF10B981),
                              side: BorderSide(
                                color: s.isActive
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF10B981),
                              ),
                            ),
                            icon: Icon(
                              s.isActive
                                  ? Icons.visibility_off_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 16,
                            ),
                            label: Text(s.isActive ? 'Deactivate' : 'Activate'),
                          ),
                          IconButton(
                            tooltip:
                                'Safe Remove (Deactivates if referenced by users/requests)',
                            onPressed: () => _handleDeleteOrDeactivateSkill(s),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            if (_skillsPage != null)
              AdminPaginationFooter(
                count: _skillsPage!.count,
                page: _skillsPage!.page,
                totalPages: _skillsPage!.totalPages,
                hasPrevious: _skillsPage!.hasPrevious,
                hasNext: _skillsPage!.hasNext,
                onPrevious: () => _loadSkills(page: _skillsCurrentPage - 1),
                onNext: () => _loadSkills(page: _skillsCurrentPage + 1),
              ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. SKILL-SWAP REQUEST MANAGEMENT SECTION
  // ---------------------------------------------------------------------------

  Future<void> _handleOverrideRequestStatus(
    AdminSkillRequestModel req,
    String newStatus,
  ) async {
    try {
      await _adminService.updateRequestStatus(
        req.id,
        status: newStatus,
        reason: 'Administrative status transition to $newStatus',
      );
      _showSnack('Request #${req.id} marked as $newStatus.');
      _loadRequests(page: _requestsCurrentPage);
      _loadStats();
    } catch (e) {
      _showSnack('Failed to update request status: $e', isError: true);
    }
  }

  Widget _buildRequestsSection({
    required bool isDesktop,
    required bool isTablet,
  }) {
    final requests = _requestsPage?.results ?? const [];

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageTitleBar(
            title: 'Skill-Swap Request Management',
            subtitle:
                'Inspect skill exchange requests, learning goals, and perform administrative status overrides.',
            onRefresh: () => _loadRequests(page: _requestsCurrentPage),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _requestSearchCtrl,
                        style: const TextStyle(color: Colors.white),
                        onSubmitted: (_) => _loadRequests(page: 1),
                        decoration: InputDecoration(
                          hintText:
                              'Search by requester, target user, skill name, or learning goal...',
                          hintStyle: const TextStyle(color: Color(0xFF64748B)),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF94A3B8),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => _loadRequests(page: 1),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                      child: const Text('Search'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ('all', 'All Requests'),
                    ('pending', 'Pending'),
                    ('accepted', 'Accepted'),
                    ('rejected', 'Rejected'),
                    ('cancelled', 'Cancelled'),
                  ].map((item) {
                    final selected = _requestStatusFilter == item.$1;
                    return ChoiceChip(
                      label: Text(item.$2),
                      selected: selected,
                      selectedColor: const Color(0xFF6366F1),
                      backgroundColor: const Color(0xFF0F172A),
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.white
                            : const Color(0xFFCBD5E1),
                        fontSize: 12.5,
                      ),
                      onSelected: (_) {
                        setState(() => _requestStatusFilter = item.$1);
                        _loadRequests(page: 1);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_isRequestsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              ),
            )
          else if (_requestsError != null)
            AdminEmptyOrErrorState(
              icon: Icons.error_outline_rounded,
              title: 'Failed to Load Skill-Swap Requests',
              subtitle: _requestsError!,
              actionLabel: 'Retry',
              onAction: () => _loadRequests(page: _requestsCurrentPage),
              isError: true,
            )
          else if (requests.isEmpty)
            AdminEmptyOrErrorState(
              icon: Icons.swap_horiz_rounded,
              title: 'No Skill-Swap Requests Found',
              subtitle: 'No requests match the current filter criteria.',
              actionLabel: 'Show All',
              onAction: () {
                _requestSearchCtrl.clear();
                setState(() => _requestStatusFilter = 'all');
                _loadRequests(page: 1);
              },
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final r = requests[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Request #${r.id}',
                                style: const TextStyle(
                                  color: Color(0xFF818CF8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 10),
                              AdminStatusBadge.forRequestStatus(r.status),
                            ],
                          ),
                          Text(
                            'Created: ${formatAdminTimestamp(r.createdAt)}',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          InkWell(
                            onTap: () => _openUserDetailModal(r.requesterId),
                            child: Text(
                              'Requester: ${r.requesterFullName} (@${r.requesterUsername} • ${r.requesterEmail})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                          InkWell(
                            onTap: () => _openUserDetailModal(r.targetId),
                            child: Text(
                              'Target: ${r.targetFullName} (@${r.targetUsername} • ${r.targetEmail})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          AdminStatusBadge(
                            label: 'Requested: ${r.requestedSkillName}',
                            color: const Color(0xFF38BDF8),
                            icon: Icons.school_rounded,
                          ),
                          AdminStatusBadge(
                            label:
                                'Offered: ${r.offeredSkillName ?? "Not specified"}',
                            color: const Color(0xFF10B981),
                            icon: Icons.handshake_rounded,
                          ),
                        ],
                      ),
                      if (r.message.isNotEmpty || r.learningGoal.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (r.message.isNotEmpty)
                                Text(
                                  'Message: "${r.message}"',
                                  style: const TextStyle(
                                    color: Color(0xFFCBD5E1),
                                    fontSize: 12.5,
                                  ),
                                ),
                              if (r.learningGoal.isNotEmpty)
                                Text(
                                  'Learning Goal: ${r.learningGoal}',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (r.status != 'accepted')
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _handleOverrideRequestStatus(r, 'accepted'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF10B981),
                                side: const BorderSide(
                                  color: Color(0xFF10B981),
                                ),
                              ),
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text('Accept'),
                            ),
                          if (r.status != 'rejected')
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _handleOverrideRequestStatus(r, 'rejected'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                side: const BorderSide(
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                              icon: const Icon(Icons.close_rounded, size: 16),
                              label: const Text('Reject'),
                            ),
                          if (r.status != 'cancelled')
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _handleOverrideRequestStatus(r, 'cancelled'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF94A3B8),
                                side: const BorderSide(
                                  color: Color(0xFF475569),
                                ),
                              ),
                              icon: const Icon(
                                Icons.cancel_outlined,
                                size: 16,
                              ),
                              label: const Text('Cancel'),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            if (_requestsPage != null)
              AdminPaginationFooter(
                count: _requestsPage!.count,
                page: _requestsPage!.page,
                totalPages: _requestsPage!.totalPages,
                hasPrevious: _requestsPage!.hasPrevious,
                hasNext: _requestsPage!.hasNext,
                onPrevious: () =>
                    _loadRequests(page: _requestsCurrentPage - 1),
                onNext: () => _loadRequests(page: _requestsCurrentPage + 1),
              ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. CHAT MANAGEMENT SECTION
  // ---------------------------------------------------------------------------

  Future<void> _openConversationInspector(int convId) async {
    final changed = await showAdminConversationModerationDialog(
      context,
      conversationId: convId,
      adminService: _adminService,
    );
    if (changed == true) {
      _loadConversations(page: _conversationsCurrentPage);
      _loadStats();
    }
  }

  Widget _buildChatSection({
    required bool isDesktop,
    required bool isTablet,
  }) {
    final convs = _conversationsPage?.results ?? const [];

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chat & Messaging Management',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Inspect conversations for moderation, manage legacy read-only chats, and configure messaging quotas.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _navigateToSection(AdminPortalSection.messagingPolicies),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF38BDF8)),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Messaging Policy Controls'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatSearchCtrl,
                        style: const TextStyle(color: Colors.white),
                        onSubmitted: (_) => _loadConversations(page: 1),
                        decoration: InputDecoration(
                          hintText:
                              'Search conversations by participant username or email...',
                          hintStyle: const TextStyle(color: Color(0xFF64748B)),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF94A3B8),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => _loadConversations(page: 1),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                      child: const Text('Search'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ('all', 'All Conversations'),
                    ('reported', 'Reported / Flagged'),
                    ('restricted', 'Locked / Restricted'),
                    ('authorized_legacy', 'Authorized Legacy'),
                  ].map((item) {
                    final selected = _chatStatusFilter == item.$1;
                    return ChoiceChip(
                      label: Text(item.$2),
                      selected: selected,
                      selectedColor: const Color(0xFF6366F1),
                      backgroundColor: const Color(0xFF0F172A),
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.white
                            : const Color(0xFFCBD5E1),
                        fontSize: 12.5,
                      ),
                      onSelected: (_) {
                        setState(() => _chatStatusFilter = item.$1);
                        _loadConversations(page: 1);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_isConversationsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              ),
            )
          else if (_conversationsError != null)
            AdminEmptyOrErrorState(
              icon: Icons.error_outline_rounded,
              title: 'Failed to Load Conversations',
              subtitle: _conversationsError!,
              actionLabel: 'Retry',
              onAction: () =>
                  _loadConversations(page: _conversationsCurrentPage),
              isError: true,
            )
          else if (convs.isEmpty)
            AdminEmptyOrErrorState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'No Conversations Found',
              subtitle: 'No conversations match your current filter.',
              actionLabel: 'Show All',
              onAction: () {
                _chatSearchCtrl.clear();
                setState(() => _chatStatusFilter = 'all');
                _loadConversations(page: 1);
              },
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: convs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final c = convs[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: c.isReported
                          ? const Color(0xFFEF4444).withValues(alpha: 0.6)
                          : const Color(0xFF334155),
                    ),
                  ),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Conversation #${c.id}: @${c.user1Username} & @${c.user2Username}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                AdminStatusBadge.forConversationStatus(
                                  c.conversationStatus,
                                ),
                                if (c.isReported)
                                  const AdminStatusBadge(
                                    label: 'Reported Participant',
                                    color: Color(0xFFEF4444),
                                    icon: Icons.flag_rounded,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              c.linkedRequest != null
                                  ? 'Linked Swap Request #${c.linkedRequest!.id}: ${c.linkedRequest!.requestedSkillName} (${c.linkedRequest!.status})'
                                  : 'Legacy Conversation (No accepted swap request linked)',
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Total Messages: ${c.messagesCount} • Last Message: ${formatAdminTimestamp(c.lastMessageAt)}',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                            ),
                            if (c.lastMessage != null &&
                                c.lastMessage!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Preview: "${c.lastMessage}"',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFCBD5E1),
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _openConversationInspector(c.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.manage_search_rounded, size: 18),
                        label: const Text('Inspect & Moderate'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            if (_conversationsPage != null)
              AdminPaginationFooter(
                count: _conversationsPage!.count,
                page: _conversationsPage!.page,
                totalPages: _conversationsPage!.totalPages,
                hasPrevious: _conversationsPage!.hasPrevious,
                hasNext: _conversationsPage!.hasNext,
                onPrevious: () =>
                    _loadConversations(page: _conversationsCurrentPage - 1),
                onNext: () =>
                    _loadConversations(page: _conversationsCurrentPage + 1),
              ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. REPORTS & MODERATION SECTION
  // ---------------------------------------------------------------------------

  Future<void> _openReportModerationModal(AdminUserReportModel report) async {
    final res = await showAdminReportModerationDialog(context, report: report);
    if (res == null) return;
    try {
      await _adminService.resolveReport(
        report.id,
        action: res['action'] as String,
        adminNotes: res['admin_notes'] as String?,
        suspendUser: res['suspend_user'] == true,
      );
      _showSnack('Report #${report.id} updated (${res['action']}).');
      _loadReports(page: _reportsCurrentPage);
      _loadStats();
    } catch (e) {
      _showSnack('Failed to update report: $e', isError: true);
    }
  }

  Widget _buildReportsSection({
    required bool isDesktop,
    required bool isTablet,
  }) {
    final reports = _reportsPage?.results ?? const [];

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageTitleBar(
            title: 'Reports & Moderation',
            subtitle:
                'Review community reports, add administrative notes, resolve/dismiss cases, and suspend offending accounts.',
            onRefresh: () => _loadReports(page: _reportsCurrentPage),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _reportSearchCtrl,
                        style: const TextStyle(color: Colors.white),
                        onSubmitted: (_) => _loadReports(page: 1),
                        decoration: InputDecoration(
                          hintText:
                              'Search reports by reporter, reported user, reason, or description...',
                          hintStyle: const TextStyle(color: Color(0xFF64748B)),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF94A3B8),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => _loadReports(page: 1),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                      child: const Text('Search'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ('all', 'All Reports'),
                    ('pending', 'Pending'),
                    ('under_review', 'Under Review'),
                    ('resolved', 'Resolved'),
                    ('dismissed', 'Dismissed'),
                  ].map((item) {
                    final selected = _reportStatusFilter == item.$1;
                    return ChoiceChip(
                      label: Text(item.$2),
                      selected: selected,
                      selectedColor: const Color(0xFF6366F1),
                      backgroundColor: const Color(0xFF0F172A),
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.white
                            : const Color(0xFFCBD5E1),
                        fontSize: 12.5,
                      ),
                      onSelected: (_) {
                        setState(() => _reportStatusFilter = item.$1);
                        _loadReports(page: 1);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_isReportsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              ),
            )
          else if (_reportsError != null)
            AdminEmptyOrErrorState(
              icon: Icons.error_outline_rounded,
              title: 'Failed to Load Reports',
              subtitle: _reportsError!,
              actionLabel: 'Retry',
              onAction: () => _loadReports(page: _reportsCurrentPage),
              isError: true,
            )
          else if (reports.isEmpty)
            AdminEmptyOrErrorState(
              icon: Icons.verified_user_outlined,
              title: 'No Moderation Reports Found',
              subtitle: 'There are no reports matching the selected filter.',
              actionLabel: 'View All Reports',
              onAction: () {
                _reportSearchCtrl.clear();
                setState(() {
                  _reportStatusFilter = 'all';
                  _reportReasonFilter = 'all';
                });
                _loadReports(page: 1);
              },
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reports.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final rep = reports[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Report #${rep.id}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              AdminStatusBadge.forReportStatus(rep.status),
                              const SizedBox(width: 8),
                              AdminStatusBadge(
                                label: rep.reason.toUpperCase(),
                                color: const Color(0xFFEF4444),
                              ),
                            ],
                          ),
                          Text(
                            formatAdminTimestamp(rep.createdAt),
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          InkWell(
                            onTap: () => _openUserDetailModal(rep.reporterId),
                            child: Text(
                              'Reporter: @${rep.reporterUsername}',
                              style: const TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () =>
                                _openUserDetailModal(rep.reportedUserId),
                            child: Text(
                              'Reported User: @${rep.reportedUsername} (${rep.reportedUserStatus})',
                              style: const TextStyle(
                                color: Color(0xFFFCA5A5),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (rep.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Description: ${rep.description}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      if (rep.adminNotes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Admin Notes: ${rep.adminNotes}',
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _openReportModerationModal(rep),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.gavel_rounded, size: 16),
                            label: const Text('Review & Moderate'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _openUserDetailModal(rep.reportedUserId),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF475569)),
                            ),
                            icon: const Icon(Icons.person_rounded, size: 16),
                            label: const Text('Inspect Reported User'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            if (_reportsPage != null)
              AdminPaginationFooter(
                count: _reportsPage!.count,
                page: _reportsPage!.page,
                totalPages: _reportsPage!.totalPages,
                hasPrevious: _reportsPage!.hasPrevious,
                hasNext: _reportsPage!.hasNext,
                onPrevious: () => _loadReports(page: _reportsCurrentPage - 1),
                onNext: () => _loadReports(page: _reportsCurrentPage + 1),
              ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 7. AUDIT & SECURITY LOGS SECTION
  // ---------------------------------------------------------------------------

  Widget _buildAuditLogsSection({
    required bool isDesktop,
    required bool isTablet,
  }) {
    final logs = _auditLogsPage?.results ?? const [];

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageTitleBar(
            title: 'Audit & Security Logs',
            subtitle:
                'Append-only immutable audit trail of all administrative actions. Sensitive credentials are automatically redacted.',
            onRefresh: () => _loadAuditLogs(page: _auditCurrentPage),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _auditSearchCtrl,
                        style: const TextStyle(color: Colors.white),
                        onSubmitted: (_) => _loadAuditLogs(page: 1),
                        decoration: InputDecoration(
                          hintText:
                              'Search by admin username, action, affected record, or reason...',
                          hintStyle: const TextStyle(color: Color(0xFF64748B)),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF94A3B8),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => _loadAuditLogs(page: 1),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                      child: const Text('Search'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ('all', 'All Records'),
                    ('User', 'User Actions'),
                    ('Skill', 'Skill Catalog'),
                    ('SkillRequest', 'Swap Requests'),
                    ('Conversation', 'Chat Moderation'),
                    ('MessagingPolicy', 'Messaging Policy'),
                    ('UserReport', 'Reports'),
                  ].map((item) {
                    final selected = _auditModelFilter == item.$1;
                    return ChoiceChip(
                      label: Text(item.$2),
                      selected: selected,
                      selectedColor: const Color(0xFF6366F1),
                      backgroundColor: const Color(0xFF0F172A),
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.white
                            : const Color(0xFFCBD5E1),
                        fontSize: 12.5,
                      ),
                      onSelected: (_) {
                        setState(() => _auditModelFilter = item.$1);
                        _loadAuditLogs(page: 1);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_isAuditLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              ),
            )
          else if (_auditError != null)
            AdminEmptyOrErrorState(
              icon: Icons.error_outline_rounded,
              title: 'Failed to Load Audit Logs',
              subtitle: _auditError!,
              actionLabel: 'Retry',
              onAction: () => _loadAuditLogs(page: _auditCurrentPage),
              isError: true,
            )
          else if (logs.isEmpty)
            AdminEmptyOrErrorState(
              icon: Icons.security_rounded,
              title: 'No Audit Log Entries Found',
              subtitle: 'No administrative security events match your filter.',
              actionLabel: 'Reset Filter',
              onAction: () {
                _auditSearchCtrl.clear();
                setState(() => _auditModelFilter = 'all');
                _loadAuditLogs(page: 1);
              },
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final log = logs[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_user_rounded,
                                size: 16,
                                color: Color(0xFFA78BFA),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '#${log.id} • ${log.action}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              AdminStatusBadge(
                                label: log.status.toUpperCase(),
                                color: const Color(0xFF10B981),
                              ),
                            ],
                          ),
                          Text(
                            formatAdminTimestamp(log.createdAt),
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Admin: @${log.adminUsername} • Affected Record: ${log.targetModel} (${log.targetRepr ?? "#${log.targetId ?? ""}"})',
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        log.description,
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 13,
                        ),
                      ),
                      if (log.previousValue != null ||
                          log.newValue != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Changes: ${log.previousValue ?? "{}"} → ${log.newValue ?? "{}"}',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11.5,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            if (_auditLogsPage != null)
              AdminPaginationFooter(
                count: _auditLogsPage!.count,
                page: _auditLogsPage!.page,
                totalPages: _auditLogsPage!.totalPages,
                hasPrevious: _auditLogsPage!.hasPrevious,
                hasNext: _auditLogsPage!.hasNext,
                onPrevious: () =>
                    _loadAuditLogs(page: _auditCurrentPage - 1),
                onNext: () => _loadAuditLogs(page: _auditCurrentPage + 1),
              ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 8. MESSAGING POLICIES SECTION
  // ---------------------------------------------------------------------------

  Future<void> _handleSaveMessagingPolicy() async {
    final maxMin = int.tryParse(_maxPerMinCtrl.text.trim());
    final maxConvDay = int.tryParse(_maxPerConvDayCtrl.text.trim());
    final maxUserDay = int.tryParse(_maxPerUserDayCtrl.text.trim());
    final warnPct = int.tryParse(_warningPercentCtrl.text.trim());
    final cooldown = int.tryParse(_cooldownMinCtrl.text.trim());

    if (maxMin == null ||
        maxConvDay == null ||
        maxUserDay == null ||
        warnPct == null ||
        cooldown == null ||
        maxMin < 1 ||
        maxConvDay < 1 ||
        maxUserDay < 1 ||
        warnPct < 1 ||
        warnPct > 100 ||
        cooldown < 1) {
      _showSnack(
        'Please enter valid positive numbers (warning threshold between 1% and 100%).',
        isError: true,
      );
      return;
    }

    setState(() => _isPolicySaving = true);
    try {
      await _adminService.updateMessagingPolicy(
        maxMessagesPerMinute: maxMin,
        maxMessagesPerConversationPerDay: maxConvDay,
        maxMessagesPerUserPerDay: maxUserDay,
        warningThresholdPercent: warnPct,
        cooldownMinutes: cooldown,
        enforceAcceptedRequest: _enforceAcceptedReq,
        enableRateLimiting: _enableRateLimiting,
        reason: 'Updated via Admin Messaging Policies screen',
      );
      _showSnack('Messaging policy settings saved.');
      await _loadMessagingPolicy();
    } catch (e) {
      _showSnack('Failed to update policy: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isPolicySaving = false);
    }
  }

  void _restoreDefaultPolicyValues() {
    setState(() {
      _maxPerMinCtrl.text = '5';
      _maxPerConvDayCtrl.text = '50';
      _maxPerUserDayCtrl.text = '100';
      _warningPercentCtrl.text = '80';
      _cooldownMinCtrl.text = '15';
      _enforceAcceptedReq = true;
      _enableRateLimiting = true;
    });
  }

  Future<void> _handleReleaseRestriction(
    AdminMessagingRestrictionModel r,
  ) async {
    try {
      await _adminService.releaseMessagingRestriction(
        r.id,
        reason: 'Released by administrator from Messaging Policies screen',
      );
      _showSnack('Released restriction for @${r.username}.');
      _loadMessagingPolicy();
    } catch (e) {
      _showSnack('Failed to release restriction: $e', isError: true);
    }
  }

  Widget _buildMessagingPoliciesSection({
    required bool isDesktop,
    required bool isTablet,
  }) {
    final restrictions = _policyEnvelope?.activeRestrictions ?? const [];

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageTitleBar(
            title: 'Messaging Policies & Rate Limits',
            subtitle:
                'Configure platform-wide messaging quotas, warning thresholds, cooldown durations, and active restrictions.',
            onRefresh: _loadMessagingPolicy,
          ),
          const SizedBox(height: 16),

          if (_isPolicyLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              ),
            )
          else if (_policyError != null)
            AdminEmptyOrErrorState(
              icon: Icons.error_outline_rounded,
              title: 'Failed to Load Messaging Policy',
              subtitle: _policyError!,
              actionLabel: 'Retry',
              onAction: _loadMessagingPolicy,
              isError: true,
            )
          else ...[
            Material(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF334155)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quota & Rate-Limiting Thresholds',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 16,
                      runSpacing: 14,
                      children: [
                        _policyNumberField(
                          controller: _maxPerMinCtrl,
                          label: 'Max Messages / Minute',
                          helper: 'Default: 5 messages/min',
                        ),
                        _policyNumberField(
                          controller: _maxPerConvDayCtrl,
                          label: 'Max Messages / Conversation / Day',
                          helper: 'Default: 50 messages/day',
                        ),
                        _policyNumberField(
                          controller: _maxPerUserDayCtrl,
                          label: 'Max Messages / User / Day',
                          helper: 'Default: 100 messages/day',
                        ),
                        _policyNumberField(
                          controller: _warningPercentCtrl,
                          label: 'Warning Threshold (%)',
                          helper: 'Default: 80%',
                        ),
                        _policyNumberField(
                          controller: _cooldownMinCtrl,
                          label: 'Cooldown Duration (Minutes)',
                          helper: 'Default: 15 minutes',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      value: _enforceAcceptedReq,
                      activeThumbColor: const Color(0xFF10B981),
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Require Accepted Skill-Swap Request for New Chats',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Only participants with an accepted skill-swap request can start new conversations and send messages. Legacy conversations remain read-only unless authorized.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                      onChanged: (v) => setState(() => _enforceAcceptedReq = v),
                    ),
                    SwitchListTile(
                      value: _enableRateLimiting,
                      activeThumbColor: const Color(0xFF10B981),
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Enable Automated Rate Limiting & Temporary Cooldowns',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Applies temporary cooldowns without permanently banning users on automated spam detection.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                      onChanged: (v) => setState(() => _enableRateLimiting = v),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        ElevatedButton.icon(
                          onPressed:
                              _isPolicySaving ? null : _handleSaveMessagingPolicy,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: const Text('Save Policy Settings'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _restoreDefaultPolicyValues,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFCBD5E1),
                            side: const BorderSide(color: Color(0xFF475569)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          icon: const Icon(Icons.restore_rounded, size: 18),
                          label:
                              const Text('Restore Defaults (5/50/100/80%/15m)'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Active Restrictions
            Material(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF334155)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Messaging Cooldowns & Restrictions (${restrictions.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (restrictions.isEmpty)
                      const Text(
                        'No users are currently under an active messaging cooldown or restriction.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      )
                    else
                      ...restrictions.map(
                        (r) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '@${r.username} (${r.restrictionType})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${r.reason} • Expires: ${formatAdminTimestamp(r.expiresAt)}',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                          trailing: OutlinedButton(
                            onPressed: () => _handleReleaseRestriction(r),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF10B981),
                              side: const BorderSide(color: Color(0xFF10B981)),
                            ),
                            child: const Text('Release Cooldown'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _policyNumberField({
    required TextEditingController controller,
    required String label,
    required String helper,
  }) {
    return SizedBox(
      width: 240,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
          helperText: helper,
          helperStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
          filled: true,
          fillColor: const Color(0xFF0F172A),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 9. ADMIN SETTINGS SECTION
  // ---------------------------------------------------------------------------

  Future<void> _handleSaveOwnAdminProfile() async {
    setState(() => _isSavingAdminProfile = true);
    try {
      final updated = await _profileService.updateProfile(
        email: _adminEmailCtrl.text,
        phone: _adminPhoneCtrl.text,
        bio: _adminBioCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _profile = (_profile ?? updated).copyWith(
          email: _adminEmailCtrl.text.trim(),
          phone: _adminPhoneCtrl.text.trim(),
          bio: _adminBioCtrl.text.trim(),
        );
      });
      _showSnack('Administrator profile updated successfully.');
    } catch (e) {
      _showSnack('Failed to update profile: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSavingAdminProfile = false);
    }
  }

  Widget _buildAdminSettingsSection({
    required bool isDesktop,
    required bool isTablet,
  }) {
    final p = _profile;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageTitleBar(
            title: 'Admin Settings & Security Profile',
            subtitle:
                'Manage your administrator account details and inspect authorization privileges.',
            onRefresh: _loadAdminData,
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Authenticated Administrator Eligibility',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    AdminStatusBadge(
                      label: 'Username: @${p?.username ?? "admin"}',
                      color: const Color(0xFF38BDF8),
                      icon: Icons.person_rounded,
                    ),
                    AdminStatusBadge(
                      label: 'Role: ${p?.role ?? "admin"}',
                      color: const Color(0xFF818CF8),
                      icon: Icons.badge_rounded,
                    ),
                    AdminStatusBadge(
                      label: 'is_staff: ${p?.isStaff == true}',
                      color: p?.isStaff == true
                          ? const Color(0xFF10B981)
                          : const Color(0xFF94A3B8),
                    ),
                    AdminStatusBadge(
                      label: 'is_superuser: ${p?.isSuperuser == true}',
                      color: p?.isSuperuser == true
                          ? const Color(0xFF10B981)
                          : const Color(0xFF94A3B8),
                    ),
                    AdminStatusBadge(
                      label: 'Admin Access: Authorized',
                      color: const Color(0xFF10B981),
                      icon: Icons.verified_user_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Color(0xFF334155)),
                const SizedBox(height: 16),
                const Text(
                  'Update Contact Information',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _adminEmailCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Administrator Email',
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _adminPhoneCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _adminBioCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Administrator Bio / Notes',
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isSavingAdminProfile
                          ? null
                          : _handleSaveOwnAdminProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Save Admin Profile'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _handleLogout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Sign Out of Admin Portal'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageTitleBar({
    required String title,
    required String subtitle,
    required VoidCallback onRefresh,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onRefresh,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF475569)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}
