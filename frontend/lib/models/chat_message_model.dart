class ChatMessageModel {
  final int id;
  final int conversationId;
  final int senderId;
  final String senderName;
  final String message;
  final bool isRead;
  final DateTime? createdAt;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.message,
    this.isRead = false,
    this.createdAt,
  });

  /// Check whether this message was sent by the given username
  bool isSentBy(String currentUsername) {
    if (currentUsername.isEmpty) return false;
    return senderName.trim().toLowerCase() ==
        currentUsername.trim().toLowerCase();
  }

  /// Check whether this message was sent by the given user ID
  bool isSentById(int currentUserId) {
    return senderId == currentUserId;
  }

  /// Formatted time string (e.g. "10:30 AM")
  String get formattedTime {
    if (createdAt == null) return '';
    final local = createdAt!.toLocal();
    final hour = local.hour > 12
        ? local.hour - 12
        : (local.hour == 0 ? 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
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

    return ChatMessageModel(
      id: parseInt(json['id']),
      conversationId: parseInt(json['conversation']),
      senderId: parseInt(json['sender']),
      senderName: (json['sender_name'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      isRead: json['is_read'] == true,
      createdAt: parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation': conversationId,
      'sender': senderId,
      'sender_name': senderName,
      'message': message,
      'is_read': isRead,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
