import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/profile_service.dart';

class MockApiService extends ApiService {
  final Map<String, dynamic> getResponses;
  final Map<String, dynamic> putResponses;
  final List<Map<String, dynamic>> putCalls = [];
  final List<String> getCalls = [];

  MockApiService({this.getResponses = const {}, this.putResponses = const {}});

  @override
  Future<Response<dynamic>> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    getCalls.add(endpoint);
    if (getResponses.containsKey(endpoint)) {
      final res = getResponses[endpoint];
      if (res is Exception) throw res;
      return Response(
        requestOptions: RequestOptions(path: endpoint),
        data: res,
        statusCode: 200,
      );
    }
    throw ApiException('404 Not Found', statusCode: 404);
  }

  @override
  Future<Response<dynamic>> put(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    putCalls.add({'endpoint': endpoint, 'data': data});
    if (putResponses.containsKey(endpoint)) {
      final res = putResponses[endpoint];
      if (res is Exception) throw res;
      return Response(
        requestOptions: RequestOptions(path: endpoint),
        data: res,
        statusCode: 200,
      );
    }
    throw ApiException('400 Bad Request', statusCode: 400);
  }
}

void main() {
  group('ProfileService Tests', () {
    test(
      'getProfile sends GET to /api/auth/profile/ and returns model',
      () async {
        final mockApi = MockApiService(
          getResponses: {
            '/api/auth/profile/': {
              'id': 10,
              'username': 'john_doe',
              'email': 'john@example.com',
              'phone': '1234567890',
              'bio': 'Passionate about coding',
              'role': 'student',
            },
          },
        );

        final service = ProfileService(apiService: mockApi);
        final profile = await service.getProfile();

        expect(mockApi.getCalls.length, equals(1));
        expect(mockApi.getCalls.first, equals('/api/auth/profile/'));
        expect(profile.username, equals('john_doe'));
        expect(profile.email, equals('john@example.com'));
        expect(profile.phone, equals('1234567890'));
        expect(profile.bio, equals('Passionate about coding'));
        expect(profile.role, equals('student'));
      },
    );

    test(
      'updateProfile sends PUT to /api/auth/profile/ with email, phone, bio',
      () async {
        final mockApi = MockApiService(
          putResponses: {
            '/api/auth/profile/': {
              'id': 10,
              'username': 'john_doe',
              'email': 'john_new@example.com',
              'phone': '9998887777',
              'bio': 'Updated bio description',
              'role': 'student',
            },
          },
        );

        final service = ProfileService(apiService: mockApi);
        final updated = await service.updateProfile(
          email: 'john_new@example.com',
          phone: '9998887777',
          bio: 'Updated bio description',
        );

        expect(mockApi.putCalls.length, equals(1));
        expect(
          mockApi.putCalls.first['endpoint'],
          equals('/api/auth/profile/'),
        );
        expect(
          mockApi.putCalls.first['data'],
          equals({
            'email': 'john_new@example.com',
            'phone': '9998887777',
            'bio': 'Updated bio description',
          }),
        );

        expect(updated.email, equals('john_new@example.com'));
        expect(updated.phone, equals('9998887777'));
        expect(updated.bio, equals('Updated bio description'));
      },
    );

    test('getProfile throws ApiException on failure', () async {
      final mockApi = MockApiService(
        getResponses: {
          '/api/auth/profile/': ApiException(
            'Network error occurred',
            statusCode: 500,
          ),
        },
      );

      final service = ProfileService(apiService: mockApi);
      expect(() => service.getProfile(), throwsA(isA<ApiException>()));
    });

    test('updateProfile throws ApiException on validation failure', () async {
      final mockApi = MockApiService(
        putResponses: {
          '/api/auth/profile/': ApiException(
            'Enter a valid email address.',
            statusCode: 400,
          ),
        },
      );

      final service = ProfileService(apiService: mockApi);
      expect(
        () => service.updateProfile(
          email: 'invalid-email',
          phone: '123',
          bio: 'test',
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('getProfile handles list response format gracefully', () async {
      final mockApi = MockApiService(
        getResponses: {
          '/api/auth/profile/': [
            {
              'id': 20,
              'username': 'list_user',
              'email': 'list@example.com',
              'phone': '1112223333',
              'bio': 'From a list response',
              'role': 'professional',
            },
          ],
        },
      );

      final service = ProfileService(apiService: mockApi);
      final profile = await service.getProfile();

      expect(profile.username, equals('list_user'));
      expect(profile.email, equals('list@example.com'));
      expect(profile.bio, equals('From a list response'));
    });

    test('getProfile handles paginated results response format', () async {
      final mockApi = MockApiService(
        getResponses: {
          '/api/auth/profile/': {
            'count': 1,
            'results': [
              {
                'id': 21,
                'username': 'paginated_user',
                'email': 'page@example.com',
                'phone': '4445556666',
                'bio': 'From results array',
                'role': 'student',
              },
            ],
          },
        },
      );

      final service = ProfileService(apiService: mockApi);
      final profile = await service.getProfile();

      expect(profile.username, equals('paginated_user'));
      expect(profile.email, equals('page@example.com'));
    });
  });
}
