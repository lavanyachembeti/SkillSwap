import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/user_profile_model.dart';
import 'package:frontend/screens/profile/account_settings_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/profile_service.dart';

class MockProfileService extends ProfileService {
  UserProfileModel profile;
  bool shouldFailGet;
  bool shouldFailUpdate;
  String errorMessage;
  int updateCallCount = 0;
  Map<String, String>? lastUpdateArgs;

  MockProfileService({
    required this.profile,
    this.shouldFailGet = false,
    this.shouldFailUpdate = false,
    this.errorMessage = 'An error occurred',
  });

  @override
  Future<UserProfileModel> getProfile() async {
    if (shouldFailGet) {
      throw ApiException(errorMessage);
    }
    return profile;
  }

  @override
  Future<UserProfileModel> updateProfile({
    required String email,
    required String phone,
    required String bio,
  }) async {
    updateCallCount++;
    lastUpdateArgs = {'email': email, 'phone': phone, 'bio': bio};
    if (shouldFailUpdate) {
      throw ApiException(errorMessage);
    }
    profile = profile.copyWith(email: email, phone: phone, bio: bio);
    return profile;
  }
}

void main() {
  group('AccountSettingsScreen Widget Tests', () {
    late UserProfileModel testProfile;

    setUp(() {
      testProfile = UserProfileModel(
        id: 1,
        username: 'alex_dev',
        email: 'alex@example.com',
        phone: '+1234567890',
        bio: 'Mobile and backend engineer',
        role: 'professional',
      );
    });

    Widget createWidgetUnderTest(ProfileService service) {
      return MaterialApp(home: AccountSettingsScreen(profileService: service));
    }

    testWidgets('displays loaded profile information and read-only fields', (
      tester,
    ) async {
      final mockService = MockProfileService(profile: testProfile);

      await tester.pumpWidget(createWidgetUnderTest(mockService));
      await tester.pumpAndSettle();

      // Verify AppBar
      expect(find.text('Account Settings'), findsOneWidget);

      // Verify username and role exist
      expect(find.text('alex_dev'), findsWidgets);
      expect(find.text('Professional'), findsWidgets);

      // Verify editable fields have loaded initial values
      expect(find.text('alex@example.com'), findsWidgets);
      expect(find.text('+1234567890'), findsOneWidget);
      expect(find.text('Mobile and backend engineer'), findsOneWidget);

      // Verify Save Changes button exists
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets(
      'displays error state when loading profile fails, and retries successfully',
      (tester) async {
        final mockService = MockProfileService(
          profile: testProfile,
          shouldFailGet: true,
          errorMessage: 'Network timeout',
        );

        await tester.pumpWidget(createWidgetUnderTest(mockService));
        await tester.pumpAndSettle();

        expect(find.text('Unable to Load Settings'), findsOneWidget);
        expect(find.text('Network timeout'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        // Now set failure to false and click retry
        mockService.shouldFailGet = false;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(find.text('alex_dev'), findsWidgets);
        expect(find.text('Save Changes'), findsOneWidget);
      },
    );

    testWidgets('validates required email and phone fields before submitting', (
      tester,
    ) async {
      final mockService = MockProfileService(profile: testProfile);

      await tester.pumpWidget(createWidgetUnderTest(mockService));
      await tester.pumpAndSettle();

      // Find the email TextFormField (index 2: username=0, role=1, email=2, phone=3, bio=4)
      final emailField = find.byType(TextFormField).at(2);
      await tester.enterText(emailField, '');

      // Ensure button is scrolled into view and tap Save Changes
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(mockService.updateCallCount, equals(0));

      // Enter invalid email
      await tester.enterText(emailField, 'not-an-email');
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(mockService.updateCallCount, equals(0));

      // Fix email, clear phone
      await tester.enterText(emailField, 'valid@example.com');
      final phoneField = find.byType(TextFormField).at(3);
      await tester.enterText(phoneField, '');
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('Phone number is required'), findsOneWidget);
      expect(mockService.updateCallCount, equals(0));
    });

    testWidgets('submits updated profile and displays success message', (
      tester,
    ) async {
      final mockService = MockProfileService(profile: testProfile);

      await tester.pumpWidget(createWidgetUnderTest(mockService));
      await tester.pumpAndSettle();

      // Update email
      final emailField = find.byType(TextFormField).at(2);
      await tester.enterText(emailField, 'alex_updated@example.com');

      // Update phone
      final phoneField = find.byType(TextFormField).at(3);
      await tester.enterText(phoneField, '+9876543210');

      // Update bio
      final bioField = find.byType(TextFormField).at(4);
      await tester.enterText(bioField, 'Updated bio text');

      // Ensure button is scrolled into view and tap Save Changes
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(mockService.updateCallCount, equals(1));
      expect(
        mockService.lastUpdateArgs,
        equals({
          'email': 'alex_updated@example.com',
          'phone': '+9876543210',
          'bio': 'Updated bio text',
        }),
      );

      // Verify success snackbar
      expect(find.text('Profile updated successfully!'), findsOneWidget);
    });

    testWidgets('shows error banner when updating profile fails', (
      tester,
    ) async {
      final mockService = MockProfileService(
        profile: testProfile,
        shouldFailUpdate: true,
        errorMessage: 'Email is already in use.',
      );

      await tester.pumpWidget(createWidgetUnderTest(mockService));
      await tester.pumpAndSettle();

      // Ensure button is scrolled into view and tap Save Changes
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(mockService.updateCallCount, equals(1));
      expect(find.text('Email is already in use.'), findsOneWidget);
    });
  });
}
