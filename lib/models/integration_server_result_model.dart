class IntegrationServerResult {
  final bool success;
  final int statusCode;
  final String? message;

  IntegrationServerResult({
    required this.success,
    required this.statusCode,
    this.message,
  });

  @override
  String toString() {
    return 'IntegrationServerResult(success: $success, statusCode: $statusCode, message: $message)';
  }
}
