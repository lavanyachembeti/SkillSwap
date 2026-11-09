import 'package:flutter/material.dart';

import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/discover/discover_screen.dart';
import '../screens/requests/requests_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/skills/skills_teach_screen.dart';
import '../screens/skills/skills_learn_screen.dart';
import '../screens/profile/account_settings_screen.dart';

import '../screens/requests/send_request_screen.dart';
import '../models/discover_user_model.dart';
import '../screens/admin/admin_dashboard_screen.dart';

class AppRouter {
  AppRouter._();

  static const String splash = '/splash';
  static const String login = '/login';
  static const String adminLogin = '/admin/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String admin = '/admin';
  static const String adminUsers = '/admin/users';
  static const String adminSkills = '/admin/skills';
  static const String adminRequests = '/admin/requests';
  static const String adminChat = '/admin/chat';
  static const String adminReports = '/admin/reports';
  static const String adminAuditLogs = '/admin/audit-logs';
  static const String adminMessagingPolicies = '/admin/messaging-policies';
  static const String adminSettings = '/admin/settings';
  static const String discover = '/discover';
  static const String requests = '/requests';
  static const String sendRequest = '/requests/send';
  static const String chat = '/chat';
  static const String profile = '/profile';
  static const String accountSettings = '/account-settings';
  static const String skillsTeach = '/skills/teach';
  static const String skillsLearn = '/skills/learn';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final rawName = settings.name;
    final normalizedName = rawName == null
        ? null
        : (rawName.endsWith('/') && rawName.length > 1
              ? rawName.substring(0, rawName.length - 1)
              : rawName);

    switch (normalizedName) {
      case splash:
      case 'splash':
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      case login:
      case 'login':
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
      case adminLogin:
      case 'admin/login':
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(initialAdminMode: true),
          settings: settings,
        );
      case admin:
      case 'admin':
      case '/admin/overview':
      case 'admin/overview':
        return MaterialPageRoute(
          builder: (_) => const AdminDashboardScreen(
            initialSection: AdminPortalSection.overview,
          ),
          settings: settings,
        );
      case adminUsers:
      case 'admin/users':
        return MaterialPageRoute(
          builder: (_) => const AdminDashboardScreen(
            initialSection: AdminPortalSection.users,
          ),
          settings: settings,
        );
      case adminSkills:
      case 'admin/skills':
        return MaterialPageRoute(
          builder: (_) => const AdminDashboardScreen(
            initialSection: AdminPortalSection.skills,
          ),
          settings: settings,
        );
      case adminRequests:
      case 'admin/requests':
        return MaterialPageRoute(
          builder: (_) => const AdminDashboardScreen(
            initialSection: AdminPortalSection.requests,
          ),
          settings: settings,
        );
      case adminChat:
      case 'admin/chat':
        return MaterialPageRoute(
          builder: (_) => const AdminDashboardScreen(
            initialSection: AdminPortalSection.chat,
          ),
          settings: settings,
        );
      case adminReports:
      case 'admin/reports':
        return MaterialPageRoute(
          builder: (_) => const AdminDashboardScreen(
            initialSection: AdminPortalSection.reports,
          ),
          settings: settings,
        );
      case adminAuditLogs:
      case 'admin/audit-logs':
        return MaterialPageRoute(
          builder: (_) => const AdminDashboardScreen(
            initialSection: AdminPortalSection.auditLogs,
          ),
          settings: settings,
        );
      case adminMessagingPolicies:
      case 'admin/messaging-policies':
        return MaterialPageRoute(
          builder: (_) => const AdminDashboardScreen(
            initialSection: AdminPortalSection.messagingPolicies,
          ),
          settings: settings,
        );
      case adminSettings:
      case 'admin/settings':
        return MaterialPageRoute(
          builder: (_) => const AdminDashboardScreen(
            initialSection: AdminPortalSection.adminSettings,
          ),
          settings: settings,
        );
      case register:
      case 'register':
        return MaterialPageRoute(
          builder: (_) => const RegisterScreen(),
          settings: settings,
        );
      case home:
      case 'home':
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );
      case discover:
      case 'discover':
        return MaterialPageRoute(
          builder: (_) => const DiscoverScreen(),
          settings: settings,
        );
      case requests:
      case 'requests':
        return MaterialPageRoute(
          builder: (_) => const RequestsScreen(),
          settings: settings,
        );
      case sendRequest:
      case 'requests/send':
        final user = settings.arguments as DiscoverUserModel?;
        if (user != null) {
          return MaterialPageRoute(
            builder: (_) => SendRequestScreen(targetUser: user),
            settings: settings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => const DiscoverScreen(),
          settings: settings,
        );
      case chat:
      case 'chat':
        final chatArgs = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ChatScreen(
            peerUserId: chatArgs?['peerUserId'] as int?,
            peerName: chatArgs?['peerName'] as String?,
            peerSkill: chatArgs?['peerSkill'] as String?,
          ),
          settings: settings,
        );
      case profile:
      case 'profile':
        return MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
          settings: settings,
        );
      case accountSettings:
      case 'account-settings':
        return MaterialPageRoute(
          builder: (_) => const AccountSettingsScreen(),
          settings: settings,
        );
      case skillsTeach:
      case 'skills/teach':
        return MaterialPageRoute(
          builder: (_) => const SkillsTeachScreen(),
          settings: settings,
        );
      case skillsLearn:
      case 'skills/learn':
        return MaterialPageRoute(
          builder: (_) => const SkillsLearnScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
    }
  }
}
