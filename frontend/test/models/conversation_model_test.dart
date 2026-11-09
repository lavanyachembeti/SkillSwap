import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/conversation_model.dart';

void main() {
  group('ConversationModel Tests', () {
    test('fromJson parses complete conversation correctly', () {
      final json = {
        'id': 1,
        'user1': 1,
        'user1_name': 'rahul',
        'user2': 2,
        'user2_name': 'priya',
        'created_at': '2026-10-21T10:00:00Z',
        'updated_at': '2026-10-21T10:30:00Z',
      };

      final model = ConversationModel.fromJson(json);

      expect(model.id, equals(1));
      expect(model.user1, equals(1));
      expect(model.user1Name, equals('rahul'));
      expect(model.user2, equals(2));
      expect(model.user2Name, equals('priya'));
      expect(model.createdAt, isNotNull);
      expect(model.updatedAt, isNotNull);

      // Partner resolution by username
      expect(model.getPartnerName('rahul'), equals('priya'));
      expect(model.getPartnerName('priya'), equals('rahul'));

      // Partner resolution by ID
      expect(model.getPartnerId(1), equals(2));
      expect(model.getPartnerId(2), equals(1));
    });

    test('getPartnerName handles case insensitivity', () {
      final json = {
        'id': 2,
        'user1': 1,
        'user1_name': 'Rahul',
        'user2': 3,
        'user2_name': 'Lavanya',
      };

      final model = ConversationModel.fromJson(json);

      expect(model.getPartnerName('rahul'), equals('Lavanya'));
      expect(model.getPartnerName('LAVANYA'), equals('Rahul'));
    });

    test('toJson serializes conversation accurately', () {
      final model = ConversationModel(
        id: 5,
        user1: 1,
        user1Name: 'user1',
        user2: 2,
        user2Name: 'user2',
      );

      final json = model.toJson();
      expect(json['id'], equals(5));
      expect(json['user1'], equals(1));
      expect(json['user1_name'], equals('user1'));
      expect(json['user2'], equals(2));
      expect(json['user2_name'], equals('user2'));
    });

    test('copyWith creates updated clone correctly', () {
      final model = ConversationModel(
        id: 1,
        user1: 1,
        user1Name: 'user1',
        user2: 2,
        user2Name: 'user2',
      );

      final updated = model.copyWith(user2Name: 'new_partner');
      expect(updated.id, equals(1));
      expect(updated.user2Name, equals('new_partner'));
      expect(updated.user1Name, equals('user1'));
    });
  });
}
