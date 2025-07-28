// Al-Tijwal Test Configuration
// Configuration and setup for testing the Al-Tijwal application

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TestConfig {
  static const String testDatabaseUrl = 'test-supabase-url';
  static const String testApiKey = 'test-api-key';
  
  // Mock user data for testing
  static const Map<String, dynamic> mockAdminUser = {
    'id': 'admin-test-id',
    'email': 'admin@altijwal.com',
    'full_name': 'Test Admin',
    'role': 'admin',
  };

  static const Map<String, dynamic> mockAgentUser = {
    'id': 'agent-test-id',
    'email': 'agent@altijwal.com',
    'full_name': 'Test Agent',
    'role': 'agent',
  };

  static const Map<String, dynamic> mockClientUser = {
    'id': 'client-test-id',
    'email': 'client@altijwal.com',
    'full_name': 'Test Client',
    'role': 'client',
  };

  // Test campaign data
  static const Map<String, dynamic> mockCampaign = {
    'id': 'test-campaign-id',
    'name': 'Test Campaign',
    'description': 'Test campaign for automated testing',
    'status': 'active',
    'client_id': 'client-test-id',
    'package_type': 'basic',
    'start_date': '2025-01-01T00:00:00.000Z',
    'end_date': '2025-01-31T23:59:59.000Z',
    'created_at': '2025-01-01T10:00:00.000Z',
  };

  // Test locations (Cairo, Egypt)
  static const double testLatitude = 30.0444;
  static const double testLongitude = 31.2357;
  static const double testGeofenceRadius = 1000.0; // 1km

  /// Sets up the testing environment
  static Future<void> setupTestEnvironment() async {
    // Initialize any global test configuration
    WidgetsFlutterBinding.ensureInitialized();
    
    // Note: Test timeouts are configured per test using the timeout parameter
    // Example: testWidgets('test name', (tester) async { ... }, timeout: Timeout(Duration(seconds: 30)));
  }

  /// Creates a basic Material App wrapper for widget testing
  static Widget createTestApp({required Widget child}) {
    return MaterialApp(
      title: 'Al-Tijwal Test',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: child,
    );
  }

  /// Creates a test scaffold with basic structure
  static Widget createTestScaffold({
    String title = 'Test Screen',
    required Widget body,
    Widget? floatingActionButton,
  }) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }

  /// Utility to wait for animations and async operations
  static Future<void> pumpAndSettle(WidgetTester tester) async {
    await tester.pumpAndSettle(const Duration(seconds: 10));
  }

  /// Simulates user input delay
  static Future<void> simulateUserDelay() async {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

/// Custom test matchers for Al-Tijwal specific testing
class AlTijwalMatchers {
  /// Matches valid email format
  static Matcher isValidEmail() {
    return predicate<String>(
      (email) => RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email),
      'valid email format',
    );
  }

  /// Matches valid coordinates
  static Matcher isValidLatitude() {
    return predicate<double>(
      (lat) => lat >= -90.0 && lat <= 90.0,
      'valid latitude (-90 to 90)',
    );
  }

  /// Matches valid longitude
  static Matcher isValidLongitude() {
    return predicate<double>(
      (lng) => lng >= -180.0 && lng <= 180.0,
      'valid longitude (-180 to 180)',
    );
  }

  /// Matches campaign status values
  static Matcher isValidCampaignStatus() {
    return isIn(['draft', 'active', 'completed', 'cancelled']);
  }

  /// Matches user role values
  static Matcher isValidUserRole() {
    return isIn(['admin', 'manager', 'agent', 'client']);
  }
}

/// Test data generators
class TestDataGenerator {
  /// Generates a list of test campaigns
  static List<Map<String, dynamic>> generateTestCampaigns(int count) {
    return List.generate(count, (index) => {
      'id': 'campaign-$index',
      'name': 'Test Campaign ${index + 1}',
      'description': 'Generated test campaign ${index + 1}',
      'status': ['draft', 'active', 'completed'][index % 3],
      'client_id': 'client-test-id',
      'package_type': 'basic',
      'start_date': DateTime.now().add(Duration(days: index)).toIso8601String(),
      'end_date': DateTime.now().add(Duration(days: index + 30)).toIso8601String(),
      'created_at': DateTime.now().subtract(Duration(days: index)).toIso8601String(),
    });
  }

  /// Generates test user data
  static Map<String, dynamic> generateTestUser({
    String role = 'agent',
    int index = 0,
  }) {
    return {
      'id': '$role-$index',
      'email': '$role$index@altijwal.com',
      'full_name': 'Test ${role.capitalize()} $index',
      'role': role,
      'phone_number': '+20100000000$index',
      'created_at': DateTime.now().subtract(Duration(days: index)).toIso8601String(),
    };
  }
}

/// Extension methods for testing
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

/// Test utilities
class TestUtils {
  /// Finds text ignoring case
  static Finder findTextIgnoreCase(String text) {
    return find.byWidgetPredicate(
      (widget) => widget is Text && 
                   widget.data?.toLowerCase().contains(text.toLowerCase()) == true,
    );
  }

  /// Enters text in a specific text field
  static Future<void> enterTextInField(
    WidgetTester tester,
    String text, {
    int fieldIndex = 0,
  }) async {
    final textFields = find.byType(TextFormField);
    if (textFields.evaluate().length > fieldIndex) {
      await tester.enterText(textFields.at(fieldIndex), text);
      await tester.pump();
    }
  }

  /// Taps a button with specific text
  static Future<void> tapButton(WidgetTester tester, String buttonText) async {
    final button = find.widgetWithText(ElevatedButton, buttonText);
    if (button.evaluate().isNotEmpty) {
      await tester.tap(button);
      await tester.pump();
    }
  }

  /// Verifies a widget exists
  static void expectWidget<T>({int count = 1}) {
    if (count == 1) {
      expect(find.byType(T), findsOneWidget);
    } else {
      expect(find.byType(T), findsNWidgets(count));
    }
  }

  /// Verifies text exists
  static void expectText(String text, {int count = 1}) {
    if (count == 1) {
      expect(find.text(text), findsOneWidget);
    } else {
      expect(find.text(text), findsNWidgets(count));
    }
  }
}