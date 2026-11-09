class SkillRequestModel {
  final int id;
  final int requester;
  final String requesterName;
  final int target;
  final String targetName;
  final int requestedSkill;
  final String requestedSkillName;
  final int? offeredSkill;
  final String? offeredSkillName;
  final String? message;
  final String? learningGoal;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SkillRequestModel({
    required this.id,
    required this.requester,
    required this.requesterName,
    required this.target,
    required this.targetName,
    required this.requestedSkill,
    required this.requestedSkillName,
    this.offeredSkill,
    this.offeredSkillName,
    this.message,
    this.learningGoal,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isAccepted => status.toLowerCase() == 'accepted';
  bool get isRejected => status.toLowerCase() == 'rejected';
  bool get isCancelled => status.toLowerCase() == 'cancelled';

  factory SkillRequestModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val, [int fallback = 0]) {
      if (val is int) return val;
      if (val is String) return int.tryParse(val) ?? fallback;
      return fallback;
    }

    int? parseNullableInt(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      if (val is String) return int.tryParse(val);
      return null;
    }

    DateTime? parseDate(dynamic val) {
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val);
      }
      return null;
    }

    return SkillRequestModel(
      id: parseInt(json['id']),
      requester: parseInt(json['requester']),
      requesterName: (json['requester_name'] ?? json['requester_username'] ?? '').toString(),
      target: parseInt(json['target']),
      targetName: (json['target_name'] ?? json['target_username'] ?? '').toString(),
      requestedSkill: parseInt(json['requested_skill']),
      requestedSkillName: (json['requested_skill_name'] ?? json['skill_name'] ?? '').toString(),
      offeredSkill: parseNullableInt(json['offered_skill']),
      offeredSkillName: json['offered_skill_name']?.toString(),
      message: json['message']?.toString(),
      learningGoal: json['learning_goal']?.toString(),
      status: (json['status'] ?? 'pending').toString(),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  SkillRequestModel copyWith({
    int? id,
    int? requester,
    String? requesterName,
    int? target,
    String? targetName,
    int? requestedSkill,
    String? requestedSkillName,
    int? offeredSkill,
    String? offeredSkillName,
    String? message,
    String? learningGoal,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SkillRequestModel(
      id: id ?? this.id,
      requester: requester ?? this.requester,
      requesterName: requesterName ?? this.requesterName,
      target: target ?? this.target,
      targetName: targetName ?? this.targetName,
      requestedSkill: requestedSkill ?? this.requestedSkill,
      requestedSkillName: requestedSkillName ?? this.requestedSkillName,
      offeredSkill: offeredSkill ?? this.offeredSkill,
      offeredSkillName: offeredSkillName ?? this.offeredSkillName,
      message: message ?? this.message,
      learningGoal: learningGoal ?? this.learningGoal,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'requester': requester,
      'requester_name': requesterName,
      'target': target,
      'target_name': targetName,
      'requested_skill': requestedSkill,
      'requested_skill_name': requestedSkillName,
      'status': status,
    };
    if (offeredSkill != null) map['offered_skill'] = offeredSkill;
    if (offeredSkillName != null) map['offered_skill_name'] = offeredSkillName;
    if (message != null) map['message'] = message;
    if (learningGoal != null) map['learning_goal'] = learningGoal;
    if (createdAt != null) map['created_at'] = createdAt!.toIso8601String();
    if (updatedAt != null) map['updated_at'] = updatedAt!.toIso8601String();
    return map;
  }
}

class SkillRequestsResponse {
  final List<SkillRequestModel> sent;
  final List<SkillRequestModel> received;

  SkillRequestsResponse({
    required this.sent,
    required this.received,
  });

  factory SkillRequestsResponse.fromJson(dynamic data) {
    if (data is Map<String, dynamic> || data is Map) {
      final map = Map<String, dynamic>.from(data as Map);
      final sentRaw = map['sent'] is List ? map['sent'] as List : [];
      final receivedRaw = map['received'] is List ? map['received'] as List : [];

      return SkillRequestsResponse(
        sent: sentRaw
            .whereType<Map>()
            .map((item) => SkillRequestModel.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
        received: receivedRaw
            .whereType<Map>()
            .map((item) => SkillRequestModel.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
    }

    return SkillRequestsResponse(sent: [], received: []);
  }
}
