import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/discover/discover_screen.dart';
import 'package:frontend/services/api_service.dart';

class MockDiscoverApiService extends ApiService {
  final Map<String, dynamic> getResponses;
  final List<String> getCalls = [];

  MockDiscoverApiService({required this.getResponses});

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
    throw ApiException('Not found', statusCode: 404);
  }
}

void main() {
  group('DiscoverScreen Widget Tests', () {
    Widget buildTestWidget(ApiService service) {
      return MaterialApp(home: DiscoverScreen(apiService: service));
    }

    testWidgets(
      'fetches users from GET /api/discovery/users/ and displays cards',
      (tester) async {
        final mockApi = MockDiscoverApiService(
          getResponses: {
            '/api/discovery/users/': [
              {
                'id': 1,
                'username': 'alice_wong',
                'bio': 'Flutter and UI/UX enthusiast',
                'profile_image': null,
                'skills_teach': ['Flutter', 'Figma'],
                'skills_learn': ['Python', 'Django'],
              },
              {
                'id': 2,
                'username': 'bob_ross',
                'bio': 'Creative painter and digital artist',
                'profile_image': null,
                'skills_teach': [
                  {'name': 'Painting', 'proficiency': 'Expert'},
                ],
                'skills_learn': ['Photography'],
              },
            ],
          },
        );

        await tester.pumpWidget(buildTestWidget(mockApi));
        await tester.pumpAndSettle();

        // Check API was called
        expect(mockApi.getCalls, contains('/api/discovery/users/'));

        // Check users are rendered
        expect(find.text('alice_wong'), findsOneWidget);
        expect(find.text('Flutter and UI/UX enthusiast'), findsOneWidget);
        expect(find.text('Flutter'), findsOneWidget);
        expect(find.text('Figma'), findsOneWidget);
        expect(find.text('Python'), findsOneWidget);
        expect(find.text('Django'), findsOneWidget);

        expect(find.text('bob_ross'), findsOneWidget);
        expect(
          find.text('Creative painter and digital artist'),
          findsOneWidget,
        );
        expect(find.text('Painting • Expert'), findsOneWidget);
        expect(find.text('Photography'), findsOneWidget);
      },
    );

    testWidgets('displays empty state when backend returns empty list', (
      tester,
    ) async {
      final mockApi = MockDiscoverApiService(
        getResponses: {'/api/discovery/users/': []},
      );

      await tester.pumpWidget(buildTestWidget(mockApi));
      await tester.pumpAndSettle();

      expect(find.text('No Peers Found'), findsOneWidget);
      expect(
        find.text(
          'There are currently no active users available for skill swapping.',
        ),
        findsOneWidget,
      );
      expect(find.text('Refresh'), findsOneWidget);
    });

    testWidgets('displays error state on failure and retries successfully', (
      tester,
    ) async {
      final responses = <String, dynamic>{
        '/api/discovery/users/': ApiException('Network connection failed'),
      };

      final mockApi = MockDiscoverApiService(getResponses: responses);

      await tester.pumpWidget(buildTestWidget(mockApi));
      await tester.pumpAndSettle();

      expect(find.text('Failed to Load Users'), findsOneWidget);
      expect(find.text('Network connection failed'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Fix response and tap retry
      responses['/api/discovery/users/'] = [
        {
          'id': 3,
          'username': 'charlie_brown',
          'bio': 'Learning chess',
          'skills_teach': ['Chess'],
          'skills_learn': ['Guitar'],
        },
      ];

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('charlie_brown'), findsOneWidget);
      expect(find.text('Chess'), findsOneWidget);
      expect(find.text('Guitar'), findsOneWidget);
    });

    testWidgets('handles paginated response format', (tester) async {
      final mockApi = MockDiscoverApiService(
        getResponses: {
          '/api/discovery/users/': {
            'count': 1,
            'results': [
              {
                'id': 4,
                'username': 'diana_prince',
                'bio': 'Archery coach',
                'skills_teach': ['Archery'],
                'skills_learn': ['Meditation'],
              },
            ],
          },
        },
      );

      await tester.pumpWidget(buildTestWidget(mockApi));
      await tester.pumpAndSettle();

      expect(find.text('diana_prince'), findsOneWidget);
      expect(find.text('Archery'), findsOneWidget);
      expect(find.text('Meditation'), findsOneWidget);
    });

    testWidgets('user card and Request Skill Swap button open request form', (
      tester,
    ) async {
      final mockApi = MockDiscoverApiService(
        getResponses: {
          '/api/discovery/users/': [
            {
              'id': 10,
              'username': 'satya_nadella',
              'bio': 'Cloud and platform enthusiast',
              'skills_teach': [
                {
                  'id': 501,
                  'name': 'Cloud Architecture',
                  'proficiency': 'Expert',
                },
              ],
              'skills_learn': ['Quantum Computing'],
            },
          ],
          '/api/skills/my-skills/': [],
        },
      );

      await tester.pumpWidget(buildTestWidget(mockApi));
      await tester.pumpAndSettle();

      expect(find.text('satya_nadella'), findsOneWidget);
      expect(find.text('Request Skill Swap'), findsOneWidget);

      // Tap on Request Skill Swap button
      await tester.tap(find.text('Request Skill Swap'));
      await tester.pumpAndSettle();

      // Should open SendRequestScreen
      expect(find.text('Request Skill Swap'), findsWidgets);
      expect(find.text('1. Choose what to learn'), findsOneWidget);
      expect(find.text('Cloud Architecture (Expert)'), findsOneWidget);
    });
  });
}
