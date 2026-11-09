import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/discover_user_model.dart';

void main() {
  group('DiscoverUserModel Tests', () {
    test('fromJson parses user with string skill lists and image', () {
      final json = {
        'id': 1,
        'username': 'jane_doe',
        'bio': 'Passionate about languages and coding.',
        'profile_image': 'http://127.0.0.1:8000/media/profiles/jane.jpg',
        'skills_teach': ['Python', 'Django'],
        'skills_learn': ['Flutter', 'Spanish'],
      };

      final user = DiscoverUserModel.fromJson(json);

      expect(user.id, equals(1));
      expect(user.username, equals('jane_doe'));
      expect(user.bio, equals('Passionate about languages and coding.'));
      expect(
        user.profileImage,
        equals('http://127.0.0.1:8000/media/profiles/jane.jpg'),
      );
      expect(user.skillsTeach.length, equals(2));
      expect(user.skillsTeach[0].name, equals('Python'));
      expect(user.skillsTeach[1].name, equals('Django'));
      expect(user.skillsLearn.length, equals(2));
      expect(user.skillsLearn[0].name, equals('Flutter'));
      expect(user.skillsLearn[1].name, equals('Spanish'));
      expect(user.initials, equals('J'));
      expect(
        user.fullProfileImageUrl,
        equals('http://127.0.0.1:8000/media/profiles/jane.jpg'),
      );
    });

    test('fromJson parses user with object skill lists and relative image', () {
      final json = {
        'id': 2,
        'username': 'bob',
        'bio': 'Web developer',
        'profile_image': '/media/profiles/bob.png',
        'skills_teach': [
          {'id': 10, 'name': 'Dart', 'proficiency': 'Advanced'},
        ],
        'skills_learn': [
          {'id': 20, 'skill_name': 'Rust', 'level': 'Beginner'},
        ],
      };

      final user = DiscoverUserModel.fromJson(json);

      expect(user.id, equals(2));
      expect(user.username, equals('bob'));
      expect(user.skillsTeach.first.name, equals('Dart'));
      expect(user.skillsTeach.first.proficiency, equals('Advanced'));
      expect(user.skillsLearn.first.name, equals('Rust'));
      expect(user.skillsLearn.first.proficiency, equals('Beginner'));
      expect(user.fullProfileImageUrl, contains('/media/profiles/bob.png'));
    });

    test('fromJson handles null and missing fields gracefully', () {
      final json = <String, dynamic>{};

      final user = DiscoverUserModel.fromJson(json);

      expect(user.id, equals(0));
      expect(user.username, equals('User'));
      expect(user.bio, isEmpty);
      expect(user.profileImage, isNull);
      expect(user.skillsTeach, isEmpty);
      expect(user.skillsLearn, isEmpty);
      expect(user.fullProfileImageUrl, isNull);
      expect(user.initials, equals('U'));
    });
  });
}
