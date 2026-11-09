class ConversationModel {
  final int id;
  final int user1;
  final String user1Name;
  final int user2;
  final String user2Name;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ConversationModel({
    required this.id,
    required this.user1,
    required this.user1Name,
    required this.user2,
    required this.user2Name,
    this.createdAt,
    this.updatedAt,
  });

  /// Helper to get the other participant's username
  String getPartnerName([String? currentUsername, int? currentUserId]) {
    if (currentUserId != null) {
      if (user1 == currentUserId) return user2Name;
      if (user2 == currentUserId) return user1Name;
    }
    if (currentUsername != null && currentUsername.trim().isNotEmpty) {
      final cur = currentUsername.trim().toLowerCase();
      if (user1Name.trim().toLowerCase() == cur) {
        return user2Name;
      }
      if (user2Name.trim().toLowerCase() == cur) {
        return user1Name;
      }
    }
    return user2Name.isNotEmpty ? user2Name : user1Name;
  }

  /// Helper to get the other participant's user ID
  int getPartnerId(int currentUserId) {
    if (user1 == currentUserId) {
      return user2;
    }
    return user1;
  }

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val, [int fallback = 0]) {
      if (val is int) return val;
      if (val is String) return int.tryParse(val) ?? fallback;
      return fallback;
    }

    DateTime? parseDate(dynamic val) {
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val);
      }
      return null;
    }

    return ConversationModel(
      id: parseInt(json['id']),
      user1: parseInt(json['user1']),
      user1Name: (json['user1_name'] ?? '').toString(),
      user2: parseInt(json['user2']),
      user2Name: (json['user2_name'] ?? '').toString(),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user1': user1,
      'user1_name': user1Name,
      'user2': user2,
      'user2_name': user2Name,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  ConversationModel copyWith({
    int? id,
    int? user1,
    String? user1Name,
    int? user2,
    String? user2Name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      user1: user1 ?? this.user1,
      user1Name: user1Name ?? this.user1Name,
      user2: user2 ?? this.user2,
      user2Name: user2Name ?? this.user2Name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
