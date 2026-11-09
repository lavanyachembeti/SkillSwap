import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/discover_user_model.dart';
import 'package:frontend/screens/requests/requests_screen.dart';
import 'package:frontend/screens/requests/send_request_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/requests_service.dart';
import 'package:frontend/services/skills_service.dart';

class MockSendRequestApiService extends ApiService {
  final Map<String, dynamic> getResponses;
  final Map<String, dynamic> postResponses;

  final List<String> getCalls = [];
  final List<Map<String, dynamic>> postCalls = [];

  MockSendRequestApiService({
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
  group('SendRequestScreen Widget Tests', () {
    late DiscoverUserModel sampleTargetUser;

    setUp(() {
      sampleTargetUser = const DiscoverUserModel(
        id: 2,
        username: 'alice_wong',
        bio: 'Senior Flutter and Mobile Developer',
        profileImage: null,
        skillsTeach: [
          DiscoveredSkill(id: 101, name: 'Flutter', proficiency: 'Advanced'),
          DiscoveredSkill(id: 102, name: 'Dart', proficiency: 'Expert'),
        ],
        skillsLearn: [DiscoveredSkill(id: 201, name: 'Python')],
      );
    });

    Widget buildTestWidget({
      required DiscoverUserModel targetUser,
      required ApiService apiService,
    }) {
      return MaterialApp(
        home: SendRequestScreen(
          targetUser: targetUser,
          apiService: apiService,
          requestsService: RequestsService(apiService: apiService),
          skillsService: SkillsService(apiService: apiService),
        ),
      );
    }

    testWidgets(
      'renders target user info, skills to learn, and loads user teaching skills',
      (tester) async {
        final mockApi = MockSendRequestApiService(
          getResponses: {
            '/api/skills/my-skills/': [
              {
                'id': 1,
                'skill': 301,
                'skill_name': 'Python',
                'skill_type': 'teach',
                'proficiency': 'Expert',
              },
            ],
            '/api/skills/': [
              {'id': 301, 'name': 'Python', 'category': 'Programming'},
            ],
          },
        );

        await tester.pumpWidget(
          buildTestWidget(targetUser: sampleTargetUser, apiService: mockApi),
        );
        await tester.pumpAndSettle();

        // Target user card details
        expect(find.text('Request Skill Swap'), findsOneWidget);
        expect(find.text('alice_wong'), findsOneWidget);
        expect(
          find.text('Senior Flutter and Mobile Developer'),
          findsOneWidget,
        );
        expect(find.text('Target Peer'), findsOneWidget);

        // Section 1: Choose what to learn
        expect(find.text('1. Choose what to learn'), findsOneWidget);
        expect(find.text('Flutter (Advanced)'), findsOneWidget);
        expect(find.text('Dart (Expert)'), findsOneWidget);

        // Section 2: Choose what to teach in return
        expect(find.text('2. Choose what to teach in return'), findsOneWidget);
        expect(find.text('None (Learn only)'), findsOneWidget);
        expect(find.text('Python (Expert)'), findsOneWidget);

        // Section 3: Message & goal inputs
        expect(find.text('3. Message & Learning Goal'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(2));

        // Submit button
        expect(find.text('Send Swap Request'), findsOneWidget);
      },
    );

    testWidgets(
      'submits request with exact payload matching backend serializer',
      (tester) async {
        final mockApi = MockSendRequestApiService(
          getResponses: {
            '/api/skills/my-skills/': [
              {
                'id': 5,
                'skill': 301,
                'skill_name': 'Python',
                'skill_type': 'teach',
                'proficiency': 'Expert',
              },
            ],
            '/api/skills/': [],
          },
          postResponses: {
            '/api/requests/': {
              'id': 99,
              'requester': 1,
              'requester_name': 'my_user',
              'target': 2,
              'target_name': 'alice_wong',
              'requested_skill': 102,
              'requested_skill_name': 'Dart',
              'offered_skill': 301,
              'offered_skill_name': 'Python',
              'message': 'Hi Alice, let us swap Dart and Python!',
              'learning_goal': 'Build cross platform UI',
              'status': 'pending',
            },
          },
        );

        await tester.pumpWidget(
          buildTestWidget(targetUser: sampleTargetUser, apiService: mockApi),
        );
        await tester.pumpAndSettle();

        // Select Dart instead of Flutter
        await tester.tap(find.text('Dart (Expert)'));
        await tester.pumpAndSettle();

        // Select Python as offered skill
        await tester.tap(find.text('Python (Expert)'));
        await tester.pumpAndSettle();

        // Enter message and learning goal
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Message (optional)'),
          'Hi Alice, let us swap Dart and Python!',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Learning Goal (optional)'),
          'Build cross platform UI',
        );
        await tester.pumpAndSettle();

        // Tap submit
        await tester.ensureVisible(find.text('Send Swap Request'));
        await tester.tap(find.text('Send Swap Request'));
        await tester.pumpAndSettle();

        // Verify POST call and exact payload
        expect(mockApi.postCalls.length, equals(1));
        final call = mockApi.postCalls.first;
        expect(call['endpoint'], equals('/api/requests/'));
        expect(
          call['data'],
          equals({
            'target': 2,
            'requested_skill': 102,
            'offered_skill': 301,
            'message': 'Hi Alice, let us swap Dart and Python!',
            'learning_goal': 'Build cross platform UI',
          }),
        );
      },
    );

    testWidgets('submits request without offered skill (omits offered_skill)', (
      tester,
    ) async {
      final mockApi = MockSendRequestApiService(
        getResponses: {'/api/skills/my-skills/': [], '/api/skills/': []},
        postResponses: {
          '/api/requests/': {
            'id': 100,
            'requester': 1,
            'target': 2,
            'requested_skill': 101,
            'status': 'pending',
          },
        },
      );

      await tester.pumpWidget(
        buildTestWidget(targetUser: sampleTargetUser, apiService: mockApi),
      );
      await tester.pumpAndSettle();

      // Flutter is selected by default, no offered skill selected
      await tester.ensureVisible(find.text('Send Swap Request'));
      await tester.tap(find.text('Send Swap Request'));
      await tester.pumpAndSettle();

      expect(mockApi.postCalls.length, equals(1));
      final call = mockApi.postCalls.first;
      expect(call['endpoint'], equals('/api/requests/'));
      expect(call['data'], equals({'target': 2, 'requested_skill': 101}));
    });

    testWidgets(
      'resolves skill ID from master catalog if discovered skill has null ID',
      (tester) async {
        const userWithoutSkillIds = DiscoverUserModel(
          id: 3,
          username: 'bob_builder',
          bio: 'Carpenter and Woodworker',
          profileImage: null,
          skillsTeach: [
            DiscoveredSkill(id: null, name: 'Carpentry', proficiency: 'Master'),
          ],
          skillsLearn: [],
        );

        final mockApi = MockSendRequestApiService(
          getResponses: {
            '/api/skills/my-skills/': [],
            '/api/skills/': [
              {'id': 707, 'name': 'Carpentry', 'category': 'Crafts'},
            ],
          },
          postResponses: {
            '/api/requests/': {
              'id': 101,
              'requester': 1,
              'target': 3,
              'requested_skill': 707,
              'status': 'pending',
            },
          },
        );

        await tester.pumpWidget(
          buildTestWidget(targetUser: userWithoutSkillIds, apiService: mockApi),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Send Swap Request'));
        await tester.tap(find.text('Send Swap Request'));
        await tester.pumpAndSettle();

        expect(mockApi.postCalls.length, equals(1));
        final call = mockApi.postCalls.first;
        expect(call['data']['requested_skill'], equals(707));
        expect(call['data']['target'], equals(3));
      },
    );

    testWidgets(
      'displays error state when user has no teaching skills and disables submit',
      (tester) async {
        const emptyTeachUser = DiscoverUserModel(
          id: 4,
          username: 'new_learner',
          bio: 'Just getting started',
          skillsTeach: [],
          skillsLearn: [DiscoveredSkill(id: 1, name: 'Coding')],
        );

        final mockApi = MockSendRequestApiService(
          getResponses: {'/api/skills/my-skills/': []},
        );

        await tester.pumpWidget(
          buildTestWidget(targetUser: emptyTeachUser, apiService: mockApi),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'This user has not listed any skills to teach yet. You cannot send a swap request.',
          ),
          findsOneWidget,
        );

        final submitBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Send Swap Request'),
        );
        expect(submitBtn.onPressed, isNull);
      },
    );

    testWidgets('displays backend validation error banner on API failure', (
      tester,
    ) async {
      final mockApi = MockSendRequestApiService(
        getResponses: {'/api/skills/my-skills/': []},
        postResponses: {
          '/api/requests/': ApiException(
            'You cannot send a skill request to this user.',
            statusCode: 403,
          ),
        },
      );

      await tester.pumpWidget(
        buildTestWidget(targetUser: sampleTargetUser, apiService: mockApi),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Send Swap Request'));
      await tester.tap(find.text('Send Swap Request'));
      await tester.pumpAndSettle();

      expect(
        find.text('You cannot send a skill request to this user.'),
        findsOneWidget,
      );
    });

    testWidgets('triggers RequestsScreen.triggerRefresh on successful submit', (
      tester,
    ) async {
      final mockApi = MockSendRequestApiService(
        getResponses: {'/api/skills/my-skills/': []},
        postResponses: {
          '/api/requests/': {
            'id': 105,
            'requester': 1,
            'target': 2,
            'requested_skill': 101,
            'status': 'pending',
          },
        },
      );

      int refreshCount = 0;
      void listener() {
        refreshCount++;
      }

      RequestsScreen.refreshNotifier.addListener(listener);

      await tester.pumpWidget(
        buildTestWidget(targetUser: sampleTargetUser, apiService: mockApi),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Send Swap Request'));
      await tester.tap(find.text('Send Swap Request'));
      await tester.pumpAndSettle();

      expect(refreshCount, greaterThan(0));

      RequestsScreen.refreshNotifier.removeListener(listener);
    });
  });
}
