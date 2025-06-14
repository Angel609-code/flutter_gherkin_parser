import 'package:flutter_gherkin_parser/server/integration_test_server.dart';

import 'integration_endpoints/endpoints.dart';

void main() {
  final server = IntegrationTestServer();

  EndpointUtils.addHelloEndpoint(server);

  server.start();
}