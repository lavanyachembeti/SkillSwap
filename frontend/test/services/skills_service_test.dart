import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/skills_service.dart';

class MockApiService extends ApiService {
  final Map<String, dynamic> getResponses;
  final Map<String, dynamic> postResponses;
  final List<String> deleteCalls = [];
  final List<Map<String, dynamic>> postCalls = [];

  MockApiService({required this.getResponses, required this.postResponses});

  @override
  Future<Response<dynamic>> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    if (getResponses.containsKey(endpoint)) {
      return Response(
        requestOptions: RequestOptions(path: endpoint),
        data: getResponses[endpoint],
        statusCode: 200,
      );
    }
    throw ApiException('404 Not Found');
  }

  @override
  Future<Response<dynamic>> post(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    postCalls.add({'endpoint': endpoint, 'data': data});
    if (postResponses.containsKey(endpoint)) {
      return Response(
        requestOptions: RequestOptions(path: endpoint),
        data: postResponses[endpoint],
        statusCode: 201,
      );
    }
    throw ApiException('400 Bad Request');
  }

  @override
  Future<Response<dynamic>> delete(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    deleteCalls.add(endpoint);
    return Response(
      requestOptions: RequestOptions(path: endpoint),
      data: {'detail': 'Deleted'},
      statusCode: 204,
    );
  }
}

void main() {
  group('SkillsService Tests', () {
    late MockApiService mockApi;
    late SkillsService skillsService;

    setUp(() {
      mockApi = MockApiService(
        getResponses: {
          '/api/skills/': [
            {
              'id': 101,
              'name': 'Flutter',
              'category': {'id': 1, 'name': 'Mobile Dev'},
            },
            {
              'id': 102,
              'name': 'Django',
              'category': {'id': 2, 'name': 'Backend Dev'},
            },
          ],
          '/api/skills/my-skills/': [
            {
              'id': 1,
              'skill': 101,
              'skill_name': 'Flutter',
              'skill_type': 'teach',
              'proficiency': 'advanced',
              'created_at': '2026-10-08T00:00:00Z',
            },
            {
              'id': 2,
              'skill': 102,
              'skill_name': 'Django',
              'skill_type': 'learn',
              'proficiency': 'beginner',
              'created_at': '2026-10-08T00:00:00Z',
            },
          ],
        },
        postResponses: {
          '/api/skills/my-skills/': {
            'id': 3,
            'skill': 101,
            'skill_name': 'Flutter',
            'skill_type': 'teach',
            'proficiency': 'expert',
            'created_at': '2026-10-08T00:00:00Z',
          },
        },
      );
      skillsService = SkillsService(apiService: mockApi);
    });

    test('getAvailableSkills returns catalog from /api/skills/', () async {
      final catalog = await skillsService.getAvailableSkills();
      expect(catalog.length, equals(2));
      expect(catalog[0].id, equals(101));
      expect(catalog[0].name, equals('Flutter'));
      expect(catalog[0].categoryName, equals('Mobile Dev'));
    });

    test(
      'getMySkills returns user skills with categories populated from catalog',
      () async {
        final userSkills = await skillsService.getMySkills();
        expect(userSkills.length, equals(2));
        expect(userSkills[0].id, equals(1));
        expect(userSkills[0].skillName, equals('Flutter'));
        expect(userSkills[0].categoryName, equals('Mobile Dev'));
        expect(userSkills[0].proficiency, equals('Advanced'));
        expect(userSkills[0].skillType, equals('teach'));

        expect(userSkills[1].id, equals(2));
        expect(userSkills[1].skillName, equals('Django'));
        expect(userSkills[1].categoryName, equals('Backend Dev'));
        expect(userSkills[1].proficiency, equals('Beginner'));
        expect(userSkills[1].skillType, equals('learn'));
      },
    );

    test(
      'getTeachingSkills filters user skills where skill_type == teach',
      () async {
        final teachSkills = await skillsService.getTeachingSkills();
        expect(teachSkills.length, equals(1));
        expect(teachSkills[0].skillName, equals('Flutter'));
        expect(teachSkills[0].skillType, equals('teach'));
      },
    );

    test(
      'getLearningSkills filters user skills where skill_type == learn',
      () async {
        final learnSkills = await skillsService.getLearningSkills();
        expect(learnSkills.length, equals(1));
        expect(learnSkills[0].skillName, equals('Django'));
        expect(learnSkills[0].skillType, equals('learn'));
      },
    );

    test('addTeachingSkill sends POST to /api/skills/my-skills/ with skill_type=teach', () async {
      final added = await skillsService.addTeachingSkill(
        skillId: 101,
        proficiency: 'expert',
      );
      expect(mockApi.postCalls.length, equals(1));
      expect(
        mockApi.postCalls[0]['endpoint'],
        equals('/api/skills/my-skills/'),
      );
      expect(
        mockApi.postCalls[0]['data'],
        equals({'skill': 101, 'skill_type': 'teach', 'proficiency': 'expert'}),
      );
      expect(added.id, equals(3));
      expect(added.proficiency, equals('Expert'));
    });

    test('removeSkill sends DELETE to /api/skills/my-skills/<id>/', () async {
      await skillsService.removeSkill(userSkillId: 2, skillType: 'learn');
      expect(mockApi.deleteCalls.length, equals(1));
      expect(mockApi.deleteCalls[0], equals('/api/skills/my-skills/2/'));
    });
  });
}
