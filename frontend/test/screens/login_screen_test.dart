import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/user_profile_model.dart';
import 'package:frontend/navigation/app_router.dart';
import 'package:frontend/screens/auth/login_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/profile_service.dart';
import 'package:frontend/services/storage_service.dart';

class MockLoginApiService extends ApiService {
  final Map<String, dynamic>? customResponse;
  final Exception? errorToThrow;

  MockLoginApiService({this.customResponse, this.errorToThrow});

  @override
  Future<Response<dynamic>> post(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    return Response(
      requestOptions: RequestOptions(path: endpoint),
      data: customResponse ??
          {
            'access': 'mock_access_token_123',
            'refresh': 'mock_refresh_token_456',
          },
      statusCode: 200,
    );
  }
}

class MockStorageService extends StorageService {
  String? accessToken;
  String? refreshToken;
  bool cleared = false;

  @override
  Future<void> saveAccessToken(String token) async => accessToken = token;
  @override
  Future<String?> getAccessToken() async => accessToken;
  @override
  Future<void> saveRefreshToken(String token) async => refreshToken = token;
  @override
  Future<String?> getRefreshToken() async => refreshToken;
  @override
  Future<void> clearTokens() async {
    accessToken = null;
    refreshToken = null;
    cleared = true;
  }
}

class MockProfileService extends ProfileService {
  final UserProfileModel profile;
  MockProfileService(this.profile);

  @override
  Future<UserProfileModel> getProfile() async => profile;
}

void main() {
  group('LoginScreen Widget & Admin Authentication Tests', () {
    Widget buildTestWidget({
      bool initialAdminMode = false,
      ApiService? apiService,
      StorageService? storageService,
      ProfileService? profileService,
      NavigatorObserver? observer,
    }) {
      return MaterialApp(
        navigatorObservers: observer != null ? [observer] : [],
        routes: {
          AppRouter.home: (_) => const Scaffold(body: Text('Home Screen')),
          AppRouter.admin: (_) => const Scaffold(body: Text('Admin Dashboard Screen')),
          AppRouter.register: (_) => const Scaffold(body: Text('Register Screen')),
        },
        home: LoginScreen(
          initialAdminMode: initialAdminMode,
          apiService: apiService ?? MockLoginApiService(),
          storageService: storageService ?? MockStorageService(),
          profileService: profileService,
        ),
      );
    }

    testWidgets('renders user login mode with Admin Login button by default', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Sign in to continue your skill exchange journey'), findsOneWidget);
      expect(find.text('Username or Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Register'), findsOneWidget);

      // Verify clearly visible Admin Login button exists
      expect(find.byKey(const ValueKey('admin_login_mode_button')), findsOneWidget);
      expect(find.text('Admin Login'), findsOneWidget);
      expect(find.byIcon(Icons.admin_panel_settings_rounded), findsOneWidget);
    });

    testWidgets('tapping Admin Login switches into dedicated Admin Portal mode', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      // Scroll to and tap Admin Login
      await tester.ensureVisible(find.byKey(const ValueKey('admin_login_mode_button')));
      await tester.tap(find.byKey(const ValueKey('admin_login_mode_button')));
      await tester.pumpAndSettle();

      // Header changes to Admin Portal
      expect(find.text('Admin Portal'), findsOneWidget);
      expect(find.text('Sign in with elevated administrator credentials'), findsOneWidget);
      expect(find.text('Authorized Personnel Only'), findsOneWidget);
      expect(find.text('Sign In as Admin'), findsOneWidget);
      expect(find.byKey(const ValueKey('switch_to_user_login_button')), findsOneWidget);

      // Scroll to and tap Back to User Login
      await tester.ensureVisible(find.byKey(const ValueKey('switch_to_user_login_button')));
      await tester.tap(find.byKey(const ValueKey('switch_to_user_login_button')));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Admin Login'), findsOneWidget);
    });

    testWidgets('Admin login successfully verifies admin and redirects to /admin', (
      tester,
    ) async {
      final mockStorage = MockStorageService();
      final adminProfile = UserProfileModel(
        username: 'lavanya',
        email: 'lavanya@example.com',
        phone: '1234567890',
        bio: 'Super admin',
        role: 'student',
        isSuperuser: true,
        isStaff: true,
      );

      await tester.pumpWidget(
        buildTestWidget(
          initialAdminMode: true,
          storageService: mockStorage,
          profileService: MockProfileService(adminProfile),
        ),
      );

      // Enter credentials
      await tester.enterText(find.byType(TextFormField).at(0), 'lavanya');
      await tester.enterText(find.byType(TextFormField).at(1), 'secureadminpass');

      // Tap Sign In as Admin
      await tester.tap(find.byKey(const ValueKey('admin_submit_button')));
      await tester.pumpAndSettle();

      // Navigated to Admin Dashboard
      expect(find.text('Admin Dashboard Screen'), findsOneWidget);
      expect(mockStorage.accessToken, equals('mock_access_token_123'));
    });

    testWidgets('Admin login rejects normal student account, clears tokens and displays Access Denied', (
      tester,
    ) async {
      final mockStorage = MockStorageService();
      final studentProfile = UserProfileModel(
        username: 'student_bob',
        email: 'bob@example.com',
        phone: '1234567890',
        bio: 'Just a student',
        role: 'student',
        isAdmin: false,
        isStaff: false,
        isSuperuser: false,
      );

      await tester.pumpWidget(
        buildTestWidget(
          initialAdminMode: true,
          storageService: mockStorage,
          profileService: MockProfileService(studentProfile),
        ),
      );

      // Enter credentials
      await tester.enterText(find.byType(TextFormField).at(0), 'student_bob');
      await tester.enterText(find.byType(TextFormField).at(1), 'studentpass123');

      // Tap Sign In as Admin
      await tester.tap(find.byKey(const ValueKey('admin_submit_button')));
      await tester.pumpAndSettle();

      // Must NOT navigate to Admin Dashboard
      expect(find.text('Admin Dashboard Screen'), findsNothing);

      // Tokens MUST be cleared
      expect(mockStorage.cleared, isTrue);
      expect(mockStorage.accessToken, isNull);

      // Error banner must be displayed
      expect(
        find.textContaining('Access Denied: This account (student_bob) does not have administrator privileges.'),
        findsOneWidget,
      );
    });

    testWidgets('Normal user login redirects to /home', (tester) async {
      final mockStorage = MockStorageService();

      await tester.pumpWidget(
        buildTestWidget(
          initialAdminMode: false,
          storageService: mockStorage,
        ),
      );

      // Enter credentials
      await tester.enterText(find.byType(TextFormField).at(0), 'normaluser');
      await tester.enterText(find.byType(TextFormField).at(1), 'userpass123');

      // Tap Login
      await tester.tap(find.byKey(const ValueKey('user_submit_button')));
      await tester.pumpAndSettle();

      // Navigated to Home Screen
      expect(find.text('Home Screen'), findsOneWidget);
      expect(mockStorage.accessToken, equals('mock_access_token_123'));
    });
  });
}
