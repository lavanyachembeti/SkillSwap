import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/requests_service.dart';

class MockRequestsApiService extends ApiService {
  final Map<String, dynamic> getResponses;
  final Map<String, dynamic> putResponses;
  final Map<String, dynamic> postResponses;

  final List<String> getCalls = [];
  final List<Map<String, dynamic>> putCalls = [];
  final List<Map<String, dynamic>> postCalls = [];

  MockRequestsApiService({
    this.getResponses = const {},
    this.putResponses = const {},
    this.postResponses = const {},
  });

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

  @override
  Future<Response<dynamic>> post(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    postCalls.add({'endpoint': endpoint, 'data': data});
    if (postResponses.containsKey(endpoint)) {
      final res = postResponses[endpoint];
      if (res is Exception) throw res;
      return Response(
        requestOptions: RequestOptions(path: endpoint),
        data: res,
        statusCode: 201,
      );
    }
    throw ApiException('400 Bad Request', statusCode: 400);
  }
}

void main() {
  group('RequestsService Tests', () {
    late MockRequestsApiService mockApi;
    late RequestsService service;

    setUp(() {
      mockApi = MockRequestsApiService(
        getResponses: {
          '/api/requests/': {
            'sent': [
              {
                'id': 1,
                'requester': 10,
                'requester_name': 'alice',
                'target': 20,
                'target_name': 'bob',
                'requested_skill': 101,
                'requested_skill_name': 'Flutter',
                'offered_skill': 102,
                'offered_skill_name': 'Django',
                'status': 'pending',
                'created_at': '2026-10-21T00:00:00Z',
              },
            ],
            'received': [
              {
                'id': 2,
                'requester': 30,
                'requester_name': 'charlie',
                'target': 10,
                'target_name': 'alice',
                'requested_skill': 103,
                'requested_skill_name': 'Python',
                'message': 'Teach me Python please',
                'learning_goal': 'Build a web service',
                'status': 'pending',
                'created_at': '2026-10-21T01:00:00Z',
              },
            ],
          },
        },
        putResponses: {
          '/api/requests/2/': {
            'id': 2,
            'requester': 30,
            'requester_name': 'charlie',
            'target': 10,
            'target_name': 'alice',
            'requested_skill': 103,
            'requested_skill_name': 'Python',
            'status': 'accepted',
          },
          '/api/requests/3/': {
            'id': 3,
            'requester': 40,
            'requester_name': 'david',
            'target': 10,
            'target_name': 'alice',
            'requested_skill': 104,
            'requested_skill_name': 'Go',
            'status': 'rejected',
          },
        },
        postResponses: {
          '/api/requests/': {
            'id': 4,
            'requester': 10,
            'requester_name': 'alice',
            'target': 50,
            'target_name': 'eve',
            'requested_skill': 105,
            'requested_skill_name': 'Rust',
            'status': 'pending',
          },
        },
      );
      service = RequestsService(apiService: mockApi);
    });

    test(
      'getRequests fetches and returns sent and received skill requests',
      () async {
        final res = await service.getRequests();

        expect(mockApi.getCalls, contains('/api/requests/'));
        expect(res.sent.length, equals(1));
        expect(res.sent[0].targetName, equals('bob'));
        expect(res.sent[0].requestedSkillName, equals('Flutter'));

        expect(res.received.length, equals(1));
        expect(res.received[0].requesterName, equals('charlie'));
        expect(res.received[0].requestedSkillName, equals('Python'));
        expect(res.received[0].message, equals('Teach me Python please'));
      },
    );

    test(
      'acceptRequest sends PUT to /api/requests/<id>/ with status: accepted',
      () async {
        final updated = await service.acceptRequest(2);

        expect(mockApi.putCalls.length, equals(1));
        expect(mockApi.putCalls[0]['endpoint'], equals('/api/requests/2/'));
        expect(mockApi.putCalls[0]['data'], equals({'status': 'accepted'}));
        expect(updated.id, equals(2));
        expect(updated.status, equals('accepted'));
        expect(updated.isAccepted, isTrue);
      },
    );

    test(
      'rejectRequest sends PUT to /api/requests/<id>/ with status: rejected',
      () async {
        final updated = await service.rejectRequest(3);

        expect(mockApi.putCalls.length, equals(1));
        expect(mockApi.putCalls[0]['endpoint'], equals('/api/requests/3/'));
        expect(mockApi.putCalls[0]['data'], equals({'status': 'rejected'}));
        expect(updated.id, equals(3));
        expect(updated.status, equals('rejected'));
        expect(updated.isRejected, isTrue);
      },
    );

    test('sendRequest sends POST to /api/requests/ with required and optional payload', () async {
      final created = await service.sendRequest(
        targetUserId: 50,
        requestedSkillId: 105,
        offeredSkillId: 101,
        message: 'Let us swap Rust and Flutter',
        learningGoal: 'Systems programming',
      );

      expect(mockApi.postCalls.length, equals(1));
      expect(mockApi.postCalls[0]['endpoint'], equals('/api/requests/'));
      expect(
        mockApi.postCalls[0]['data'],
        equals({
          'target': 50,
          'requested_skill': 105,
          'offered_skill': 101,
          'message': 'Let us swap Rust and Flutter',
          'learning_goal': 'Systems programming',
        }),
      );
      expect(created.id, equals(4));
      expect(created.requestedSkillName, equals('Rust'));
    });

    test('rethrows ApiException when api request fails', () async {
      final failingApi = MockRequestsApiService(
        getResponses: {
          '/api/requests/': ApiException('Network error', statusCode: 500),
        },
      );
      final failingService = RequestsService(apiService: failingApi);

      expect(() => failingService.getRequests(), throwsA(isA<ApiException>()));
    });
  });
}
