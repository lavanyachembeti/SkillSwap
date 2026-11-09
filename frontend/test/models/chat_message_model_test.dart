import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/chat_message_model.dart';

void main() {
  group('ChatMessageModel Tests', () {
    test('fromJson parses chat message correctly', () {
      final json = {
        'id': 42,
        'conversation': 7,
        'sender': 1,
        'sender_name': 'rahul',
        'message': 'Hello there, let us swap skills!',
        'created_at': '2026-10-21T14:35:00Z',
        'is_read': true,
      };

      final msg = ChatMessageModel.fromJson(json);

      expect(msg.id, equals(42));
      expect(msg.conversationId, equals(7));
      expect(msg.senderId, equals(1));
      expect(msg.senderName, equals('rahul'));
      expect(msg.message, equals('Hello there, let us swap skills!'));
      expect(msg.isRead, isTrue);
      expect(msg.isSentById(1), isTrue);
      expect(msg.isSentById(2), isFalse);
      expect(msg.isSentBy('rahul'), isTrue);
      expect(msg.isSentBy('priya'), isFalse);
      expect(msg.formattedTime, isNotEmpty);
    });

    test('toJson serializes chat message correctly', () {
      final msg = ChatMessageModel(
        id: 10,
        conversationId: 3,
        senderId: 2,
        senderName: 'priya',
        message: 'Looking forward to it',
        isRead: false,
      );

      final json = msg.toJson();
      expect(json['id'], equals(10));
      expect(json['conversation'], equals(3));
      expect(json['sender'], equals(2));
      expect(json['sender_name'], equals('priya'));
      expect(json['message'], equals('Looking forward to it'));
      expect(json['is_read'], isFalse);
    });

    test('handles fallback timestamp and missing values', () {
      final msg = ChatMessageModel.fromJson({
        'id': 1,
        'conversation': 1,
        'sender': 1,
        'sender_name': '',
        'message': 'test',
      });

      expect(msg.formattedTime, isEmpty);
      expect(msg.isRead, isFalse);
      expect(msg.isSentBy(''), isFalse);
    });
  });
}
