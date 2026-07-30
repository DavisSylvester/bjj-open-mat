import 'dart:io';

import 'package:auth0_flutter/auth0_flutter.dart' hide ApiException;
import 'package:dio/dio.dart';

import '../data/api_exception.dart';

/// Maps an HTTP status code to the same user-facing message used for the
/// equivalent `DioException` badResponse case. Returns null when there is no
/// specific mapping for [status], leaving the caller to fall back to
/// something else (e.g. the exception's own message).
String? _statusMessage(int status) {
  if (status == 401) {
    return 'Your session has expired. Please sign in again.';
  }
  if (status == 403) {
    return 'You don\'t have permission to do that.';
  }
  if (status == 404) {
    return 'We couldn\'t find what you were looking for.';
  }
  if (status == 429) {
    return 'Too many requests. Please wait a moment and try again.';
  }
  if (status >= 500) {
    return 'BJJ Open Mat is having trouble right now. Please try again shortly.';
  }
  return null;
}

/// Translates a thrown error into a message that is safe to show a user.
///
/// Raw `DioException.toString()` leaks the request internals ("RequestOptions
/// .validateStatus was configured to throw...") straight into the UI, so every
/// user-facing catch block should route through here instead of `e.toString()`.
///
/// Messages stay general on purpose — enough for someone to know whether to
/// retry, check their connection, or sign in again, without exposing endpoints,
/// status codes, or stack detail.
String friendlyErrorMessage(Object error) {
  if (error is ApiException) {
    final status = error.status;
    final mapped = status == null ? null : _statusMessage(status);
    if (mapped != null) return mapped;
    if (error.message.isNotEmpty) return error.message;
    return 'Something went wrong. Please try again.';
  }

  if (error is! DioException) {
    return 'Something went wrong. Please try again.';
  }

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'The connection timed out. Check your internet and try again.';

    case DioExceptionType.connectionError:
      return 'We couldn\'t reach BJJ Open Mat. Check your connection and try again.';

    case DioExceptionType.badCertificate:
      return 'We couldn\'t establish a secure connection. Please try again.';

    case DioExceptionType.cancel:
      return 'That request was cancelled.';

    case DioExceptionType.unknown:
      if (error.error is SocketException) {
        return 'We couldn\'t reach BJJ Open Mat. Check your connection and try again.';
      }
      return 'Something went wrong. Please try again.';

    case DioExceptionType.badResponse:
      final status = error.response?.statusCode ?? 0;
      return _statusMessage(status) ?? 'Something went wrong. Please try again.';
  }
}

/// True when the user dismissed the Auth0 hosted login sheet.
///
/// Backing out of sign-in is a deliberate choice, not a failure, so callers
/// should return to the login screen without showing any message.
bool isUserCancelledLogin(Object error) {
  return error is WebAuthenticationException && error.isUserCancelledException;
}

/// True when [error] is an HTTP 401 — i.e. the stored session is no longer
/// accepted by the API and the user needs to sign in again.
bool isUnauthorized(Object error) {
  return error is DioException && error.response?.statusCode == 401;
}
