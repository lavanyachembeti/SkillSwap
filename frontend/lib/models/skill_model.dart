class SkillModel {
  final int id;
  final String name;
  final String categoryName;
  final int? categoryId;

  SkillModel({
    required this.id,
    required this.name,
    this.categoryName = 'General',
    this.categoryId,
  });

  factory SkillModel.fromJson(Map<String, dynamic> json) {
    String categoryStr = 'General';
    int? catId;

    if (json['category'] != null) {
      if (json['category'] is Map) {
        categoryStr = json['category']['name'] ??
            json['category']['title'] ??
            'General';
        catId = json['category']['id'] is int
            ? json['category']['id']
            : int.tryParse(json['category']['id']?.toString() ?? '');
      } else if (json['category'] is String) {
        categoryStr = json['category'];
      } else if (json['category'] is int) {
        catId = json['category'];
      }
    }

    if (json['category_name'] is String && (json['category_name'] as String).isNotEmpty) {
      categoryStr = json['category_name'];
    }

    return SkillModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name'] ?? json['title'] ?? 'Unnamed Skill',
      categoryName: categoryStr,
      categoryId: catId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category_name': categoryName,
      if (categoryId != null) 'category_id': categoryId,
    };
  }
}
