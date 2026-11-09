import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/app_constants.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/chat_service.dart';
import 'package:frontend/services/storage_service.dart';

class FakeChatStorageService extends StorageService {
  final String? token;
  FakeChatStorageService({this.token});

  @override
  Future<String?> getAccessToken() async => token;
}

class MockChatApiService extends ApiService {
  final Map<String, dynamic> getResponses;
  final Map<String, dynamic> postResponses;

  final List<String> getCalls = [];
  final List<Map<String, dynamic>> postCalls = [];

  MockChatApiService({
    this.getResponses = const {},
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
  group('ChatService Tests', () {
    test('getConversations fetches and parses conversation list', () async {
      final mockApi = MockChatApiService(
        getResponses: {
          '/api/chat/conversations/': [
            {
              'id': 1,
              'user1': 1,
              'user1_name': 'rahul',
              'user2': 2,
              'user2_name': 'priya',
              'unread_count': 0,
            },
            {
              'id': 2,
              'user1': 1,
              'user1_name': 'rahul',
              'user2': 3,
              'user2_name': 'lavanya',
              'unread_count': 2,
            },
          ],
        },
      );

      final service = ChatService(apiService: mockApi);
      final conversations = await service.getConversations();

      expect(conversations.length, equals(2));
      expect(conversations[0].id, equals(1));
      expect(conversations[0].user2Name, equals('priya'));
      expect(conversations[1].id, equals(2));
      expect(conversations[1].user2Name, equals('lavanya'));
      expect(mockApi.getCalls, contains('/api/chat/conversations/'));
    });

    test(
      'getOrCreateConversation posts user_id and returns conversation',
      () async {
        final mockApi = MockChatApiService(
          postResponses: {
            '/api/chat/conversations/': {
              'id': 3,
              'user1': 1,
              'user1_name': 'rahul',
              'user2': 4,
              'user2_name': 'vikram',
            },
          },
        );

        final service = ChatService(apiService: mockApi);
        final conv = await service.getOrCreateConversation(4);

        expect(conv.id, equals(3));
        expect(conv.user2Name, equals('vikram'));
        expect(mockApi.postCalls.length, equals(1));
        expect(mockApi.postCalls.first['data'], equals({'user_id': 4}));
      },
    );

    test('getMessages fetches message history for a conversation', () async {
      final mockApi = MockChatApiService(
        getResponses: {
          '/api/chat/conversations/1/messages/': [
            {
              'id': 1,
              'conversation': 1,
              'sender': 1,
              'sender_name': 'rahul',
              'message': 'Hi Priya',
              'timestamp': '2026-10-21T10:00:00Z',
            },
            {
              'id': 2,
              'conversation': 1,
              'sender': 2,
              'sender_name': 'priya',
              'message': 'Hi Rahul!',
              'timestamp': '2026-10-21T10:01:00Z',
            },
          ],
        },
      );

      final service = ChatService(apiService: mockApi);
      final messages = await service.getMessages(1);

      expect(messages.length, equals(2));
      expect(messages[0].message, equals('Hi Priya'));
      expect(messages[1].message, equals('Hi Rahul!'));
    });

    test(
      'sendMessage posts message and returns created ChatMessageModel',
      () async {
        final mockApi = MockChatApiService(
          postResponses: {
            '/api/chat/conversations/1/messages/': {
              'id': 3,
              'conversation': 1,
              'sender': 1,
              'sender_name': 'rahul',
              'message': 'Let us start tomorrow',
              'timestamp': '2026-10-21T10:05:00Z',
            },
          },
        );

        final service = ChatService(apiService: mockApi);
        final msg = await service.sendMessage(1, 'Let us start tomorrow');

        expect(msg.id, equals(3));
        expect(msg.message, equals('Let us start tomorrow'));
        expect(mockApi.postCalls.length, equals(1));
        expect(
          mockApi.postCalls.first['data'],
          equals({'message': 'Let us start tomorrow'}),
        );
      },
    );

    test('throws ApiException on API error', () async {
      final mockApi = MockChatApiService(
        getResponses: {
          '/api/chat/conversations/': ApiException(
            'Network Error',
            statusCode: 500,
          ),
        },
      );

      final service = ChatService(apiService: mockApi);
      expect(() => service.getConversations(), throwsA(isA<ApiException>()));
    });

    test(
      'AppConstants and ChatService build ws:// and wss:// WebSocket URLs accurately',
      () async {
        expect(
          AppConstants.wsBaseUrlFor('http://127.0.0.1:8000'),
          equals('ws://127.0.0.1:8000'),
        );
        expect(
          AppConstants.wsBaseUrlFor('https://api.skillswap.example.com/'),
          equals('wss://api.skillswap.example.com'),
        );
        expect(
          AppConstants.chatWebSocketUrl(
            42,
            token: 'jwt-token-123',
            overrideBaseUrl: 'https://api.skillswap.example.com',
          ),
          equals(
            'wss://api.skillswap.example.com/ws/chat/42/?token=jwt-token-123',
          ),
        );

        final service = ChatService(
          apiService: MockChatApiService(),
          storageService: FakeChatStorageService(token: 'my-access-token'),
        );
        final wsUrl = await service.getConversationWebSocketUrl(7);
        expect(
          wsUrl,
          equals('${AppConstants.wsBaseUrl}/ws/chat/7/?token=my-access-token'),
        );
      },
    );
  });
}
