import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/discover_user_model.dart';
import '../../models/skill_model.dart';
import '../../models/user_skill_model.dart';
import '../../services/api_service.dart';
import '../../services/requests_service.dart';
import '../../services/skills_service.dart';
import 'requests_screen.dart';

class SendRequestScreen extends StatefulWidget {
  final DiscoverUserModel targetUser;
  final RequestsService? requestsService;
  final SkillsService? skillsService;
  final ApiService? apiService;

  const SendRequestScreen({
    super.key,
    required this.targetUser,
    this.requestsService,
    this.skillsService,
    this.apiService,
  });

  @override
  State<SendRequestScreen> createState() => _SendRequestScreenState();
}

class _SendRequestScreenState extends State<SendRequestScreen> {
  late final RequestsService _requestsService;
  late final SkillsService _skillsService;

  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _goalController = TextEditingController();

  DiscoveredSkill? _selectedSkillToLearn;
  UserSkillModel? _selectedSkillToOffer;

  List<UserSkillModel> _myTeachingSkills = [];
  bool _isLoadingMySkills = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final api = widget.apiService;
    _requestsService = widget.requestsService ?? RequestsService(apiService: api);
    _skillsService = widget.skillsService ?? SkillsService(apiService: api);

    // Default select first available teaching skill if present
    if (widget.targetUser.skillsTeach.isNotEmpty) {
      _selectedSkillToLearn = widget.targetUser.skillsTeach.first;
    }

    _loadMyTeachingSkills();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _loadMyTeachingSkills() async {
    setState(() {
      _isLoadingMySkills = true;
    });

    try {
      final skills = await _skillsService.getTeachingSkills();
      if (!mounted) return;
      setState(() {
        _myTeachingSkills = skills;
        _isLoadingMySkills = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMySkills = false;
      });
    }
  }

  Future<int?> _resolveRequestedSkillId(DiscoveredSkill skill) async {
    if (skill.id != null && skill.id! > 0) {
      return skill.id;
    }

    try {
      final catalog = await _skillsService.getAvailableSkills();
      final match = catalog.firstWhere(
        (s) => s.name.trim().toLowerCase() == skill.name.trim().toLowerCase(),
        orElse: () => SkillModel(id: -1, name: ''),
      );
      if (match.id > 0) return match.id;
    } catch (_) {}

    return null;
  }

  Future<void> _submitRequest() async {
    setState(() {
      _errorMessage = null;
    });

    if (_selectedSkillToLearn == null) {
      setState(() {
        _errorMessage = 'Please select a skill you want to learn.';
      });
      return;
    }

    if (widget.targetUser.id <= 0) {
      setState(() {
        _errorMessage = 'Invalid target user. Cannot send request.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final requestedSkillId = await _resolveRequestedSkillId(_selectedSkillToLearn!);
      if (requestedSkillId == null || requestedSkillId <= 0) {
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'Unable to identify the selected skill ID. Please try another skill or contact support.';
          _isSubmitting = false;
        });
        return;
      }

      final offeredSkillId = _selectedSkillToOffer?.skillId;

      await _requestsService.sendRequest(
        targetUserId: widget.targetUser.id,
        requestedSkillId: requestedSkillId,
        offeredSkillId: offeredSkillId,
        message: _messageController.text,
        learningGoal: _goalController.text,
      );

      // Trigger automatic refresh of requests lists across the app
      RequestsScreen.triggerRefresh();

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Swap request sent to ${widget.targetUser.username}!'),
          backgroundColor: AppTheme.successColor,
        ),
      );

      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isSubmitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to send request. Please check your network and try again.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = widget.targetUser;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Request Skill Swap'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Target User Profile Card
                _buildTargetUserCard(user, theme),
                const SizedBox(height: 24),

                // Error message banner if any
                if (_errorMessage != null) ...[
                  _buildErrorBanner(_errorMessage!),
                  const SizedBox(height: 20),
                ],

                // Section 1: Choose what to learn (Required)
                _buildSectionHeader(
                  title: '1. Choose what to learn',
                  subtitle: 'Select one skill you want ${user.username} to teach you (required)',
                  icon: Icons.school_rounded,
                  isRequired: true,
                ),
                const SizedBox(height: 12),
                _buildLearnSkillSelection(user),
                const SizedBox(height: 24),

