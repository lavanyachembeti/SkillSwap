import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/admin_service.dart';
import 'admin_portal_widgets.dart';

/// Prompt admin for suspension reason and optional duration in days.
Future<Map<String, dynamic>?> showAdminSuspendUserDialog(
  BuildContext context, {
  required String username,
}) async {
  final reasonController = TextEditingController();
  final daysController = TextEditingController();
  String? errorText;

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF334155)),
            ),
            title: Row(
              children: [
                const Icon(Icons.block_rounded, color: Color(0xFFEF4444)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Suspend @$username',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Suspending an account immediately revokes active access and records an audit log entry.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Suspension Reason (Required)',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        hintText: 'Explain the policy violation or reason...',
                        hintStyle: const TextStyle(color: Color(0xFF64748B)),
                        errorText: errorText,
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: daysController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Duration in Days (Optional)',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        hintText: 'Leave blank for indefinite suspension',
                        hintStyle: const TextStyle(color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final reason = reasonController.text.trim();
                  if (reason.isEmpty) {
                    setModalState(() {
                      errorText = 'Please provide a reason for suspension.';
                    });
                    return;
                  }
                  final days = int.tryParse(daysController.text.trim());
                  Navigator.of(ctx).pop({
                    'reason': reason,
                    'duration_days': days,
                  });
                },
                icon: const Icon(Icons.gavel_rounded, size: 16),
                label: const Text('Confirm Suspension'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Complete User Detail Modal Dialog showing profile, teaching/learning skills,
/// sent/received requests, account activity, and admin actions.
Future<bool?> showAdminUserDetailDialog(
  BuildContext context, {
  required int userId,
  required AdminService adminService,
  AdminUserModel? initialUser,
}) async {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _AdminUserDetailDialog(
      userId: userId,
      adminService: adminService,
      initialUser: initialUser,
    ),
  );
}

class _AdminUserDetailDialog extends StatefulWidget {
  final int userId;
  final AdminService adminService;
  final AdminUserModel? initialUser;

  const _AdminUserDetailDialog({
    required this.userId,
    required this.adminService,
    this.initialUser,
  });

  @override
  State<_AdminUserDetailDialog> createState() => _AdminUserDetailDialogState();
}

class _AdminUserDetailDialogState extends State<_AdminUserDetailDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AdminUserModel? _user;
  bool _isLoading = true;
  bool _isMutating = false;
  String? _error;
  bool _didChange = false;

  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _bioCtrl;
  String _selectedRole = 'student';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _user = widget.initialUser;
    _firstNameCtrl = TextEditingController(text: _user?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: _user?.lastName ?? '');
    _emailCtrl = TextEditingController(text: _user?.email ?? '');
    _phoneCtrl = TextEditingController(text: _user?.phone ?? '');
    _bioCtrl = TextEditingController(text: _user?.bio ?? '');
    _selectedRole = _user?.role ?? 'student';
    _fetchDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final detail = await widget.adminService.getUserDetail(widget.userId);
      if (!mounted) return;
      setState(() {
        _user = detail;
        _firstNameCtrl.text = detail.firstName;
        _lastNameCtrl.text = detail.lastName;
        _emailCtrl.text = detail.email;
        _phoneCtrl.text = detail.phone;
        _bioCtrl.text = detail.bio;
        _selectedRole =
            ['student', 'professional', 'admin'].contains(detail.role)
                ? detail.role
                : 'student';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleVerifyToggle() async {
    if (_user == null) return;
    setState(() => _isMutating = true);
    try {
      final targetState = !_user!.isVerified;
      await widget.adminService.verifyUser(
        _user!.id,
        isVerified: targetState,
        reason: targetState
            ? 'Verified via Admin User Details modal'
            : 'Verification revoked via Admin User Details modal',
      );
      _didChange = true;
      await _fetchDetail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              targetState
                  ? 'Account verified successfully.'
                  : 'Verification revoked.',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _handleSuspendOrReactivate() async {
    if (_user == null) return;
    if (_user!.isSuspended || !_user!.isActive) {
      setState(() => _isMutating = true);
      try {
        await widget.adminService.updateUserStatus(
          _user!.id,
          action: 'reactivate',
          reason: 'Reactivated by administrator',
        );
        _didChange = true;
        await _fetchDetail();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account reactivated.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reactivate: $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isMutating = false);
      }
    } else {
      final res = await showAdminSuspendUserDialog(
        context,
        username: _user!.username,
      );
      if (res == null) return;
      setState(() => _isMutating = true);
      try {
        await widget.adminService.updateUserStatus(
          _user!.id,
          action: 'suspend',
          reason: res['reason'] as String,
          durationDays: res['duration_days'] as int?,
        );
        _didChange = true;
        await _fetchDetail();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account suspended.'),
              backgroundColor: Color(0xFFF59E0B),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to suspend: $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isMutating = false);
      }
    }
  }

  Future<void> _handleSaveProfile() async {
    if (_user == null) return;
    setState(() => _isMutating = true);
    try {
      await widget.adminService.updateUser(
        _user!.id,
        firstName: _firstNameCtrl.text,
        lastName: _lastNameCtrl.text,
        email: _emailCtrl.text,
        phone: _phoneCtrl.text,
        bio: _bioCtrl.text,
        role: _selectedRole,
        reason: 'Admin updated user profile details',
      );
      _didChange = true;
      await _fetchDetail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User details saved.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final user = _user;

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenWidth < 600 ? 12 : 32,
        vertical: 20,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 780,
          maxHeight: screenHeight * 0.88,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF334155))),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF6366F1),
                    child: Text(
                      (user?.username.isNotEmpty == true
                              ? user!.username[0]
                              : 'U')
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              user != null
                                  ? '${user.fullName} (@${user.username})'
                                  : 'User #${widget.userId}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (user != null)
                              AdminStatusBadge.forAccountStatus(
                                user.accountStatus,
                              ),
                            if (user != null)
                              AdminStatusBadge(
                                label: user.isVerified
                                    ? 'Verified'
                                    : 'Unverified',
                                color: user.isVerified
                                    ? const Color(0xFF38BDF8)
                                    : const Color(0xFFF59E0B),
                                icon: user.isVerified
                                    ? Icons.verified_rounded
                                    : Icons.gpp_maybe_rounded,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user != null
                              ? 'ID: #${user.id} • Role: ${user.displayRole} • Email: ${user.email}'
                              : 'Loading user details...',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(_didChange),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              color: const Color(0xFF0F172A),
              child: TabBar(
                controller: _tabController,
                isScrollable: screenWidth < 600,
                indicatorColor: const Color(0xFF6366F1),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF94A3B8),
                tabs: [
                  const Tab(text: 'Profile & Actions'),
                  Tab(
                    text:
                        'Skills (${(user?.skillsTeaching.length ?? 0) + (user?.skillsLearning.length ?? 0)})',
                  ),
                  Tab(
                    text:
                        'Requests (${(user?.sentRequestsCount ?? 0) + (user?.receivedRequestsCount ?? 0)})',
                  ),
                  Tab(text: 'Activity (${user?.accountActivity.length ?? 0})'),
                ],
              ),
            ),

            // Body
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6366F1),
                      ),
                    )
                  : _error != null
                  ? AdminEmptyOrErrorState(
                      icon: Icons.error_outline_rounded,
                      title: 'Failed to Load User Details',
                      subtitle: _error!,
                      actionLabel: 'Retry',
                      onAction: _fetchDetail,
                      isError: true,
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildProfileTab(user!),
                        _buildSkillsTab(user),
                        _buildRequestsTab(user),
                        _buildActivityTab(user),
                      ],
                    ),
            ),

            // Bottom Action Bar
            if (user != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  border: Border(top: BorderSide(color: Color(0xFF334155))),
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isMutating ? null : _handleVerifyToggle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: user.isVerified
                                ? const Color(0xFF475569)
                                : const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                          ),
                          icon: Icon(
                            user.isVerified
                                ? Icons.unpublished_rounded
                                : Icons.verified_user_rounded,
                            size: 16,
                          ),
                          label: Text(
                            user.isVerified
                                ? 'Revoke Verification'
                                : 'Verify Account',
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed:
                              _isMutating ? null : _handleSuspendOrReactivate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                (user.isSuspended || !user.isActive)
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                          ),
                          icon: Icon(
                            (user.isSuspended || !user.isActive)
                                ? Icons.restore_rounded
                                : Icons.block_rounded,
                            size: 16,
                          ),
                          label: Text(
                            (user.isSuspended || !user.isActive)
                                ? 'Reactivate Account'
                                : 'Suspend Account',
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(_didChange),
                      child: const Text(
                        'Close',
                        style: TextStyle(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab(AdminUserModel user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user.isSuspended &&
              user.suspensionReason != null &&
              user.suspensionReason!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account Suspended',
                    style: TextStyle(
                      color: Color(0xFFFCA5A5),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reason: ${user.suspensionReason}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  if (user.suspendedUntil != null)
                    Text(
                      'Suspended Until: ${formatAdminTimestamp(user.suspendedUntil)}',
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Metadata Grid
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _metaItem('Date Joined', formatAdminTimestamp(user.dateJoined)),
              _metaItem('Last Login', formatAdminTimestamp(user.lastLogin)),
              _metaItem(
                'Last Activity',
                formatAdminTimestamp(user.lastActivity),
              ),
              _metaItem('Conversations', '${user.conversationsCount}'),
              _metaItem('Reports Received', '${user.reportsReceivedCount}'),
              _metaItem(
                'Privileges',
                user.isSuperuser
                    ? 'Superuser & Staff'
                    : (user.isStaff ? 'Staff' : 'Standard'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF334155)),
          const SizedBox(height: 12),
          const Text(
            'Edit Profile Information',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _darkTextField(
                  controller: _firstNameCtrl,
                  label: 'First Name',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _darkTextField(
                  controller: _lastNameCtrl,
                  label: 'Last Name',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _darkTextField(controller: _emailCtrl, label: 'Email'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _darkTextField(controller: _phoneCtrl, label: 'Phone'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedRole,
            dropdownColor: const Color(0xFF0F172A),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'User Role',
              labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'student', child: Text('Student')),
              DropdownMenuItem(
                value: 'professional',
                child: Text('Professional'),
              ),
              DropdownMenuItem(value: 'admin', child: Text('Administrator')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedRole = val);
            },
          ),
          const SizedBox(height: 12),
          _darkTextField(controller: _bioCtrl, label: 'Bio', maxLines: 3),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isMutating ? null : _handleSaveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsTab(AdminUserModel user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Teaching Skills (${user.skillsTeaching.length})',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (user.skillsTeaching.isEmpty)
            const Text(
              'No teaching skills registered.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: user.skillsTeaching
                  .map(
                    (s) => Chip(
                      backgroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      label: Text(
                        '${s.name} • ${s.category} (${s.proficiency})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 24),
          Text(
            'Learning Skills (${user.skillsLearning.length})',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (user.skillsLearning.isEmpty)
            const Text(
              'No learning skills registered.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: user.skillsLearning
                  .map(
                    (s) => Chip(
                      backgroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFF38BDF8)),
                      label: Text(
                        '${s.name} • ${s.category} (${s.proficiency})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildRequestsTab(AdminUserModel user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sent Requests (${user.sentRequestsCount})',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (user.sentRequests.isEmpty)
            const Text(
              'No sent requests.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            )
          else
            ...user.sentRequests.map(
              (r) => _requestTile(
                label: 'To @${r.peerUsername}',
                req: r,
              ),
            ),
          const SizedBox(height: 20),
          Text(
            'Received Requests (${user.receivedRequestsCount})',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (user.receivedRequests.isEmpty)
            const Text(
              'No received requests.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            )
          else
            ...user.receivedRequests.map(
              (r) => _requestTile(
                label: 'From @${r.peerUsername}',
                req: r,
              ),
            ),
        ],
      ),
    );
  }

  Widget _requestTile({required String label, required AdminUserRequestItem req}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#$req.id • $label — ${req.requestedSkillName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (req.offeredSkillName != null)
                  Text(
                    'Offered: ${req.offeredSkillName}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                Text(
                  formatAdminTimestamp(req.createdAt),
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          AdminStatusBadge.forRequestStatus(req.status),
        ],
      ),
    );
  }

  Widget _buildActivityTab(AdminUserModel user) {
    if (user.accountActivity.isEmpty) {
      return const Center(
        child: Text(
          'No administrative actions recorded for this account yet.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: user.accountActivity.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final log = user.accountActivity[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    log.action,
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    formatAdminTimestamp(log.createdAt),
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'By @${log.adminUsername} • ${log.reason.isEmpty ? "No reason specified" : log.reason}',
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metaItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _darkTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

/// Add or Edit a Catalog Skill Dialog.
Future<Map<String, dynamic>?> showAdminSkillFormDialog(
  BuildContext context, {
  AdminSkillModel? existingSkill,
}) async {
  final nameCtrl = TextEditingController(text: existingSkill?.name ?? '');
  final categoryCtrl = TextEditingController(
    text: existingSkill?.category ?? 'Technology',
  );
  final descCtrl = TextEditingController(
    text: existingSkill?.description ?? '',
  );
  bool isActive = existingSkill?.isActive ?? true;
  String? errorText;

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF334155)),
            ),
            title: Text(
              existingSkill == null
                  ? 'Add New Skill to Catalog'
                  : 'Edit Skill: ${existingSkill.name}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Skill Name *',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        errorText: errorText,
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Category',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        hintText: 'e.g., Technology, Design, Language, Music',
                        hintStyle: const TextStyle(color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Description',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: isActive,
                      activeThumbColor: const Color(0xFF10B981),
                      title: const Text(
                        'Active in Skill Catalog',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Inactive skills are hidden from new user selections while preserving existing user references.',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                      onChanged: (v) => setModalState(() => isActive = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 40),
                ),
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) {
                    setModalState(() => errorText = 'Skill name is required.');
                    return;
                  }
                  Navigator.of(ctx).pop({
                    'name': nameCtrl.text.trim(),
                    'category': categoryCtrl.text.trim().isEmpty
                        ? 'General'
                        : categoryCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'is_active': isActive,
                  });
                },
                icon: const Icon(Icons.check_rounded, size: 16),
                label: Text(existingSkill == null ? 'Create Skill' : 'Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// View Users Teaching and Learning a Skill.
Future<void> showAdminSkillUsersDialog(
  BuildContext context, {
  required AdminSkillModel skill,
  required ValueChanged<int> onInspectUser,
}) async {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: Row(
          children: [
            const Icon(Icons.school_rounded, color: Color(0xFF38BDF8)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${skill.name} — Associated Users',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Category: ${skill.category} • Requests referencing skill: ${skill.requestsCount}',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Users Teaching (${skill.teachingUsers.length})',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                if (skill.teachingUsers.isEmpty)
                  const Text(
                    'No users currently teaching this skill.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  )
                else
                  ...skill.teachingUsers.map(
                    (u) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${u.fullName} (@${u.username})',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        '${u.email} • Role: ${u.role} • Proficiency: ${u.proficiency}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onInspectUser(u.userId);
                        },
                        child: const Text('Inspect User'),
                      ),
                    ),
                  ),
                const Divider(color: Color(0xFF334155), height: 24),
                Text(
                  'Users Learning (${skill.learningUsers.length})',
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                if (skill.learningUsers.isEmpty)
                  const Text(
                    'No users currently learning this skill.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  )
                else
                  ...skill.learningUsers.map(
                    (u) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${u.fullName} (@${u.username})',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        '${u.email} • Role: ${u.role} • Proficiency: ${u.proficiency}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onInspectUser(u.userId);
                        },
                        child: const Text('Inspect User'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

/// Conversation Transcript & Moderation Dialog.
Future<bool?> showAdminConversationModerationDialog(
  BuildContext context, {
  required int conversationId,
  required AdminService adminService,
}) async {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _AdminConversationModerationDialog(
      conversationId: conversationId,
      adminService: adminService,
    ),
  );
}

class _AdminConversationModerationDialog extends StatefulWidget {
  final int conversationId;
  final AdminService adminService;

  const _AdminConversationModerationDialog({
    required this.conversationId,
    required this.adminService,
  });

  @override
  State<_AdminConversationModerationDialog> createState() =>
      _AdminConversationModerationDialogState();
}

class _AdminConversationModerationDialogState
    extends State<_AdminConversationModerationDialog> {
  AdminConversationDetailModel? _detail;
  bool _isLoading = true;
  bool _isMutating = false;
  String? _error;
  bool _didChange = false;

  @override
  void initState() {
    super.initState();
    _loadTranscript();
  }

  Future<void> _loadTranscript() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await widget.adminService.getConversationMessages(
        widget.conversationId,
      );
      if (!mounted) return;
      setState(() {
        _detail = res;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _performModerationAction(String action) async {
    setState(() => _isMutating = true);
    try {
      await widget.adminService.updateConversationStatus(
        widget.conversationId,
        action: action,
        reason: 'Admin moderation action: $action',
      );
      _didChange = true;
      await _loadTranscript();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversation updated ($action).'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update conversation: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      title: Row(
        children: [
          const Icon(Icons.forum_rounded, color: Color(0xFF38BDF8)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              d != null
                  ? 'Conversation #${d.conversationId}: @${d.user1} & @${d.user2}'
                  : 'Conversation #${widget.conversationId}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (d != null)
            AdminStatusBadge.forConversationStatus(d.conversationStatus),
        ],
      ),
      content: SizedBox(
        width: 640,
        height: 440,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              )
            : _error != null
            ? AdminEmptyOrErrorState(
                icon: Icons.error_outline_rounded,
                title: 'Unable to Load Messages',
                subtitle: _error!,
                actionLabel: 'Retry',
                onAction: _loadTranscript,
                isError: true,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            d!.linkedRequest != null
                                ? 'Linked Swap Request #${d.linkedRequest!.id}: ${d.linkedRequest!.requestedSkillName} (${d.linkedRequest!.status})'
                                : 'Legacy Conversation (No Accepted Skill-Swap Request Linked)',
                            style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: d.messages.isEmpty
                        ? const Center(
                            child: Text(
                              'No messages in this conversation.',
                              style: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          )
                        : ListView.separated(
                            itemCount: d.messages.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final m = d.messages[i];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '@${m.senderUsername}',
                                          style: const TextStyle(
                                            color: Color(0xFF38BDF8),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          formatAdminTimestamp(m.createdAt),
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      m.message,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
      actions: [
        if (d != null && !d.hasAcceptedRequest)
          OutlinedButton.icon(
            onPressed: _isMutating
                ? null
                : () => _performModerationAction(
                    d.adminAuthorized ? 'revoke_legacy' : 'authorize_legacy',
                  ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF38BDF8),
              side: const BorderSide(color: Color(0xFF38BDF8)),
              minimumSize: const Size(0, 40),
            ),
            icon: Icon(
              d.adminAuthorized
                  ? Icons.lock_clock_rounded
                  : Icons.check_circle_outline_rounded,
              size: 16,
            ),
            label: Text(
              d.adminAuthorized
                  ? 'Set Read-Only (Revoke Legacy Auth)'
                  : 'Authorize Legacy Messaging',
            ),
          ),
        if (d != null)
          ElevatedButton.icon(
            onPressed: _isMutating
                ? null
                : () => _performModerationAction(
                    d.isLocked ? 'unlock' : 'lock',
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: d.isLocked
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
            ),
            icon: Icon(
              d.isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
              size: 16,
            ),
            label: Text(
              d.isLocked ? 'Unlock Conversation' : 'Lock Conversation',
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_didChange),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Report Moderation Dialog (Under Review, Resolve, Dismiss, Add Notes, Suspend User).
Future<Map<String, dynamic>?> showAdminReportModerationDialog(
  BuildContext context, {
  required AdminUserReportModel report,
}) async {
  final notesCtrl = TextEditingController(text: report.adminNotes);
  bool suspendReportedUser = false;

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF334155)),
            ),
            title: Row(
              children: [
                const Icon(Icons.flag_rounded, color: Color(0xFFF59E0B)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Report #${report.id} — @${report.reportedUsername}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                AdminStatusBadge.forReportStatus(report.status),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 500,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Reporter: @${report.reporterUsername} (${report.reporterEmail})',
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reported User: @${report.reportedUsername} (${report.reportedUserEmail}) • Account: ${report.reportedUserStatus}',
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reason: ${report.reason.toUpperCase()} • Submitted: ${formatAdminTimestamp(report.createdAt)}',
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Text(
                        report.description.isEmpty
                            ? 'No additional description provided by reporter.'
                            : report.description,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Administrative Notes',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        hintText:
                            'Document findings, evidence, and moderation decision...',
                        hintStyle: const TextStyle(color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      value: suspendReportedUser,
                      activeColor: const Color(0xFFEF4444),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Also suspend @${report.reportedUsername} immediately',
                        style: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Suspends the reported user account and revokes active tokens.',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                      onChanged: (v) =>
                          setModalState(() => suspendReportedUser = v == true),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(ctx).pop({
                    'action': 'under_review',
                    'admin_notes': notesCtrl.text.trim(),
                    'suspend_user': suspendReportedUser,
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF38BDF8),
                  side: const BorderSide(color: Color(0xFF38BDF8)),
                  minimumSize: const Size(0, 40),
                ),
                child: const Text('Mark Under Review'),
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(ctx).pop({
                    'action': 'dismiss',
                    'admin_notes': notesCtrl.text.trim(),
                    'suspend_user': false,
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF94A3B8),
                  side: const BorderSide(color: Color(0xFF475569)),
                  minimumSize: const Size(0, 40),
                ),
                child: const Text('Dismiss'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 40),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop({
                    'action': 'resolve',
                    'admin_notes': notesCtrl.text.trim(),
                    'suspend_user': suspendReportedUser,
                  });
                },
                icon: const Icon(Icons.task_alt_rounded, size: 16),
                label: const Text('Resolve Report'),
              ),
            ],
          );
        },
      );
    },
  );
}
