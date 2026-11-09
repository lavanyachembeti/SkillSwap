import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/navigation/app_router.dart';

void main() {
  group('AppRouter Route Generation Tests', () {
    test(
      'onGenerateRoute returns MaterialPageRoute with AccountSettingsScreen',
      () {
        final route = AppRouter.onGenerateRoute(
          const RouteSettings(name: AppRouter.accountSettings),
        );

        expect(route, isA<MaterialPageRoute>());
        expect(route.settings.name, equals(AppRouter.accountSettings));
      },
    );

    test('onGenerateRoute resolves /account-settings/ with trailing slash', () {
      final route = AppRouter.onGenerateRoute(
        const RouteSettings(name: '/account-settings/'),
      );

      expect(route, isA<MaterialPageRoute>());
    });

    test('onGenerateRoute resolves account-settings without leading slash', () {
      final route = AppRouter.onGenerateRoute(
        const RouteSettings(name: 'account-settings'),
      );

      expect(route, isA<MaterialPageRoute>());
    });

    test('onGenerateRoute returns MaterialPageRoute for AppRouter.admin', () {
      final route = AppRouter.onGenerateRoute(
        const RouteSettings(name: AppRouter.admin),
      );

      expect(route, isA<MaterialPageRoute>());
      expect(route.settings.name, equals(AppRouter.admin));
    });

    test('onGenerateRoute returns MaterialPageRoute for AppRouter.adminLogin', () {
      final route = AppRouter.onGenerateRoute(
        const RouteSettings(name: AppRouter.adminLogin),
      );

      expect(route, isA<MaterialPageRoute>());
      expect(route.settings.name, equals(AppRouter.adminLogin));
    });

    test('onGenerateRoute resolves all admin subroutes', () {
      final adminSubroutes = [
        AppRouter.adminUsers,
        AppRouter.adminSkills,
        AppRouter.adminRequests,
        AppRouter.adminChat,
        AppRouter.adminReports,
        AppRouter.adminAuditLogs,
        AppRouter.adminMessagingPolicies,
        AppRouter.adminSettings,
      ];

      for (final name in adminSubroutes) {
        final route = AppRouter.onGenerateRoute(RouteSettings(name: name));
        expect(route, isA<MaterialPageRoute>());
        expect(route.settings.name, equals(name));
      }
    });
  });
}
