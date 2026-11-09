import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/skill_request_model.dart';

void main() {
  group('SkillRequestModel Tests', () {
    test('fromJson parses complete request data correctly', () {
      final json = {
        'id': 10,
        'requester': 1,
        'requester_name': 'alice',
        'target': 2,
        'target_name': 'bob',
        'requested_skill': 101,
        'requested_skill_name': 'Flutter',
        'offered_skill': 102,
        'offered_skill_name': 'Django',
        'message': 'Would love to exchange skills!',
        'learning_goal': 'Build cross-platform applications',
        'status': 'pending',
        'created_at': '2026-10-21T10:00:00Z',
        'updated_at': '2026-10-21T10:05:00Z',
      };

      final model = SkillRequestModel.fromJson(json);

      expect(model.id, equals(10));
      expect(model.requester, equals(1));
      expect(model.requesterName, equals('alice'));
      expect(model.target, equals(2));
      expect(model.targetName, equals('bob'));
      expect(model.requestedSkill, equals(101));
      expect(model.requestedSkillName, equals('Flutter'));
      expect(model.offeredSkill, equals(102));
      expect(model.offeredSkillName, equals('Django'));
      expect(model.message, equals('Would love to exchange skills!'));
      expect(model.learningGoal, equals('Build cross-platform applications'));
      expect(model.status, equals('pending'));
      expect(model.isPending, isTrue);
      expect(model.isAccepted, isFalse);
      expect(model.isRejected, isFalse);
      expect(model.createdAt, isNotNull);
      expect(model.updatedAt, isNotNull);
    });

    test('fromJson handles null and missing optional fields safely', () {
      final json = {
        'id': 20,
        'requester': 3,
        'target': 4,
        'requested_skill': 205,
        'status': 'accepted',
      };

      final model = SkillRequestModel.fromJson(json);

      expect(model.id, equals(20));
      expect(model.requesterName, equals(''));
      expect(model.targetName, equals(''));
      expect(model.requestedSkillName, equals(''));
      expect(model.offeredSkill, isNull);
      expect(model.offeredSkillName, isNull);
      expect(model.message, isNull);
      expect(model.learningGoal, isNull);
      expect(model.status, equals('accepted'));
      expect(model.isPending, isFalse);
      expect(model.isAccepted, isTrue);
      expect(model.createdAt, isNull);
    });

    test('toJson produces expected structure', () {
      final model = SkillRequestModel(
        id: 5,
        requester: 1,
        requesterName: 'alice',
        target: 2,
        targetName: 'bob',
        requestedSkill: 10,
        requestedSkillName: 'Dart',
        offeredSkill: 12,
        offeredSkillName: 'Python',
        message: 'Hello!',
        learningGoal: 'Master Dart',
        status: 'pending',
      );

      final json = model.toJson();
      expect(json['id'], equals(5));
      expect(json['requester'], equals(1));
      expect(json['requester_name'], equals('alice'));
      expect(json['target'], equals(2));
      expect(json['target_name'], equals('bob'));
      expect(json['requested_skill'], equals(10));
      expect(json['requested_skill_name'], equals('Dart'));
      expect(json['offered_skill'], equals(12));
      expect(json['offered_skill_name'], equals('Python'));
      expect(json['message'], equals('Hello!'));
      expect(json['learning_goal'], equals('Master Dart'));
      expect(json['status'], equals('pending'));
    });

    test('copyWith updates specified fields only', () {
      final model = SkillRequestModel(
        id: 1,
        requester: 1,
        requesterName: 'alice',
        target: 2,
        targetName: 'bob',
        requestedSkill: 10,
        requestedSkillName: 'Dart',
        status: 'pending',
      );

      final updated = model.copyWith(status: 'rejected');
      expect(updated.id, equals(1));
      expect(updated.requesterName, equals('alice'));
      expect(updated.status, equals('rejected'));
      expect(updated.isRejected, isTrue);
      expect(updated.isPending, isFalse);
    });
  });

  group('SkillRequestsResponse Tests', () {
    test('fromJson correctly parses sent and received lists', () {
      final data = {
        'sent': [
          {
            'id': 1,
            'requester': 1,
            'requester_name': 'alice',
            'target': 2,
            'target_name': 'bob',
            'requested_skill': 101,
            'requested_skill_name': 'Flutter',
            'status': 'pending',
          },
        ],
        'received': [
          {
            'id': 2,
            'requester': 3,
            'requester_name': 'charlie',
            'target': 1,
            'target_name': 'alice',
            'requested_skill': 102,
            'requested_skill_name': 'Python',
            'status': 'accepted',
          },
        ],
      };

      final response = SkillRequestsResponse.fromJson(data);

      expect(response.sent.length, equals(1));
      expect(response.sent.first.id, equals(1));
      expect(response.sent.first.targetName, equals('bob'));

      expect(response.received.length, equals(1));
      expect(response.received.first.id, equals(2));
      expect(response.received.first.requesterName, equals('charlie'));
    });

    test('fromJson handles non-map and empty responses gracefully', () {
      final response1 = SkillRequestsResponse.fromJson(null);
      expect(response1.sent, isEmpty);
      expect(response1.received, isEmpty);

      final response2 = SkillRequestsResponse.fromJson({});
      expect(response2.sent, isEmpty);
      expect(response2.received, isEmpty);
    });
  });
}
