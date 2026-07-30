import 'dart:io';

import 'package:auth0_flutter/auth0_flutter.dart' hide ApiException;
import 'package:bjj_open_mat/core/api/friendly_error.dart';
import 'package:bjj_open_mat/core/data/api_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _response(int status) => DioException(
      requestOptions: RequestOptions(path: '/api/v1/auth/me'),
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/api/v1/auth/me'),
        statusCode: status,
      ),
    );

DioException _type(DioExceptionType type, {Object? error}) => DioException(
      requestOptions: RequestOptions(path: '/api/v1/open-mats'),
      type: type,
      error: error,
    );

void main() {
  group('friendlyErrorMessage', () {
    test('never leaks DioException internals to the user', () {
      final messages = <String>[
        friendlyErrorMessage(_response(401)),
        friendlyErrorMessage(_response(403)),
        friendlyErrorMessage(_response(404)),
        friendlyErrorMessage(_response(429)),
        friendlyErrorMessage(_response(500)),
        friendlyErrorMessage(_type(DioExceptionType.connectionError)),
        friendlyErrorMessage(_type(DioExceptionType.connectionTimeout)),
        friendlyErrorMessage(Exception('some internal blow-up')),
      ];

      for (final m in messages) {
        expect(m, isNot(contains('DioException')));
        expect(m, isNot(contains('RequestOptions')));
        expect(m, isNot(contains('validateStatus')));
        expect(m, isNot(contains('status code')));
        expect(m, isNot(contains('Exception')));
        // Descriptive, not a bare "Error".
        expect(m.length, greaterThan(15));
        expect(m.trim(), endsWith('.'));
      }
    });

    test('expired session reads as a sign-in prompt', () {
      expect(friendlyErrorMessage(_response(401)), contains('session'));
      expect(friendlyErrorMessage(_response(401)).toLowerCase(), contains('sign in'));
    });

    test('permission and missing-resource cases are distinguished', () {
      expect(friendlyErrorMessage(_response(403)).toLowerCase(), contains('permission'));
      expect(friendlyErrorMessage(_response(404)).toLowerCase(), contains("couldn't find"));
    });

    test('rate limiting tells the user to wait', () {
      expect(friendlyErrorMessage(_response(429)).toLowerCase(), contains('too many'));
    });

    test('server faults blame the service, not the user', () {
      final m = friendlyErrorMessage(_response(503)).toLowerCase();
      expect(m, contains('trouble'));
    });

    test('offline and timeout cases mention the connection', () {
      expect(
        friendlyErrorMessage(_type(DioExceptionType.connectionError)).toLowerCase(),
        contains('connection'),
      );
      expect(
        friendlyErrorMessage(_type(DioExceptionType.connectionTimeout)).toLowerCase(),
        contains('connection'),
      );
      expect(
        friendlyErrorMessage(_type(DioExceptionType.unknown, error: const SocketException('no route')))
            .toLowerCase(),
        contains('connection'),
      );
    });

    test('unknown failures fall back to a generic but polite message', () {
      expect(friendlyErrorMessage(Exception('boom')).toLowerCase(), contains('something went wrong'));
    });

    test('ApiException status codes map to the same strings as their Dio equivalents', () {
      const statuses = [401, 403, 404, 429, 500];
      for (final status in statuses) {
        final dioMessage = friendlyErrorMessage(_response(status));
        final apiMessage = friendlyErrorMessage(
          ApiException(code: 'error', message: 'server message', status: status),
        );
        expect(apiMessage, equals(dioMessage));
      }
    });

    test('ApiException with an unmapped status surfaces its own message', () {
      final message = friendlyErrorMessage(
        const ApiException(code: 'validation_error', message: 'That gym name is already taken.', status: 400),
      );
      expect(message, equals('That gym name is already taken.'));
    });

    test('ApiException never leaks DioException internals to the user', () {
      final messages = <String>[
        friendlyErrorMessage(const ApiException(code: 'error', message: '', status: 401)),
        friendlyErrorMessage(const ApiException(code: 'error', message: '', status: 403)),
        friendlyErrorMessage(const ApiException(code: 'error', message: '', status: 404)),
        friendlyErrorMessage(const ApiException(code: 'error', message: '', status: 429)),
        friendlyErrorMessage(const ApiException(code: 'error', message: '', status: 500)),
      ];

      for (final m in messages) {
        expect(m, isNot(contains('DioException')));
        expect(m, isNot(contains('RequestOptions')));
        expect(m, isNot(contains('validateStatus')));
        expect(m, isNot(contains('status code')));
      }
    });
  });

  group('isUserCancelledLogin', () {
    test('detects the native "user closed the sheet" cancellation', () {
      expect(
        isUserCancelledLogin(
          const WebAuthenticationException('USER_CANCELLED', 'The user cancelled the Web Auth operation.', {}),
        ),
        isTrue,
      );
    });

    test('detects the web/legacy cancellation code', () {
      expect(
        isUserCancelledLogin(
          const WebAuthenticationException('a0.authentication_canceled', 'cancelled', {}),
        ),
        isTrue,
      );
    });

    test('does not swallow real login failures', () {
      expect(
        isUserCancelledLogin(
          const WebAuthenticationException('a0.invalid_configuration', 'bad config', {}),
        ),
        isFalse,
      );
      expect(isUserCancelledLogin(_response(500)), isFalse);
      expect(isUserCancelledLogin(Exception('boom')), isFalse);
    });
  });

  group('isUnauthorized', () {
    test('detects a 401 response', () {
      expect(isUnauthorized(_response(401)), isTrue);
    });

    test('does not treat other failures as unauthorized', () {
      expect(isUnauthorized(_response(500)), isFalse);
      expect(isUnauthorized(_type(DioExceptionType.connectionError)), isFalse);
      expect(isUnauthorized(Exception('boom')), isFalse);
    });
  });
}
