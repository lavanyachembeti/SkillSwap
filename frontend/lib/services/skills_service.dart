import '../core/constants/app_constants.dart';
import '../models/skill_model.dart';
import '../models/user_skill_model.dart';
import 'api_service.dart';

class SkillsService {
  final ApiService _apiService;

  SkillsService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Fetch all user skills from GET /api/skills/my-skills/
  Future<List<UserSkillModel>> getMySkills() async {
    try {
      final response = await _apiService.get(AppConstants.mySkillsEndpoint);
      final userSkills = _parseUserSkillList(response.data);

      // Match returned skill ID with the master catalog from GET /api/skills/ to populate category
      try {
        final catalog = await getAvailableSkills();
        if (catalog.isNotEmpty) {
          final catalogMap = {for (var s in catalog) s.id: s.categoryName};
          return userSkills.map((us) {
            if (catalogMap.containsKey(us.skillId)) {
              return us.copyWith(categoryName: catalogMap[us.skillId]);
            }
            return us;
          }).toList();
        }
      } catch (_) {
        // Ignore catalog match failure, return userSkills as parsed
      }

      return userSkills;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to load user skills: $e');
    }
  }

  /// Alias for backward compatibility
  Future<List<UserSkillModel>> getUserSkillsProfile() => getMySkills();

  /// Fetch user's teaching skills (filtered locally where skill_type == "teach")
  Future<List<UserSkillModel>> getTeachingSkills() async {
    final allUserSkills = await getMySkills();
    return allUserSkills
        .where((s) => s.skillType.toLowerCase() == 'teach')
        .toList();
  }

  /// Fetch user's learning skills (filtered locally where skill_type == "learn")
  Future<List<UserSkillModel>> getLearningSkills() async {
    final allUserSkills = await getMySkills();
    return allUserSkills
        .where((s) => s.skillType.toLowerCase() == 'learn')
        .toList();
  }

  /// Fetch available master skills list from GET /api/skills/
  Future<List<SkillModel>> getAvailableSkills() async {
    try {
      final response = await _apiService.get(AppConstants.skillsEndpoint);
      return _parseSkillList(response.data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to load available skills list: $e');
    }
  }

  /// Add a teaching skill via POST /api/skills/my-skills/
  Future<UserSkillModel> addTeachingSkill({
    required int skillId,
    required String proficiency,
  }) async {
    return _addUserSkill(
      skillId: skillId,
      skillType: 'teach',
      proficiency: proficiency,
    );
  }

  /// Add a learning skill via POST /api/skills/my-skills/
  Future<UserSkillModel> addLearningSkill({
    required int skillId,
    required String proficiency,
  }) async {
    return _addUserSkill(
      skillId: skillId,
      skillType: 'learn',
      proficiency: proficiency,
    );
  }

  /// Internal helper to post new user skill to POST /api/skills/my-skills/
  Future<UserSkillModel> _addUserSkill({
    required int skillId,
    required String skillType,
    required String proficiency,
  }) async {
    final payload = {
      'skill': skillId,
      'skill_type': skillType,
      'proficiency': proficiency.toLowerCase(),
    };

    try {
      final response = await _apiService.post(
        AppConstants.mySkillsEndpoint,
        data: payload,
      );
      final addedSkill = UserSkillModel.fromJson(
        response.data is Map<String, dynamic> ? response.data : {'id': skillId, 'skill': skillId},
        defaultType: skillType,
      );
      return addedSkill;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to add skill: $e');
    }
  }

  /// Remove a user skill entry via DELETE /api/skills/my-skills/{id}/
  Future<void> removeSkill({
    required int userSkillId,
    String? skillType,
  }) async {
    final endpoint = '${AppConstants.mySkillsEndpoint}$userSkillId/';
    try {
      await _apiService.delete(endpoint);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to remove skill: $e');
    }
  }

  /// Parse response list for master skills
  List<SkillModel> _parseSkillList(dynamic data) {
    List items = [];
    if (data is List) {
      items = data;
    } else if (data is Map && data.containsKey('results') && data['results'] is List) {
      items = data['results'];
    }

    return items
        .map((item) => SkillModel.fromJson(item is Map<String, dynamic> ? item : {}))
        .toList();
  }

  /// Parse response list for user skills
  List<UserSkillModel> _parseUserSkillList(dynamic data) {
    List items = [];
    if (data is List) {
      items = data;
    } else if (data is Map && data.containsKey('results') && data['results'] is List) {
      items = data['results'];
    } else if (data is Map && data.containsKey('skills') && data['skills'] is List) {
      items = data['skills'];
    }

    return items
        .map((item) => UserSkillModel.fromJson(
              item is Map<String, dynamic> ? item : {},
            ))
        .toList();
  }
}
