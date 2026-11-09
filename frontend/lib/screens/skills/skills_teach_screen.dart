import 'package:flutter/material.dart';
import '../../models/skill_model.dart';
import '../../models/user_skill_model.dart';
import '../../services/skills_service.dart';
import '../../services/api_service.dart';
import '../../widgets/primary_button.dart';

class SkillsTeachScreen extends StatefulWidget {
  const SkillsTeachScreen({super.key});

  @override
  State<SkillsTeachScreen> createState() => _SkillsTeachScreenState();
}

class _SkillsTeachScreenState extends State<SkillsTeachScreen> {
  final SkillsService _skillsService = SkillsService();

  List<UserSkillModel> _teachingSkills = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTeachingSkills();
  }

  Future<void> _loadTeachingSkills() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final skills = await _skillsService.getTeachingSkills();
      setState(() {
        _teachingSkills = skills;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to load skills. Please check your connection.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRemoveSkill(UserSkillModel skill) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Skill'),
        content: Text('Are you sure you want to remove "${skill.skillName}" from your teaching skills?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _skillsService.removeSkill(
        userSkillId: skill.id,
        skillType: 'teach',
      );

      setState(() {
        _teachingSkills.removeWhere((s) => s.id == skill.id);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed "${skill.skillName}"')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove skill: ${e.toString()}'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _showAddSkillModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddSkillBottomSheet(
        skillType: 'teach',
        skillsService: _skillsService,
        onSkillAdded: (newSkill) {
          setState(() {
            _teachingSkills.add(newSkill);
          });
          _loadTeachingSkills();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Skills I Can Teach'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadTeachingSkills,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSkillModal,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Skill'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTeachingSkills,
          child: _buildBody(theme),
        ),
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
              'Loading teaching skills...',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 60, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              const Text(
                'Failed to Load Skills',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadTeachingSkills,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_teachingSkills.isEmpty) {
      return Center(
        child: Padding(
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
                  Icons.school_rounded,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Teaching Skills Added',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Share your expertise with fellow students by adding skills you can teach.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _showAddSkillModal,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Your First Skill'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20.0),
      itemCount: _teachingSkills.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final skill = _teachingSkills[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skill.skillName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              skill.categoryName,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              skill.proficiency,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove skill',
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                  onPressed: () => _handleRemoveSkill(skill),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AddSkillBottomSheet extends StatefulWidget {
  final String skillType; // 'teach' or 'learn'
  final SkillsService skillsService;
  final Function(UserSkillModel) onSkillAdded;

  const _AddSkillBottomSheet({
    required this.skillType,
    required this.skillsService,
    required this.onSkillAdded,
  });

  @override
  State<_AddSkillBottomSheet> createState() => _AddSkillBottomSheetState();
}

class _AddSkillBottomSheetState extends State<_AddSkillBottomSheet> {
  List<SkillModel> _availableSkills = [];
  SkillModel? _selectedSkill;
  String _selectedProficiency = 'Intermediate';
  bool _isLoadingSkills = true;
  bool _isSubmitting = false;
  String? _modalError;

  final List<String> _proficiencies = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'Expert',
  ];

  @override
  void initState() {
    super.initState();
    _loadAvailableSkills();
  }

  Future<void> _loadAvailableSkills() async {
    try {
      final skills = await widget.skillsService.getAvailableSkills();
      setState(() {
        _availableSkills = skills;
        if (skills.isNotEmpty) {
          _selectedSkill = skills.first;
        }
        _isLoadingSkills = false;
      });
    } catch (e) {
      setState(() {
        _availableSkills = [];
        _modalError = 'Failed to load available skills list: ${e.toString()}';
        _isLoadingSkills = false;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (_selectedSkill == null) return;

    setState(() {
      _isSubmitting = true;
      _modalError = null;
    });

    try {
      UserSkillModel addedSkill;
      if (widget.skillType == 'teach') {
        addedSkill = await widget.skillsService.addTeachingSkill(
          skillId: _selectedSkill!.id,
          proficiency: _selectedProficiency,
        );
      } else {
        addedSkill = await widget.skillsService.addLearningSkill(
          skillId: _selectedSkill!.id,
          proficiency: _selectedProficiency,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSkillAdded(addedSkill);
    } on ApiException catch (e) {
      setState(() {
        _modalError = e.message;
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() {
        _modalError = 'Failed to add skill. Please try again.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.skillType == 'teach' ? 'Add Teaching Skill' : 'Add Learning Skill';

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_modalError != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text(
                _modalError!,
                style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
              ),
            ),
            const SizedBox(height: 14),
          ],

          if (_isLoadingSkills)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            // Select Skill Dropdown
            const Text(
              'Select Skill',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<SkillModel>(
              initialValue: _selectedSkill,
              isExpanded: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.psychology_outlined, color: Color(0xFF64748B), size: 20),
              ),
              items: _availableSkills.map((skill) {
                return DropdownMenuItem(
                  value: skill,
                  child: Text(
                    '${skill.name} (${skill.categoryName})',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _isSubmitting
                  ? null
                  : (val) {
                      if (val != null) {
                        setState(() {
                          _selectedSkill = val;
                        });
                      }
                    },
            ),
            const SizedBox(height: 18),

            // Select Proficiency Dropdown
            const Text(
              'Proficiency Level',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedProficiency,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.equalizer_rounded, color: Color(0xFF64748B), size: 20),
              ),
              items: _proficiencies.map((level) {
                return DropdownMenuItem(
                  value: level,
                  child: Text(level),
                );
              }).toList(),
              onChanged: _isSubmitting
                  ? null
                  : (val) {
                      if (val != null) {
                        setState(() {
                          _selectedProficiency = val;
                        });
                      }
                    },
            ),
            const SizedBox(height: 24),

            PrimaryButton(
              text: 'Add Skill',
              onPressed: (_isSubmitting || _selectedSkill == null) ? null : _handleSubmit,
              isLoading: _isSubmitting,
            ),
          ],
        ],
      ),
    ),
  );
}
}
