import 'package:flutter_gherkin_parser/lifecycle_listener.dart';

abstract class IntegrationReporter implements LifecycleListener {
  final String path;
  IntegrationReporter({ this.path = '' });

  Map<String, dynamic> toJson();
}
