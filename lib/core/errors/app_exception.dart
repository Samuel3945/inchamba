class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => message;
}

class AuthException extends AppException {
  const AuthException(super.message, {super.code});
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'Error de conexión. Verifica tu internet.']);
}

class ServerException extends AppException {
  const ServerException([super.message = 'Error del servidor. Intenta de nuevo.']);
}

class StorageException extends AppException {
  const StorageException([super.message = 'Error al subir el archivo.']);
}
