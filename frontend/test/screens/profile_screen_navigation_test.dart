import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/navigation/app_router.dart';
import 'package:frontend/screens/profile/profile_screen.dart';

void main() {
  testWidgets(
    'tapping Account Settings in ProfileScreen navigates to /account-settings route',
    (tester) async {
      String? navigatedRoute;

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            navigatedRoute = settings.name;
            if (settings.name == AppRouter.profile) {
              return MaterialPageRoute(builder: (_) => const ProfileScreen());
            }
            return MaterialPageRoute(
              builder: (_) =>
                  Scaffold(body: Text('Destination: ${settings.name}')),
            );
          },
          initialRoute: AppRouter.profile,
        ),
      );

      await tester.pumpAndSettle();

      final accountSettingsTile = find.text('Account Settings');
      expect(accountSettingsTile, findsOneWidget);

      await tester.tap(accountSettingsTile);
      await tester.pumpAndSettle();

      expect(navigatedRoute, equals(AppRouter.accountSettings));
      expect(find.text('Destination: /account-settings'), findsOneWidget);
    },
  );
}
