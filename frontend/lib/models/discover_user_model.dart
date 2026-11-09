import '../core/constants/app_constants.dart';

class DiscoveredSkill {
  final int? id;
  final String name;
  final String? proficiency;
  final String? category;

  const DiscoveredSkill({
    this.id,
    required this.name,
    this.proficiency,
    this.category,
  });

  factory DiscoveredSkill.fromDynamic(dynamic raw) {
    if (raw == null) {
      return const DiscoveredSkill(name: '');
    }

    if (raw is String) {
      return DiscoveredSkill(name: raw.trim());
    }

    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      String name = '';
      if (map['name'] != null && map['name'].toString().trim().isNotEmpty) {
        name = map['name'].toString().trim();
      } else if (map['skill_name'] != null && map['skill_name'].toString().trim().isNotEmpty) {
        name = map['skill_name'].toString().trim();
      } else if (map['title'] != null && map['title'].toString().trim().isNotEmpty) {
        name = map['title'].toString().trim();
      } else if (map['skill'] != null) {
        if (map['skill'] is Map) {
          final skillMap = Map<String, dynamic>.from(map['skill'] as Map);
          name = skillMap['name']?.toString().trim() ??
              skillMap['title']?.toString().trim() ??
              '';
        } else {
          name = map['skill'].toString().trim();
        }
      }

      int? sId;
      if (map['id'] is int) {
        sId = map['id'];
      } else if (map['skill_id'] is int) {
        sId = map['skill_id'];
      } else if (map['id'] != null) {
        sId = int.tryParse(map['id'].toString());
      }

      final prof = map['proficiency']?.toString() ?? map['level']?.toString();
      final cat = map['category_name']?.toString() ??
          (map['category'] is Map ? map['category']['name']?.toString() : map['category']?.toString());

      return DiscoveredSkill(
        id: sId,
        name: name.isNotEmpty ? name : 'Skill',
        proficiency: prof,
        category: cat,
      );
    }

    return DiscoveredSkill(name: raw.toString().trim());
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      if (proficiency != null) 'proficiency': proficiency,
      if (category != null) 'category': category,
    };
  }
}

class DiscoverUserModel {
  final int id;
  final String username;
  final String bio;
  final String? profileImage;
  final List<DiscoveredSkill> skillsTeach;
  final List<DiscoveredSkill> skillsLearn;

  const DiscoverUserModel({
    required this.id,
    required this.username,
    required this.bio,
    this.profileImage,
    required this.skillsTeach,
    required this.skillsLearn,
  });

  factory DiscoverUserModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] is int
        ? json['id'] as int
        : int.tryParse(json['id']?.toString() ?? '') ?? 0;

    final rawUsername = json['username']?.toString() ??
        (json['user'] is Map ? json['user']['username']?.toString() : null) ??
        'User';

    final rawBio = json['bio']?.toString() ??
        (json['profile'] is Map ? json['profile']['bio']?.toString() : null) ??
        '';

    final rawProfileImage = json['profile_image']?.toString() ??
        json['image']?.toString() ??
        json['avatar']?.toString() ??
        (json['profile'] is Map ? json['profile']['profile_image']?.toString() : null);

    final rawTeach = json['skills_teach'] ??
        json['teaching_skills'] ??
        json['skills_to_teach'];

    final rawLearn = json['skills_learn'] ??
        json['learning_skills'] ??
        json['skills_to_learn'];

    return DiscoverUserModel(
      id: rawId,
      username: rawUsername,
      bio: rawBio,
      profileImage: (rawProfileImage != null &&
              rawProfileImage.isNotEmpty &&
              rawProfileImage != 'null')
          ? rawProfileImage
          : null,
      skillsTeach: _parseSkillList(rawTeach),
      skillsLearn: _parseSkillList(rawLearn),
    );
  }

  static List<DiscoveredSkill> _parseSkillList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw
          .map((item) => DiscoveredSkill.fromDynamic(item))
          .where((s) => s.name.trim().isNotEmpty)
          .toList();
    }
    return const [];
  }

  String get initials {
    if (username.trim().isNotEmpty) {
      return username.trim()[0].toUpperCase();
    }
    return 'U';
  }

  String? get fullProfileImageUrl {
    if (profileImage == null || profileImage!.trim().isEmpty) return null;
    final img = profileImage!.trim();
    if (img.startsWith('http://') || img.startsWith('https://')) return img;
    if (img.startsWith('/')) return '${AppConstants.baseUrl}$img';
    return '${AppConstants.baseUrl}/$img';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'bio': bio,
      if (profileImage != null) 'profile_image': profileImage,
      'skills_teach': skillsTeach.map((s) => s.toJson()).toList(),
      'skills_learn': skillsLearn.map((s) => s.toJson()).toList(),
    };
  }
}
