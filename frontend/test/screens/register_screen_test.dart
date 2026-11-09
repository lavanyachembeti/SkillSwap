import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/app_constants.dart';
import 'package:frontend/screens/auth/register_screen.dart';
import 'package:frontend/services/api_service.dart';

class MockRegisterApiService extends ApiService {
  final Map<String, dynamic> postResponses;
  final List<String> postCalls = [];
  final List<dynamic> postData = [];

  MockRegisterApiService({this.postResponses = const {}});

  @override
  Future<Response<dynamic>> post(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    postCalls.add(endpoint);
    postData.add(data);

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
        'message': 'User registered successfully',
        'user': {
          'id': 1,
          'username': 'testuser',
          'email': 'test@example.com',
          'role': 'student',
        },
      },
      statusCode: 201,
    );
  }
}

void main() {
  group('RegisterScreen Widget Tests', () {
    Widget buildTestWidget(ApiService service) {
      return MaterialApp(home: RegisterScreen(apiService: service));
    }

    testWidgets('renders all registration form fields and submit button', (
      tester,
    ) async {
      final mockApi = MockRegisterApiService();
      await tester.pumpWidget(buildTestWidget(mockApi));

      expect(find.text('Join SkillSwap'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Role'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Register Account'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('shows validation errors when submitting empty form', (
      tester,
    ) async {
      final mockApi = MockRegisterApiService();
      await tester.pumpWidget(buildTestWidget(mockApi));

      final registerButton = find.text('Register Account');
      await tester.ensureVisible(registerButton);
      await tester.tap(registerButton);
      await tester.pumpAndSettle();

      expect(find.text('Username is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Phone number is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      expect(find.text('Please confirm your password'), findsOneWidget);

      expect(mockApi.postCalls.isEmpty, isTrue);
    });

    testWidgets(
      'shows validation error when password is less than 8 characters',
      (tester) async {
        final mockApi = MockRegisterApiService();
        await tester.pumpWidget(buildTestWidget(mockApi));

        final textFields = find.byType(TextFormField);
        // textFields[0]: username, [1]: email, [2]: phone, [3]: password, [4]: confirm password
        await tester.enterText(textFields.at(0), 'johndoe');
        await tester.enterText(textFields.at(1), 'john@example.com');
        await tester.enterText(textFields.at(2), '+1234567890');
        await tester.enterText(textFields.at(3), 'short');
        await tester.enterText(textFields.at(4), 'short');

        final registerButton = find.text('Register Account');
        await tester.ensureVisible(registerButton);
        await tester.tap(registerButton);
        await tester.pumpAndSettle();

        expect(
          find.text('Password must be at least 8 characters'),
          findsOneWidget,
        );
        expect(mockApi.postCalls.isEmpty, isTrue);
      },
    );

    testWidgets('shows validation error when passwords do not match', (
      tester,
    ) async {
      final mockApi = MockRegisterApiService();
      await tester.pumpWidget(buildTestWidget(mockApi));

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'johndoe');
      await tester.enterText(textFields.at(1), 'john@example.com');
      await tester.enterText(textFields.at(2), '+1234567890');
      await tester.enterText(textFields.at(3), 'ValidPassword123!');
      await tester.enterText(textFields.at(4), 'DifferentPassword456!');

      final registerButton = find.text('Register Account');
      await tester.ensureVisible(registerButton);
      await tester.tap(registerButton);
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(mockApi.postCalls.isEmpty, isTrue);
    });

    testWidgets(
      'submits all required fields including password2 matching backend contract',
      (tester) async {
        final mockApi = MockRegisterApiService();
        await tester.pumpWidget(buildTestWidget(mockApi));

        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.at(0), 'johndoe');
        await tester.enterText(textFields.at(1), 'john@example.com');
        await tester.enterText(textFields.at(2), '+1234567890');
        await tester.enterText(textFields.at(3), 'ValidPassword123!');
        await tester.enterText(textFields.at(4), 'ValidPassword123!');

        final registerButton = find.text('Register Account');
        await tester.ensureVisible(registerButton);
        await tester.tap(registerButton);
        await tester.pumpAndSettle();

        expect(mockApi.postCalls.length, 1);
        expect(mockApi.postCalls.first, AppConstants.registerEndpoint);

        final payload = mockApi.postData.first as Map<String, dynamic>;
        expect(payload['username'], 'johndoe');
        expect(payload['email'], 'john@example.com');
        expect(payload['password'], 'ValidPassword123!');
        expect(payload['password2'], 'ValidPassword123!');
        expect(payload['phone'], '+1234567890');
        expect(payload['role'], 'student');
      },
    );

    testWidgets('displays backend validation error banner on 400 Bad Request', (
      tester,
    ) async {
      final mockApi = MockRegisterApiService(
        postResponses: {
          AppConstants.registerEndpoint: ApiException(
            'username: A user with that username already exists.',
            statusCode: 400,
          ),
        },
      );

      await tester.pumpWidget(buildTestWidget(mockApi));

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'existinguser');
      await tester.enterText(textFields.at(1), 'user@example.com');
      await tester.enterText(textFields.at(2), '+1234567890');
      await tester.enterText(textFields.at(3), 'ValidPassword123!');
      await tester.enterText(textFields.at(4), 'ValidPassword123!');

      final registerButton = find.text('Register Account');
      await tester.ensureVisible(registerButton);
      await tester.tap(registerButton);
      await tester.pumpAndSettle();

      expect(
        find.text('username: A user with that username already exists.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'displays backend mismatched passwords error banner on 400 Bad Request',
      (tester) async {
        final mockApi = MockRegisterApiService(
          postResponses: {
            AppConstants.registerEndpoint: ApiException(
              'password: Passwords do not match.',
              statusCode: 400,
            ),
          },
        );

        await tester.pumpWidget(buildTestWidget(mockApi));

        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.at(0), 'newuser');
        await tester.enterText(textFields.at(1), 'user@example.com');
        await tester.enterText(textFields.at(2), '+1234567890');
        await tester.enterText(textFields.at(3), 'ValidPassword123!');
        await tester.enterText(textFields.at(4), 'ValidPassword123!');

        final registerButton = find.text('Register Account');
        await tester.ensureVisible(registerButton);
        await tester.tap(registerButton);
        await tester.pumpAndSettle();

        expect(find.text('password: Passwords do not match.'), findsOneWidget);
      },
    );
  });
}
