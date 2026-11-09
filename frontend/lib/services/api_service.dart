import 'dart:async';
import 'package:dio/dio.dart';
import '../core/constants/app_constants.dart';
import 'storage_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => message;
}

class ApiService {
  late final Dio _dio;
  late final Dio _refreshDio;
  final StorageService _storageService;
  Future<String?>? _refreshFuture;

  ApiService({
    StorageService? storageService,
    Dio? dio,
    Dio? refreshDio,
  })  : _storageService = storageService ?? StorageService() {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: AppConstants.baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

    _refreshDio = refreshDio ??
        Dio(
          BaseOptions(
            baseUrl: AppConstants.baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

    // Attach Interceptor for automatic Bearer Auth Header and 401 token refresh
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storageService.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException err, ErrorInterceptorHandler handler) async {
          if (err.response?.statusCode == 401) {
            final path = err.requestOptions.path;
            final isExcluded = path.contains(AppConstants.loginEndpoint) ||
                path.contains(AppConstants.registerEndpoint) ||
                path.contains(AppConstants.refreshEndpoint);

            final isAlreadyRetried =
                err.requestOptions.extra['isRetry'] == true;

            if (!isExcluded && !isAlreadyRetried) {
              final requestAuthHeader =
                  err.requestOptions.headers['Authorization'] as String?;
              final currentAccessToken =
                  await _storageService.getAccessToken();

              String? validToken;

              // If another concurrent request already refreshed the token
              if (currentAccessToken != null &&
                  currentAccessToken.isNotEmpty &&
                  requestAuthHeader != null &&
                  requestAuthHeader != 'Bearer $currentAccessToken') {
                validToken = currentAccessToken;
              } else {
                validToken = await _performTokenRefresh();
              }

              if (validToken != null && validToken.isNotEmpty) {
                try {
                  final options = Options(
                    method: err.requestOptions.method,
                    headers: Map<String, dynamic>.from(
                      err.requestOptions.headers,
                    )..['Authorization'] = 'Bearer $validToken',
                    responseType: err.requestOptions.responseType,
                    contentType: err.requestOptions.contentType,
                    validateStatus: err.requestOptions.validateStatus,
                    receiveTimeout: err.requestOptions.receiveTimeout,
                    sendTimeout: err.requestOptions.sendTimeout,
                    extra: Map<String, dynamic>.from(
                      err.requestOptions.extra,
                    )..['isRetry'] = true,
                  );

                  final retriedResponse = await _dio.request(
                    err.requestOptions.path,
                    data: err.requestOptions.data,
                    queryParameters: err.requestOptions.queryParameters,
                    options: options,
                  );

                  return handler.resolve(retriedResponse);
                } on DioException catch (retryErr) {
                  return handler.next(retryErr);
                } catch (_) {
                  return handler.next(err);
                }
              }
            }
          }

          return handler.next(err);
        },
      ),
    );
  }

  /// Thread-safe execution of token refresh ensuring concurrent 401s share a single call
  Future<String?> _performTokenRefresh() async {
    if (_refreshFuture != null) {
      return _refreshFuture;
    }
    _refreshFuture = _executeTokenRefresh();
    try {
      return await _refreshFuture;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<String?> _executeTokenRefresh() async {
    try {
      final refreshToken = await _storageService.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        await _storageService.clearTokens();
        return null;
      }

      final response = await _refreshDio.post(
        AppConstants.refreshEndpoint,
        data: {'refresh': refreshToken},
      );

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data is Map) {
        final data = response.data as Map;
        final newAccessToken = data['access']?.toString();
        final newRefreshToken = data['refresh']?.toString();

        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          await _storageService.saveAccessToken(newAccessToken);
          if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
            await _storageService.saveRefreshToken(newRefreshToken);
          }
          return newAccessToken;
        }
      }

      await _storageService.clearTokens();
      return null;
    } catch (_) {
      await _storageService.clearTokens();
      return null;
    }
  }

  /// POST request
  Future<Response> post(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.post(
        endpoint,
        data: data,
        queryParameters: queryParameters,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw ApiException(e.toString());
    }
  }

  /// GET request
  Future<Response> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParameters,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw ApiException(e.toString());
    }
  }

  /// PUT request
  Future<Response> put(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.put(
        endpoint,
        data: data,
        queryParameters: queryParameters,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw ApiException(e.toString());
    }
  }

  /// DELETE request
  Future<Response> delete(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.delete(
        endpoint,
        data: data,
        queryParameters: queryParameters,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw ApiException(e.toString());
    }
  }

  /// Private helper to parse and format Dio exceptions into user-friendly ApiExceptions
  ApiException _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          'Connection timeout. Please check your network or server status.',
        );

      case DioExceptionType.connectionError:
        return ApiException(
          'Unable to connect to SkillSwap backend (${AppConstants.baseUrl}). Please verify server is running.',
        );

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final data = error.response?.data;
        final message = _extractErrorMessage(data, statusCode);
        return ApiException(
          message,
          statusCode: statusCode,
          data: data,
        );

      case DioExceptionType.cancel:
        return ApiException('Request was cancelled.');

      default:
        return ApiException(
          error.message ?? 'An unexpected network error occurred.',
        );
    }
  }

  /// Helper to extract clean error message string from Django DRF JSON responses
  String _extractErrorMessage(dynamic data, int? statusCode) {
    if (data == null) {
      return 'Server error ($statusCode). Please try again.';
    }

    if (data is String) {
      if (data.isNotEmpty) return data;
      return 'Server error ($statusCode).';
    }

    if (data is Map) {
      // Common DRF error keys
      if (data.containsKey('detail')) {
        return data['detail'].toString();
      }
      if (data.containsKey('error')) {
        return data['error'].toString();
      }
      if (data.containsKey('message')) {
        return data['message'].toString();
      }
      if (data.containsKey('non_field_errors')) {
        final errors = data['non_field_errors'];
        if (errors is List && errors.isNotEmpty) {
          return errors.first.toString();
        }
      }

      // Collect field validation errors
      List<String> fieldErrors = [];
      data.forEach((key, value) {
        if (value is List && value.isNotEmpty) {
          fieldErrors.add('$key: ${value.first}');
        } else if (value is String) {
          fieldErrors.add('$key: $value');
        }
      });

      if (fieldErrors.isNotEmpty) {
        return fieldErrors.join('\n');
      }
    }

    return 'Request failed with status $statusCode.';
  }
}
