import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/screens/chat/chat_screen.dart';
import 'package:frontend/services/api_service.dart';

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
    if (endpoint.contains('/api/users/profile/')) {
      return Response(
        requestOptions: RequestOptions(path: endpoint),
        data: {
          'id': 1,
          'username': 'test_user',
          'bio': '',
          'skills_teach': <dynamic>[],
          'skills_learn': <dynamic>[],
        },
        statusCode: 200,
      );
    }
    // Default fallback to empty list
    return Response(
      requestOptions: RequestOptions(path: endpoint),
      data: <dynamic>[],
      statusCode: 200,
    );
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
      data: <String, dynamic>{
        'id': 99,
        'conversation': 1,
        'sender': 1,
        'sender_name': 'test_user',
        'message': data is Map ? data['message'] : 'test',
        'timestamp': DateTime.now().toIso8601String(),
        'is_read': false,
      },
      statusCode: 201,
    );
  }
}

void main() {
  Widget buildTestableWidget(Widget child, {Size size = const Size(390, 844)}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: child,
      ),
    );
  }

  group('ChatScreen Responsive Layout & UI Tests', () {
    testWidgets(
      'renders empty state on narrow mobile screen (320px) without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockApi = MockChatApiService();

        await tester.pumpWidget(
          buildTestableWidget(
            ChatScreen(apiService: mockApi),
            size: const Size(320, 568),
          ),
        );
        await tester.pumpAndSettle();

        // Heading and empty-state elements should be present
        expect(find.text('Messages'), findsOneWidget);
        expect(find.text('SkillSwap Messages'), findsOneWidget);
        expect(
          find.text(
            'Chat with your matched skill partners and arrange sessions.',
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'renders empty state on tablet (768px) and desktop (1280px) centered',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockApi = MockChatApiService();

        await tester.pumpWidget(
          buildTestableWidget(
            ChatScreen(apiService: mockApi),
            size: const Size(1024, 768),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Messages'), findsOneWidget);
        expect(find.text('SkillSwap Messages'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'renders active conversation with message bubbles and input bar',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockApi = MockChatApiService();

        await tester.pumpWidget(
          buildTestableWidget(
            ChatScreen(
              apiService: mockApi,
              peerName: 'Alice Walker',
              peerSkill: 'Python & Django',
              initialMessages: const [
                ChatMessageItem(
                  text: 'Hello! Excited to swap skills with you.',
                  isMe: false,
                  time: '10:30 AM',
                ),
                ChatMessageItem(
                  text: 'Hi Alice! Let us coordinate our first session.',
                  isMe: true,
                  time: '10:32 AM',
                ),
              ],
            ),
            size: const Size(375, 812),
          ),
        );
        await tester.pumpAndSettle();

        // Header details
        expect(find.text('Alice Walker'), findsOneWidget);
        expect(find.text('Python & Django'), findsOneWidget);

        // Messages
        expect(
          find.text('Hello! Excited to swap skills with you.'),
          findsOneWidget,
        );
        expect(
          find.text('Hi Alice! Let us coordinate our first session.'),
          findsOneWidget,
        );

        // Input field and send button
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byIcon(Icons.send_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'wraps extremely long message text cleanly on small screen (320px)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const longMessage =
            'This is an exceptionally long message designed to test whether responsive wrapping functions properly on a compact 320px screen width without causing any horizontal overflow errors in Flutter rendering.';

        final mockApi = MockChatApiService();

        await tester.pumpWidget(
          buildTestableWidget(
            ChatScreen(
              apiService: mockApi,
              peerName: 'Bob Builder',
              initialMessages: const [
                ChatMessageItem(
                  text: longMessage,
                  isMe: false,
                  time: '11:00 AM',
                ),
              ],
            ),
            size: const Size(320, 600),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(longMessage), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('allows typing and sending a new message', (tester) async {
      final mockApi = MockChatApiService();

      await tester.pumpWidget(
        buildTestableWidget(
          ChatScreen(apiService: mockApi, peerName: 'Charlie'),
        ),
      );
      await tester.pumpAndSettle();

      // Enter text
      await tester.enterText(
        find.byType(TextField),
        'See you tomorrow at 5 PM',
      );
      await tester.pump();

      // Tap send button
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text('See you tomorrow at 5 PM'), findsOneWidget);
      expect(find.text('Type a message...'), findsOneWidget);
    });

    testWidgets('back button returns from conversation to empty state', (
      tester,
    ) async {
      final mockApi = MockChatApiService();

      await tester.pumpWidget(
        buildTestableWidget(ChatScreen(apiService: mockApi, peerName: 'Diana')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Diana'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Should now show empty state
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('SkillSwap Messages'), findsOneWidget);
    });

    testWidgets(
      'displays conversation list when conversations exist and opens conversation on tap',
      (tester) async {
        final mockApi = MockChatApiService(
          getResponses: {
            '/api/chat/conversations/': [
              {
                'id': 10,
                'user1': 1,
                'user1_name': 'test_user',
                'user2': 2,
                'user2_name': 'priya_swap',
                'unread_count': 0,
              },
            ],
            '/api/chat/conversations/10/messages/': [
              {
                'id': 1,
                'conversation': 10,
                'sender': 2,
                'sender_name': 'priya_swap',
                'message': 'Welcome to SkillSwap!',
                'timestamp': '2026-10-21T10:00:00Z',
                'is_read': true,
              },
            ],
          },
        );

        await tester.pumpWidget(
          buildTestableWidget(ChatScreen(apiService: mockApi)),
        );
        await tester.pumpAndSettle();

        // Should show conversation list
        expect(find.text('Messages'), findsOneWidget);
        expect(find.text('priya_swap'), findsOneWidget);
        expect(find.text('Skill Exchange Partner'), findsOneWidget);

        // Tap on conversation item
        await tester.tap(find.text('priya_swap'));
        await tester.pumpAndSettle();

        // Should now be inside active conversation view
        expect(find.text('Welcome to SkillSwap!'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
      },
    );
  });
}
