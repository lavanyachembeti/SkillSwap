import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/discover_user_model.dart';
import '../../services/api_service.dart';
import '../../services/requests_service.dart';
import '../../services/skills_service.dart';
import '../requests/send_request_screen.dart';

class DiscoverScreen extends StatefulWidget {
  final ApiService? apiService;
  final RequestsService? requestsService;
  final SkillsService? skillsService;

  const DiscoverScreen({
    super.key,
    this.apiService,
    this.requestsService,
    this.skillsService,
  });

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  late final ApiService _apiService;

  List<DiscoverUserModel> _users = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.get(AppConstants.discoveryUsersEndpoint);
      final users = _parseUsersResponse(response.data);
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load discovered users. Please check your connection.';
        _isLoading = false;
      });
    }
  }

  List<DiscoverUserModel> _parseUsersResponse(dynamic data) {
    List items = [];
    if (data is List) {
      items = data;
    } else if (data is Map) {
      if (data['results'] is List) {
        items = data['results'];
      } else if (data['data'] is List) {
        items = data['data'];
      } else if (data['users'] is List) {
        items = data['users'];
      }
    }

    return items
        .whereType<Map>()
        .map((item) => DiscoverUserModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Discover Skills'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _fetchUsers,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchUsers,
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Discovering peers & skills...',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: AppTheme.errorColor,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Failed to Load Users',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchUsers,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.people_outline_rounded,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Peers Found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'There are currently no active users available for skill swapping.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchUsers,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      itemCount: _users.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final user = _users[index];
        return _buildUserCard(user, theme);
      },
    );
  }

  Future<void> _openRequestForm(DiscoverUserModel user) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SendRequestScreen(
          targetUser: user,
          apiService: _apiService,
          requestsService: widget.requestsService,
          skillsService: widget.skillsService,
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Swap request sent to ${user.username}!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  Widget _buildUserCard(DiscoverUserModel user, ThemeData theme) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openRequestForm(user),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Header Row (Avatar, Username, Bio)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFFDBEAFE),
                    backgroundImage: user.fullProfileImageUrl != null
                        ? NetworkImage(user.fullProfileImageUrl!)
                        : null,
                    onBackgroundImageError: user.fullProfileImageUrl != null
                        ? (_, _) {}
                        : null,
                    child: user.fullProfileImageUrl == null
                        ? Text(
                            user.initials,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.username,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (user.bio.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            user.bio.trim(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                              height: 1.35,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppTheme.borderLight),
              const SizedBox(height: 14),

              // Skills to Teach Section
              _buildSkillsSection(
                title: 'Can Teach',
                icon: Icons.school_rounded,
                iconColor: AppTheme.primaryColor,
                badgeBgColor: const Color(0xFFDBEAFE),
                badgeTextColor: const Color(0xFF1E40AF),
                skills: user.skillsTeach,
                emptyText: 'No teaching skills listed',
              ),

              const SizedBox(height: 12),

              // Skills to Learn Section
              _buildSkillsSection(
                title: 'Wants to Learn',
                icon: Icons.menu_book_rounded,
                iconColor: AppTheme.accentColor,
                badgeBgColor: const Color(0xFFCCFBF1),
                badgeTextColor: const Color(0xFF0F766E),
                skills: user.skillsLearn,
                emptyText: 'No learning skills listed',
              ),

              const SizedBox(height: 16),

              // Action button to open request form
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openRequestForm(user),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Request Skill Swap'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkillsSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color badgeBgColor,
    required Color badgeTextColor,
    required List<DiscoveredSkill> skills,
    required String emptyText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: iconColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (skills.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: skills.map((skill) {
              final label = skill.proficiency != null && skill.proficiency!.trim().isNotEmpty
                  ? '${skill.name} • ${skill.proficiency}'
                  : skill.name;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: badgeTextColor,
                  ),
                ),
              );
            }).toList(),
          )
        else
          Text(
            emptyText,
            style: const TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppTheme.textMuted,
            ),
          ),
      ],
    );
  }
}
