import 'package:example/integration_test/integration_endpoints/endpoints.dart';
import 'package:flutter_gherkin_parser/server/integration_test_server.dart';

void main() {
  final server = IntegrationTestServer();

  EndpointUtils.addHelloEndpoint(server);

  server.start();
}