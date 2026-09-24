import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';

abstract final class ErrorHandler {
  static AppException toAppException(Object error) {
    if (error is AppException) return error;
    if (error is AuthException) {
      return AuthFlowException(_authMessage(error.message));
    }
    if (error is PostgrestException) {
      return AuthFlowException(_dataMessage(error.message));
    }
    final text = error.toString().toLowerCase();
    if (text.contains('socket') ||
        text.contains('network') ||
        text.contains('failed host lookup') ||
        text.contains('connection')) {
      return const NetworkException(
        'Couldn\'t reach BAID X. Check your connection and try again.',
      );
    }
    return const NetworkException(
      'Something went wrong. Check your connection and try again.',
    );
  }

  static String _authMessage(String message) {
    final shared = _sharedMessage(message);
    if (shared != null) return shared;
    final text = message.toLowerCase();
    if (text.contains('invalid login') || text.contains('invalid credentials')) {
      return 'Email or password is not correct.';
    }
    if (text.contains('email not confirmed')) {
      return 'Confirm your email before signing in.';
    }
    if (text.contains('already registered') || text.contains('already been registered')) {
      return 'An account with this email already exists. Sign in instead.';
    }
    if (text.contains('password')) {
      return 'Password does not meet the project rules. Use at least 8 characters.';
    }
    return 'Couldn\'t complete that sign-in step. Try again.';
  }

  static String _dataMessage(String message) {
    return _sharedMessage(message) ?? 'Couldn\'t save that. Try again.';
  }

  static String? _sharedMessage(String message) {
    final text = message.toLowerCase();
    if (text.contains('already set')) {
      return 'This account already has a type.';
    }
    if (text.contains('reviews_')) {
      return 'You already reviewed this work.';
    }
    if (text.contains('duplicate') || text.contains('23505')) {
      return 'You already applied to this job.';
    }
    if (text.contains('not signed in') ||
        text.contains('jwt') ||
        text.contains('session')) {
      return 'Your session has ended. Sign in again.';
    }
    if (text.contains("don't have access") || text.contains('do not have access')) {
      return "You don't have access to this conversation.";
    }
    if (text.contains('permission') ||
        text.contains('not authorized') ||
        text.contains('42501')) {
      return 'You don\'t have permission to do that.';
    }
    if (text.contains('rate') || text.contains('too many')) {
      return 'Too many attempts. Wait a moment and try again.';
    }
    if (text.contains('check constraint') || text.contains('value too long')) {
      return 'Some of that information is not valid. Shorten it and try again.';
    }
    return null;
  }
}
