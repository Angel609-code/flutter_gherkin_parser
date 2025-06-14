import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gherkin_parser/models/integration_server_result_model.dart';
import 'package:http/http.dart' as http;

Future<IntegrationServerResult> sayHello() async {
  final host = kIsWeb
      ? 'localhost'
      : Platform.isAndroid
      ? '10.0.2.2'
      : 'localhost';
  final url = Uri.parse('http://$host:9876/hello');

  try {
    final response = await http.get(url);
    return IntegrationServerResult(
      success: response.statusCode == 200,
      statusCode: response.statusCode,
      message: response.body,
    );
  } catch (e) {
    return IntegrationServerResult(
      success: false,
      statusCode: -1,
      message: e.toString(),
    );
  }
}