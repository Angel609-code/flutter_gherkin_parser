import 'dart:convert' show jsonEncode, utf8;
import 'dart:io';
import 'package:flutter_gherkin_parser/models/endpoint_registration_model.dart';
import 'package:flutter_gherkin_parser/server/integration_test_server.dart';

class EndpointUtils {
  static void addHelloEndpoint(IntegrationTestServer server) {
    server.registerEndpoint(EndpointRegistration(
      method: 'GET',
      path: '/hello',
      handler: (req) async {
        // The endpoint approach can perform methods that uses dart io APIs
        // A change on this handler requires reload the integration test server
        final dir = Directory.current;
        final entries = await dir.list().map((e) => e.path).toList();

        req.response
          ..statusCode = 200
          ..write('Hello 👋 \n ${jsonEncode({'cwd': dir.path, 'files': entries})}')
          ..close();
      },
    ));
  }

  static void addEchoEndpoint(IntegrationTestServer server) {
    server.registerEndpoint(EndpointRegistration(
      method: 'POST',
      path: '/echo',
      handler: (req) async {
        final body = await utf8.decoder.bind(req).join();
        req.response
          ..statusCode = 200
          ..write('Echo: $body')
          ..close();
      },
    ));
  }
}
