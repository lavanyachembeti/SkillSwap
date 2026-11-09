import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/chat/chat_screen.dart';
import 'package:frontend/screens/requests/requests_screen.dart';
import 'package:frontend/services/api_service.dart';

class MockRequestsApiService extends ApiService {
  final Map<String, dynamic> getResponses;
  final Map<String, dynamic> putResponses;
  final Map<String, dynamic> postResponses;
  final List<String> getCalls = [];
  final List<Map<String, dynamic>> putCalls = [];
  final List<Map<String, dynamic>> postCalls = [];

  MockRequestsApiService({
    required this.getResponses,
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
    // Default fallback for profile and chat in sub-screens
    if (endpoint.contains('/api/users/profile/')) {
      return Response(
        requestOptions: RequestOptions(path: endpoint),
        data: {'username': 'my_user'},
        statusCode: 200,
      );
    }
    if (endpoint.contains('/api/chat/')) {
      return Response(
        requestOptions: RequestOptions(path: endpoint),
        data: <dynamic>[],
        statusCode: 200,
      );
    }
    throw ApiException('Not found', statusCode: 404);
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
    throw ApiException('Bad request', statusCode: 400);
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
    return Response(
      requestOptions: RequestOptions(path: endpoint),
      data: {
        'id': 1,
        'user1': 2,
        'user1_name': 'my_user',
        'user2': 3,
        'user2_name': 'priya_patel',
      },
      statusCode: 201,
    );
  }
}

void main() {
  group('RequestsScreen Widget Tests', () {
    Widget buildTestWidget(ApiService apiService) {
      return MaterialApp(home: RequestsScreen(apiService: apiService));
    }

    testWidgets(
      'renders incoming requests and displays all details and action buttons',
      (tester) async {
        final mockApi = MockRequestsApiService(
          getResponses: {
            '/api/requests/': {
              'sent': [],
              'received': [
                {
                  'id': 10,
                  'requester': 1,
                  'requester_name': 'alice_wong',
                  'target': 2,
                  'target_name': 'my_user',
                  'requested_skill': 101,
                  'requested_skill_name': 'Flutter',
                  'offered_skill': 102,
                  'offered_skill_name': 'Python',
                  'message': 'Can you teach me Flutter?',
                  'learning_goal': 'Build cross platform apps',
                  'status': 'pending',
                  'created_at': '2026-10-21T10:00:00Z',
                },
              ],
            },
          },
        );

        await tester.pumpWidget(buildTestWidget(mockApi));
        await tester.pumpAndSettle();

        expect(mockApi.getCalls, contains('/api/requests/'));
        expect(find.text('Skill Requests'), findsOneWidget);
        expect(find.text('alice_wong'), findsOneWidget);
        expect(find.text('Requested from you'), findsOneWidget);
        expect(find.text('Flutter'), findsOneWidget);
        expect(find.text('Python'), findsOneWidget);
        expect(find.text('Can you teach me Flutter?'), findsOneWidget);
        expect(find.text('Goal: Build cross platform apps'), findsOneWidget);
        expect(find.text('Pending'), findsOneWidget);
        expect(find.text('Accept'), findsOneWidget);
        expect(find.text('Decline'), findsOneWidget);
      },
    );

    testWidgets('renders sent requests on the Sent tab', (tester) async {
      final mockApi = MockRequestsApiService(
        getResponses: {
          '/api/requests/': {
            'sent': [
              {
                'id': 11,
                'requester': 2,
                'requester_name': 'my_user',
                'target': 3,
                'target_name': 'bob_ross',
                'requested_skill': 201,
                'requested_skill_name': 'Painting',
                'offered_skill': null,
                'offered_skill_name': null,
                'message': 'Excited to learn painting!',
                'learning_goal': null,
                'status': 'pending',
                'created_at': '2026-10-21T10:00:00Z',
              },
            ],
            'received': [],
          },
        },
      );

      await tester.pumpWidget(buildTestWidget(mockApi));
      await tester.pumpAndSettle();

      // Switch to Sent tab
      await tester.tap(find.text('Sent'));
      await tester.pumpAndSettle();

      expect(find.text('bob_ross'), findsOneWidget);
      expect(find.text('Sent by you'), findsOneWidget);
      expect(find.text('Painting'), findsOneWidget);
      expect(find.text('Excited to learn painting!'), findsOneWidget);
      // Sent tab should NOT have Accept/Decline action buttons
      expect(find.text('Accept'), findsNothing);
      expect(find.text('Decline'), findsNothing);
    });

    testWidgets('accepting a request updates its status to Accepted', (
      tester,
    ) async {
      final mockApi = MockRequestsApiService(
        getResponses: {
          '/api/requests/': {
            'sent': [],
            'received': [
              {
                'id': 12,
                'requester': 5,
                'requester_name': 'charlie_brown',
                'target': 2,
                'target_name': 'my_user',
                'requested_skill': 301,
                'requested_skill_name': 'Chess',
                'offered_skill': null,
                'offered_skill_name': null,
                'status': 'pending',
                'created_at': '2026-10-21T10:00:00Z',
              },
            ],
          },
        },
        putResponses: {
          '/api/requests/12/': {
            'id': 12,
            'requester': 5,
            'requester_name': 'charlie_brown',
            'target': 2,
            'target_name': 'my_user',
            'requested_skill': 301,
            'requested_skill_name': 'Chess',
            'status': 'accepted',
          },
        },
      );

      await tester.pumpWidget(buildTestWidget(mockApi));
      await tester.pumpAndSettle();

      expect(find.text('Accept'), findsOneWidget);
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      expect(mockApi.putCalls.length, equals(1));
      expect(mockApi.putCalls[0]['endpoint'], equals('/api/requests/12/'));
      expect(mockApi.putCalls[0]['data'], equals({'status': 'accepted'}));
      expect(
        find.text('Accepted swap request from charlie_brown!'),
        findsOneWidget,
      );
      expect(find.text('Accepted'), findsOneWidget);
      // Action buttons should disappear once accepted
      expect(find.text('Accept'), findsNothing);
    });

    testWidgets('declining a request updates its status to Declined', (
      tester,
    ) async {
      final mockApi = MockRequestsApiService(
        getResponses: {
          '/api/requests/': {
            'sent': [],
            'received': [
              {
                'id': 13,
                'requester': 6,
                'requester_name': 'david_beckham',
                'target': 2,
                'target_name': 'my_user',
                'requested_skill': 401,
                'requested_skill_name': 'Soccer',
                'offered_skill': null,
                'offered_skill_name': null,
                'status': 'pending',
                'created_at': '2026-10-21T10:00:00Z',
              },
            ],
          },
        },
        putResponses: {
          '/api/requests/13/': {
            'id': 13,
            'requester': 6,
            'requester_name': 'david_beckham',
            'target': 2,
            'target_name': 'my_user',
            'requested_skill': 401,
            'requested_skill_name': 'Soccer',
            'status': 'rejected',
          },
        },
      );

      await tester.pumpWidget(buildTestWidget(mockApi));
      await tester.pumpAndSettle();

      expect(find.text('Decline'), findsOneWidget);
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();

      expect(mockApi.putCalls.length, equals(1));
      expect(mockApi.putCalls[0]['endpoint'], equals('/api/requests/13/'));
      expect(mockApi.putCalls[0]['data'], equals({'status': 'rejected'}));
      expect(find.text('Declined request from david_beckham.'), findsOneWidget);
      expect(find.text('Declined'), findsOneWidget);
      expect(find.text('Decline'), findsNothing);
    });

    testWidgets('shows separate empty states for incoming and sent tabs', (
      tester,
    ) async {
      final mockApi = MockRequestsApiService(
        getResponses: {
          '/api/requests/': {'sent': [], 'received': []},
        },
      );

      await tester.pumpWidget(buildTestWidget(mockApi));
      await tester.pumpAndSettle();

      // Incoming tab empty state
      expect(find.text('No Incoming Requests'), findsOneWidget);
      expect(
        find.text('You do not have any skill swap requests from peers yet.'),
        findsOneWidget,
      );

      // Switch to Sent tab
      await tester.tap(find.text('Sent'));
      await tester.pumpAndSettle();

      // Sent tab empty state
      expect(find.text('No Sent Requests'), findsOneWidget);
      expect(
        find.text(
          'You haven\'t sent any skill swap requests yet. Discover peers to start swapping skills!',
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays error state and retries successfully', (
      tester,
    ) async {
      final responses = <String, dynamic>{
        '/api/requests/': ApiException('Network connection failed'),
      };

      final mockApi = MockRequestsApiService(getResponses: responses);

      await tester.pumpWidget(buildTestWidget(mockApi));
      await tester.pumpAndSettle();

      expect(find.text('Failed to Load Requests'), findsOneWidget);
      expect(find.text('Network connection failed'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Fix response and tap retry
      responses['/api/requests/'] = {
        'sent': [],
        'received': [
          {
            'id': 14,
            'requester': 7,
            'requester_name': 'elena_gilbert',
            'target': 2,
            'target_name': 'my_user',
            'requested_skill': 501,
            'requested_skill_name': 'Writing',
            'status': 'pending',
          },
        ],
      };

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('elena_gilbert'), findsOneWidget);
      expect(find.text('Writing'), findsOneWidget);
    });

    testWidgets(
      'renders Chat with Partner button for accepted requests and navigates',
      (tester) async {
        final mockApi = MockRequestsApiService(
          getResponses: {
            '/api/requests/': {
              'sent': [],
              'received': [
                {
                  'id': 15,
                  'requester': 3,
                  'requester_name': 'priya_patel',
                  'target': 2,
                  'target_name': 'my_user',
                  'requested_skill': 201,
                  'requested_skill_name': 'Data Science',
                  'status': 'accepted',
                  'created_at': '2026-10-21T10:00:00Z',
                },
              ],
            },
          },
        );

        await tester.pumpWidget(buildTestWidget(mockApi));
        await tester.pumpAndSettle();

        expect(find.text('priya_patel'), findsOneWidget);
        expect(find.text('Accepted'), findsOneWidget);
        expect(find.text('Chat with Partner'), findsOneWidget);

        await tester.tap(find.text('Chat with Partner'));
        await tester.pumpAndSettle();
        expect(find.byType(ChatScreen), findsOneWidget);
      },
    );
  });
}
