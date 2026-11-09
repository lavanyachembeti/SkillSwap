import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../models/user_profile_model.dart';
import '../../services/api_service.dart';
import '../../services/profile_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../navigation/app_router.dart';

class LoginScreen extends StatefulWidget {
  final bool initialAdminMode;
  final ApiService? apiService;
  final StorageService? storageService;
  final ProfileService? profileService;

  const LoginScreen({
    super.key,
    this.initialAdminMode = false,
    this.apiService,
    this.storageService,
    this.profileService,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late final ApiService _apiService;
  late final StorageService _storageService;
  late final ProfileService _profileService;

  late bool _isAdminMode;
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isAdminMode = widget.initialAdminMode;
    _apiService = widget.apiService ?? ApiService();
    _storageService = widget.storageService ?? StorageService();
    _profileService = widget.profileService ?? ProfileService(apiService: _apiService);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final usernameInput = _usernameController.text.trim();
      final passwordInput = _passwordController.text;

      final response = await _apiService.post(
        AppConstants.loginEndpoint,
        data: {
          'username': usernameInput,
          'password': passwordInput,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        // Extract access token
        final accessToken = data['access'] ?? data['token'] ?? data['access_token'];
        final refreshToken = data['refresh'] ?? data['refresh_token'];

        if (accessToken != null && accessToken is String) {
          await _storageService.saveAccessToken(accessToken);
          if (refreshToken != null && refreshToken is String) {
            await _storageService.saveRefreshToken(refreshToken);
          }

          // If in Admin Login mode, verify admin permissions via backend profile API
          if (_isAdminMode) {
            final UserProfileModel profile = await _profileService.getProfile();
            if (profile.isAdministrator) {
              if (!mounted) return;
              Navigator.of(context).pushReplacementNamed(AppRouter.admin);
              return;
            } else {
              // Reject non-admin users and clear tokens
              await _storageService.clearTokens();
              if (!mounted) return;
              setState(() {
                _errorMessage =
                    'Access Denied: This account (${profile.username}) does not have administrator privileges. Please sign in using normal user login.';
              });
              return;
            }
          }

          // Normal user login redirection
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed(AppRouter.home);
          return;
        }
      }

      setState(() {
        _errorMessage = 'Invalid response format from server.';
      });
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Icon / Logo
                  Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isAdminMode
                            ? const Color(0xFF312E81)
                            : theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: _isAdminMode
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : null,
                      ),
                      child: Icon(
                        _isAdminMode
                            ? Icons.admin_panel_settings_rounded
                            : Icons.swap_calls_rounded,
                        size: 44,
                        color: _isAdminMode
                            ? const Color(0xFF818CF8)
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Header Titles
                  Text(
                    _isAdminMode ? 'Admin Portal' : 'Welcome Back',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isAdminMode
                        ? 'Sign in with elevated administrator credentials'
                        : 'Sign in to continue your skill exchange journey',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  if (_isAdminMode) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.security_rounded, size: 16, color: Color(0xFFB45309)),
                            SizedBox(width: 6),
                            Text(
                              'Authorized Personnel Only',
                              style: TextStyle(
                                color: Color(0xFF92400E),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),

                  // Error Message Banner
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFF991B1B),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Username / Email Input
                  CustomTextField(
                    controller: _usernameController,
                    label: _isAdminMode ? 'Admin Username or Email' : 'Username or Email',
                    hint: _isAdminMode ? 'Enter your admin username' : 'Enter your username or email',
                    prefixIcon: _isAdminMode ? Icons.badge_outlined : Icons.person_outline_rounded,
                    enabled: !_isLoading,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your username or email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Password Input
                  CustomTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: 'Enter your password',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: !_isPasswordVisible,
                    enabled: !_isLoading,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF64748B),
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),

                  // Login Button
                  PrimaryButton(
                    key: ValueKey(_isAdminMode ? 'admin_submit_button' : 'user_submit_button'),
                    text: _isAdminMode ? 'Sign In as Admin' : 'Login',
                    onPressed: _isLoading ? null : _handleLogin,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 24),

                  // Mode-Specific Footer Actions
                  if (!_isAdminMode) ...[
                    // Register Redirection Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () {
                                  Navigator.of(context).pushNamed(AppRouter.register);
                                },
                          child: Text(
                            'Register',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Divider
                    const Row(
                      children: [
                        Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Prominent Admin Login Button
                    OutlinedButton.icon(
                      key: const ValueKey('admin_login_mode_button'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: const Color(0xFFEEF2FF),
                      ),
                      icon: const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Color(0xFF4F46E5),
                        size: 20,
                      ),
                      label: const Text(
                        'Admin Login',
                        style: TextStyle(
                          color: Color(0xFF4F46E5),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _isAdminMode = true;
                                _errorMessage = null;
                              });
                            },
                    ),
                  ] else ...[
                    // Back to User Login Button
                    TextButton.icon(
                      key: const ValueKey('switch_to_user_login_button'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                      label: const Text(
                        'Back to User Login',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _isAdminMode = false;
                                _errorMessage = null;
                              });
                            },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