                // Section 2: Choose what to teach in return (Optional)
                _buildSectionHeader(
                  title: '2. Choose what to teach in return',
                  subtitle: 'Select one of your teaching skills to offer (optional)',
                  icon: Icons.swap_horiz_rounded,
                  isRequired: false,
                ),
                const SizedBox(height: 12),
                _buildOfferSkillSelection(),
                const SizedBox(height: 24),

                // Section 3: Request message and goal
                _buildSectionHeader(
                  title: '3. Message & Learning Goal',
                  subtitle: 'Introduce yourself and share what you hope to achieve',
                  icon: Icons.edit_note_rounded,
                  isRequired: false,
                ),
                const SizedBox(height: 14),
                _buildFormFields(),
                const SizedBox(height: 32),

                // Submit Button
                _buildSubmitButton(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTargetUserCard(DiscoverUserModel user, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFDBEAFE),
            backgroundImage: user.fullProfileImageUrl != null
                ? NetworkImage(user.fullProfileImageUrl!)
                : null,
            child: user.fullProfileImageUrl == null
                ? Text(
                    user.initials,
                    style: const TextStyle(
                      fontSize: 20,
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
                Row(
                  children: [
                    Text(
                      user.username,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Target Peer',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isRequired,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 6),
              const Text(
                '*',
                style: TextStyle(
                  color: AppTheme.errorColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLearnSkillSelection(DiscoverUserModel user) {
    if (user.skillsTeach.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppTheme.errorColor, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'This user has not listed any skills to teach yet. You cannot send a swap request.',
                style: TextStyle(
                  color: AppTheme.errorColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: user.skillsTeach.map((skill) {
        final isSelected = _selectedSkillToLearn?.name == skill.name;
        final label = skill.proficiency != null && skill.proficiency!.trim().isNotEmpty
            ? '${skill.name} (${skill.proficiency})'
            : skill.name;

        return ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedSkillToLearn = skill;
              }
            });
          },
          selectedColor: const Color(0xFFDBEAFE),
          labelStyle: TextStyle(
            color: isSelected ? const Color(0xFF1E40AF) : AppTheme.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
          avatar: isSelected
              ? const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.primaryColor,
                  size: 18,
                )
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelected ? AppTheme.primaryColor : AppTheme.borderLight,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          backgroundColor: Colors.white,
        );
      }).toList(),
    );
  }

  Widget _buildOfferSkillSelection() {
    if (_isLoadingMySkills) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'Loading your teaching skills...',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_myTeachingSkills.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppTheme.textSecondary, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'You have not added any skills to teach yet. You can still send a request without offering a skill.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // "None" option
            ChoiceChip(
              label: const Text('None (Learn only)'),
              selected: _selectedSkillToOffer == null,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedSkillToOffer = null;
                  });
                }
              },
              selectedColor: const Color(0xFFE2E8F0),
              labelStyle: TextStyle(
                color: _selectedSkillToOffer == null
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary,
                fontWeight: _selectedSkillToOffer == null ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: _selectedSkillToOffer == null
                      ? AppTheme.textSecondary
                      : AppTheme.borderLight,
                ),
              ),
              backgroundColor: Colors.white,
            ),
            ..._myTeachingSkills.map((userSkill) {
              final isSelected = _selectedSkillToOffer?.id == userSkill.id;
              final label = '${userSkill.skillName} (${userSkill.proficiency})';

              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedSkillToOffer = selected ? userSkill : null;
                  });
                },
                selectedColor: const Color(0xFFCCFBF1),
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFF0F766E) : AppTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
                avatar: isSelected
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.accentColor,
                        size: 18,
                      )
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isSelected ? AppTheme.accentColor : AppTheme.borderLight,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                backgroundColor: Colors.white,
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _messageController,
          maxLines: 3,
          maxLength: 300,
          decoration: InputDecoration(
            labelText: 'Message (optional)',
            hintText: 'Introduce yourself or describe what you hope to learn...',
            hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            alignLabelWithHint: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _goalController,
          maxLines: 2,
          maxLength: 200,
          decoration: InputDecoration(
            labelText: 'Learning Goal (optional)',
            hintText: 'e.g. Build my portfolio app, pass certification...',
            hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            alignLabelWithHint: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.errorColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.errorColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final canSubmit =
        _selectedSkillToLearn != null && widget.targetUser.skillsTeach.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: (_isSubmitting || !canSubmit) ? null : _submitRequest,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send_rounded),
        label: Text(_isSubmitting ? 'Sending Request...' : 'Send Swap Request'),
      ),
    );
  }
}
