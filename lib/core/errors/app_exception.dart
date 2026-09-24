/// Plain-language failures. Raw database errors stay out of the UI.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class ConfigurationException extends AppException {
  const ConfigurationException(super.message);
}

final class NetworkException extends AppException {
  const NetworkException(super.message);
}

final class AuthFlowException extends AppException {
  const AuthFlowException(super.message);
}
