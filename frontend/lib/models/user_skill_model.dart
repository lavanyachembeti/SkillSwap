class UserSkillModel {
  final int id;
  final int skillId;
  final String skillName;
  final String categoryName;
  final String proficiency;
  final String skillType;

  UserSkillModel({
    required this.id,
    required this.skillId,
    required this.skillName,
    required this.categoryName,
    required this.proficiency,
    required this.skillType,
  });

  factory UserSkillModel.fromJson(Map<String, dynamic> json, {String defaultType = 'teach'}) {
    int sId = 0;
    String sName = '';
    String cName = 'General';

    if (json['skill'] != null) {
      if (json['skill'] is Map) {
        final map = json['skill'] as Map<String, dynamic>;
        sId = map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? '') ?? 0;
        sName = map['name'] ?? map['title'] ?? '';

        if (map['category'] != null) {
          if (map['category'] is Map) {
            cName = map['category']['name'] ?? map['category']['title'] ?? 'General';
          } else if (map['category'] is String) {
            cName = map['category'];
          }
        }
        if (map['category_name'] is String && (map['category_name'] as String).isNotEmpty) {
          cName = map['category_name'];
        }
      } else if (json['skill'] is int) {
        sId = json['skill'];
      } else if (json['skill'] is String) {
        sName = json['skill'];
      }
    }

    if (sName.isEmpty) {
      sName = json['skill_name'] ?? json['name'] ?? json['title'] ?? 'Skill';
    }
    if (cName == 'General' && json['category_name'] is String) {
      cName = json['category_name'];
    }

    final entryId = json['id'] is int
        ? json['id']
        : int.tryParse(json['id']?.toString() ?? '') ?? sId;

    final rawProficiency = json['proficiency'] ?? json['level'] ?? 'Intermediate';
    final normalizedProficiency = rawProficiency.toString().substring(0, 1).toUpperCase() +
        rawProficiency.toString().substring(1).toLowerCase();

    return UserSkillModel(
      id: entryId,
      skillId: sId != 0 ? sId : entryId,
      skillName: sName,
      categoryName: cName,
      proficiency: normalizedProficiency,
      skillType: json['skill_type'] ?? json['type'] ?? defaultType,
    );
  }

  UserSkillModel copyWith({
    int? id,
    int? skillId,
    String? skillName,
    String? categoryName,
    String? proficiency,
    String? skillType,
  }) {
    return UserSkillModel(
      id: id ?? this.id,
      skillId: skillId ?? this.skillId,
      skillName: skillName ?? this.skillName,
      categoryName: categoryName ?? this.categoryName,
      proficiency: proficiency ?? this.proficiency,
      skillType: skillType ?? this.skillType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'skill_id': skillId,
      'skill_name': skillName,
      'category_name': categoryName,
      'proficiency': proficiency.toLowerCase(),
      'skill_type': skillType,
    };
  }
}
