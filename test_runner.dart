// Al-Tijwal Test Runner
// Comprehensive test suite runner for the Al-Tijwal application

import 'package:flutter_test/flutter_test.dart';

// Import all test files
import 'test/widget_test.dart' as widget_tests;
import 'test/basic_app_test.dart' as app_tests;

void main() {
  group('Al-Tijwal Complete Test Suite', () {
    group('Widget Tests', () {
      widget_tests.main();
    });

    group('App Core Tests', () {
      app_tests.main();
    });
  });
}