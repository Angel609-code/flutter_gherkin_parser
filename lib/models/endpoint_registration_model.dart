import 'dart:io';

typedef EndpointHandler = Future<void> Function(HttpRequest request);

class EndpointRegistration {
  final String method;
  final String path;
  final EndpointHandler handler;

  EndpointRegistration({
    required this.method,
    required this.path,
    required this.handler,
  });
}
