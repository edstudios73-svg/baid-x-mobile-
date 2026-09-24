import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:baid_x_mobile/core/errors/error_handler.dart';
import 'package:baid_x_mobile/features/account_type/domain/account_type.dart';

void main() {
  test('there are exactly five account types', () {
    expect(AccountType.values.map((type) => type.dbValue).toSet(), {
      'worker',
      'employer',
      'business',
      'project_manager',
      'company',
    });
  });

  test('a database value maps to one account type', () {
    expect(AccountType.fromDatabase('project_manager'), AccountType.projectManager);
    expect(AccountType.fromDatabase('worker')?.setupPath, '/setup/worker');
    expect(AccountType.fromDatabase('company')?.homePath, '/role/company');
    expect(AccountType.fromDatabase('unknown'), isNull);
  });

  test('an existing account type is reported as already set', () {
    final error = ErrorHandler.toAppException(
      const PostgrestException(message: 'Account type is already set', code: 'P0001'),
    );
    expect(error.message, 'This account already has a type.');
  });

  test('an expired session is explained without a database error', () {
    final error = ErrorHandler.toAppException(
      const PostgrestException(message: 'JWT expired', code: 'PGRST301'),
    );
    expect(error.message, 'Your session has ended. Sign in again.');
    expect(error.message, isNot(contains('JWT')));
  });

  test('a permission failure stays readable', () {
    final error = ErrorHandler.toAppException(
      const PostgrestException(message: 'permission denied for function', code: '42501'),
    );
    expect(error.message, 'You don\'t have permission to do that.');
  });
}
