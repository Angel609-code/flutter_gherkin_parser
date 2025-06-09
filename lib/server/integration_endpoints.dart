import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_gherkin_parser/models/integration_server_result_model.dart';
import 'package:flutter_gherkin_parser/models/report_model.dart';

Future<IntegrationServerResult> saveReport(ReportBody report) async {
  final host = kIsWeb ? 'localhost' : Platform.isAndroid ? '10.0.2.2' : 'localhost';
  print('Host $host');
  final url = Uri.parse('http://$host:9876/save-report');

  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(report.toJson()),
    );
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
