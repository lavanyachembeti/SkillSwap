import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/user_profile_model.dart';

void main() {
  group('UserProfileModel Tests', () {
    test('fromJson parses flat DRF response correctly', () {
      final json = {
        'id': 1,
        'username': 'alice',
        'email': 'alice@example.com',
        'phone': '+1234567890',
        'bio': 'Software engineer and Flutter enthusiast.',
        'role': 'professional',
      };

      final profile = UserProfileModel.fromJson(json);

      expect(profile.id, equals(1));
      expect(profile.username, equals('alice'));
      expect(profile.email, equals('alice@example.com'));
      expect(profile.phone, equals('+1234567890'));
      expect(profile.bio, equals('Software engineer and Flutter enthusiast.'));
      expect(profile.role, equals('professional'));
    });

    test('fromJson handles nested user object in DRF response', () {
      final json = {
        'id': 2,
        'user': {'id': 2, 'username': 'bob_smith', 'email': 'bob@example.com'},
        'phone': '9876543210',
        'bio': 'Learning mobile app development',
        'role': 'student',
      };

      final profile = UserProfileModel.fromJson(json);

      expect(profile.id, equals(2));
      expect(profile.username, equals('bob_smith'));
      expect(profile.email, equals('bob@example.com'));
      expect(profile.phone, equals('9876543210'));
      expect(profile.bio, equals('Learning mobile app development'));
      expect(profile.role, equals('student'));
    });

    test('fromJson falls back gracefully for missing fields', () {
      final json = <String, dynamic>{};

      final profile = UserProfileModel.fromJson(json);

      expect(profile.id, isNull);
      expect(profile.username, isEmpty);
      expect(profile.email, isEmpty);
      expect(profile.phone, isEmpty);
      expect(profile.bio, isEmpty);
      expect(profile.role, isEmpty);
    });

    test('fromJson parses phone_number key if phone is absent', () {
      final json = {
        'username': 'charlie',
        'email': 'charlie@test.com',
        'phone_number': '555-0199',
        'bio': 'Designer',
        'role': 'student',
      };

      final profile = UserProfileModel.fromJson(json);
      expect(profile.phone, equals('555-0199'));
    });

    test('copyWith creates modified clone correctly', () {
      final original = UserProfileModel(
        id: 5,
        username: 'user1',
        email: 'user1@example.com',
        phone: '111',
        bio: 'Old bio',
        role: 'student',
      );

      final updated = original.copyWith(bio: 'Updated bio', phone: '222');

      expect(updated.id, equals(5));
      expect(updated.username, equals('user1'));
      expect(updated.email, equals('user1@example.com'));
      expect(updated.phone, equals('222'));
      expect(updated.bio, equals('Updated bio'));
      expect(updated.role, equals('student'));
    });

    test('toJson and toUpdatePayload produce correct maps', () {
      final profile = UserProfileModel(
        id: 10,
        username: 'dave',
        email: 'dave@example.com',
        phone: '123',
        bio: 'Hello world',
        role: 'professional',
      );

      final updatePayload = profile.toUpdatePayload();
      expect(
        updatePayload,
        equals({
          'email': 'dave@example.com',
          'phone': '123',
          'bio': 'Hello world',
        }),
      );

      final fullJson = profile.toJson();
      expect(fullJson['id'], equals(10));
      expect(fullJson['username'], equals('dave'));
      expect(fullJson['role'], equals('professional'));
    });

    test('isAdministrator returns true for admin role, isStaff, isSuperuser, or isAdmin', () {
      final adminRole = UserProfileModel(
        username: 'admin1',
        email: 'admin1@test.com',
        phone: '',
        bio: '',
        role: 'admin',
      );
      expect(adminRole.isAdministrator, isTrue);

      final staffUser = UserProfileModel(
        username: 'staff1',
        email: 'staff1@test.com',
        phone: '',
        bio: '',
        role: 'student',
        isStaff: true,
      );
      expect(staffUser.isAdministrator, isTrue);

      final superUser = UserProfileModel(
        username: 'lavanya',
        email: 'lavanya@test.com',
        phone: '',
        bio: '',
        role: 'student',
        isSuperuser: true,
      );
      expect(superUser.isAdministrator, isTrue);

      final adminFlagUser = UserProfileModel(
        username: 'flag1',
        email: 'flag1@test.com',
        phone: '',
        bio: '',
        role: 'professional',
        isAdmin: true,
      );
      expect(adminFlagUser.isAdministrator, isTrue);

      final normalStudent = UserProfileModel(
        username: 'student1',
        email: 'student1@test.com',
        phone: '',
        bio: '',
        role: 'student',
      );
      expect(normalStudent.isAdministrator, isFalse);

      final normalProfessional = UserProfileModel(
        username: 'pro1',
        email: 'pro1@test.com',
        phone: '',
        bio: '',
        role: 'professional',
      );
      expect(normalProfessional.isAdministrator, isFalse);
    });
  });
}
