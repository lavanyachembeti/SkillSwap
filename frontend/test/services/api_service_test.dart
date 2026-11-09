import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/app_constants.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/storage_service.dart';

class TestHttpClientAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  TestHttpClientAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

class FakeStorageService extends StorageService {
  final Map<String, String> storage = {};

  FakeStorageService({Map<String, String>? initial}) {
    if (initial != null) {
      storage.addAll(initial);
    }
  }

  @override
  Future<void> saveAccessToken(String token) async {
    storage[AppConstants.accessTokenKey] = token;
  }

  @override
  Future<String?> getAccessToken() async {
    return storage[AppConstants.accessTokenKey];
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    storage[AppConstants.refreshTokenKey] = token;
  }

  @override
  Future<String?> getRefreshToken() async {
    return storage[AppConstants.refreshTokenKey];
  }

  @override
  Future<void> clearTokens() async {
    storage.remove(AppConstants.accessTokenKey);
    storage.remove(AppConstants.refreshTokenKey);
  }
}

ResponseBody createJsonResponse(dynamic body, int statusCode) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  group('ApiService JWT Token Refresh Tests', () {
    test(
      'refreshes token on 401, updates storage, and retries original request',
      () async {
        final fakeStorage = FakeStorageService(
          initial: {
            AppConstants.accessTokenKey: 'expired_access_token',
            AppConstants.refreshTokenKey: 'valid_refresh_token',
          },
        );

        int mainCallCount = 0;
        final List<String?> receivedAuthHeaders = [];
        final mainDio = Dio();
        mainDio.httpClientAdapter = TestHttpClientAdapter((options) async {
          mainCallCount++;
          receivedAuthHeaders.add(options.headers['Authorization'] as String?);

          if (mainCallCount == 1) {
            return createJsonResponse({
              'detail': 'Token is invalid or expired',
            }, 401);
          }

          return createJsonResponse({'message': 'Success'}, 200);
        });

        int refreshCallCount = 0;
        final refreshDio = Dio();
        refreshDio.httpClientAdapter = TestHttpClientAdapter((options) async {
          refreshCallCount++;
          expect(options.path, AppConstants.refreshEndpoint);
          return createJsonResponse({
            'access': 'fresh_access_token',
            'refresh': 'rotated_refresh_token',
          }, 200);
        });

        final apiService = ApiService(
          storageService: fakeStorage,
          dio: mainDio,
          refreshDio: refreshDio,
        );

        final response = await apiService.get('/api/skills/');

        expect(response.statusCode, 200);
        expect(response.data['message'], 'Success');

        expect(mainCallCount, 2);
        expect(refreshCallCount, 1);
        expect(receivedAuthHeaders[0], 'Bearer expired_access_token');
        expect(receivedAuthHeaders[1], 'Bearer fresh_access_token');

        expect(
          fakeStorage.storage[AppConstants.accessTokenKey],
          'fresh_access_token',
        );
        expect(
          fakeStorage.storage[AppConstants.refreshTokenKey],
          'rotated_refresh_token',
        );
      },
    );

    test('clears storage and throws ApiException when refresh token is rejected (401)', () async {
      final fakeStorage = FakeStorageService(
        initial: {
          AppConstants.accessTokenKey: 'expired_access_token',
          AppConstants.refreshTokenKey: 'expired_refresh_token',
        },
      );

      final mainDio = Dio();
      mainDio.httpClientAdapter = TestHttpClientAdapter((options) async {
        return createJsonResponse({'detail': 'Token expired'}, 401);
      });

      int refreshCallCount = 0;
      final refreshDio = Dio();
      refreshDio.httpClientAdapter = TestHttpClientAdapter((options) async {
        refreshCallCount++;
        return createJsonResponse({'detail': 'Refresh token is expired'}, 401);
      });

      final apiService = ApiService(
        storageService: fakeStorage,
        dio: mainDio,
        refreshDio: refreshDio,
      );

      await expectLater(
        apiService.get('/api/skills/'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );

      expect(refreshCallCount, 1);
      expect(fakeStorage.storage.isEmpty, isTrue);
    });

    test(
      'clears storage and throws ApiException when refresh token is missing',
      () async {
        final fakeStorage = FakeStorageService(
          initial: {AppConstants.accessTokenKey: 'expired_access_token'},
        );

        final mainDio = Dio();
        mainDio.httpClientAdapter = TestHttpClientAdapter((options) async {
          return createJsonResponse({
            'detail': 'Authentication credentials were not provided.',
          }, 401);
        });

        int refreshCallCount = 0;
        final refreshDio = Dio();
        refreshDio.httpClientAdapter = TestHttpClientAdapter((options) async {
          refreshCallCount++;
          return createJsonResponse({}, 200);
        });

        final apiService = ApiService(
          storageService: fakeStorage,
          dio: mainDio,
          refreshDio: refreshDio,
        );

        await expectLater(
          apiService.get('/api/skills/'),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
          ),
        );

        expect(refreshCallCount, 0);
        expect(fakeStorage.storage.isEmpty, isTrue);
      },
    );

    test(
      'excludes login and register endpoints from automatic refresh',
      () async {
        final fakeStorage = FakeStorageService(
          initial: {AppConstants.refreshTokenKey: 'some_refresh_token'},
        );

        final mainDio = Dio();
        mainDio.httpClientAdapter = TestHttpClientAdapter((options) async {
          return createJsonResponse({
            'detail': 'No active account found with the given credentials',
          }, 401);
        });

        int refreshCallCount = 0;
        final refreshDio = Dio();
        refreshDio.httpClientAdapter = TestHttpClientAdapter((options) async {
          refreshCallCount++;
          return createJsonResponse({}, 200);
        });

        final apiService = ApiService(
          storageService: fakeStorage,
          dio: mainDio,
          refreshDio: refreshDio,
        );

        await expectLater(
          apiService.post(
            AppConstants.loginEndpoint,
            data: {'username': 'u', 'password': 'p'},
          ),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
          ),
        );

        await expectLater(
          apiService.post(AppConstants.registerEndpoint, data: {}),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
          ),
        );

        expect(refreshCallCount, 0);
      },
    );

    test(
      'prevents infinite retry loops when retried request returns 401',
      () async {
        final fakeStorage = FakeStorageService(
          initial: {
            AppConstants.accessTokenKey: 'token_1',
            AppConstants.refreshTokenKey: 'refresh_1',
          },
        );

        int mainCallCount = 0;
        final mainDio = Dio();
        mainDio.httpClientAdapter = TestHttpClientAdapter((options) async {
          mainCallCount++;
          return createJsonResponse({'detail': 'Unauthorized'}, 401);
        });

        int refreshCallCount = 0;
        final refreshDio = Dio();
        refreshDio.httpClientAdapter = TestHttpClientAdapter((options) async {
          refreshCallCount++;
          return createJsonResponse({'access': 'token_2'}, 200);
        });

        final apiService = ApiService(
          storageService: fakeStorage,
          dio: mainDio,
          refreshDio: refreshDio,
        );

        await expectLater(
          apiService.get('/api/skills/'),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
          ),
        );

        // First attempt (401) + One retry attempt (401) = 2 calls
        expect(mainCallCount, 2);
        expect(refreshCallCount, 1);
      },
    );

    test(
      'handles concurrent 401 responses safely with a single refresh call',
      () async {
        final fakeStorage = FakeStorageService(
          initial: {
            AppConstants.accessTokenKey: 'expired_token',
            AppConstants.refreshTokenKey: 'valid_refresh',
          },
        );

        int mainCallCount = 0;
        final mainDio = Dio();
        mainDio.httpClientAdapter = TestHttpClientAdapter((options) async {
          mainCallCount++;
          final authHeader = options.headers['Authorization'] as String?;
          if (authHeader == 'Bearer fresh_token') {
            return createJsonResponse({
              'status': 'ok',
              'path': options.path,
            }, 200);
          }
          return createJsonResponse({'detail': 'Token expired'}, 401);
        });

        int refreshCallCount = 0;
        final refreshDio = Dio();
        refreshDio.httpClientAdapter = TestHttpClientAdapter((options) async {
          refreshCallCount++;
          // Small delay to simulate real network latency
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return createJsonResponse({'access': 'fresh_token'}, 200);
        });

        final apiService = ApiService(
          storageService: fakeStorage,
          dio: mainDio,
          refreshDio: refreshDio,
        );

        // Launch two requests concurrently
        final future1 = apiService.get('/api/skills/');
        final future2 = apiService.get('/api/requests/');

        final results = await Future.wait([future1, future2]);

        expect(results[0].statusCode, 200);
        expect(results[1].statusCode, 200);

        // Exactly 1 refresh call should have been made
        expect(refreshCallCount, 1);
        expect(mainCallCount, 4);
        expect(fakeStorage.storage[AppConstants.accessTokenKey], 'fresh_token');
      },
    );
  });
}
