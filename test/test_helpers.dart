// Test Helpers
// Common utilities and mocks for Al-Tijwal testing

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/app_user.dart';
import 'package:myapp/models/campaign.dart';

// Common Mock Classes
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockUser extends Mock implements User {}
class MockAuthResponse extends Mock implements AuthResponse {}

// Test Data Generators
class TestDataGenerator {
  static AppUser createTestUser({
    String id = 'test-user-id',
    String email = 'test@altijwal.com',
    String fullName = 'Test User',
    String role = 'agent',
  }) {
    return AppUser(
      id: id,
      email: email,
      fullName: fullName,
      role: role,
      createdAt: DateTime.now(),
    );
  }

  static Campaign createTestCampaign({
    String id = 'test-campaign-id',
    String name = 'Test Campaign',
    String? description = 'Test campaign description',
    DateTime? startDate,
    DateTime? endDate,
    String status = 'active',
    String clientId = 'test-client-id',
  }) {
    return Campaign(
      id: id,
      name: name,
      description: description,
      startDate: startDate ?? DateTime.now(),
      endDate: endDate ?? DateTime.now().add(Duration(days: 30)),
      status: status,
      clientId: clientId,
      packageType: 'basic',
      createdAt: DateTime.now(),
    );
  }

  static List<Campaign> createTestCampaigns({int count = 5}) {
    return List.generate(count, (index) => createTestCampaign(
      id: 'campaign-$index',
      name: 'Campaign ${index + 1}',
      status: index % 3 == 0 ? 'active' : index % 3 == 1 ? 'completed' : 'draft',
    ));
  }
}

// Test Widget Wrapper
class TestWidgetWrapper extends StatelessWidget {
  final Widget child;
  final List<LocalizationsDelegate<dynamic>>? localizationsDelegates;
  final List<Locale>? supportedLocales;

  const TestWidgetWrapper({
    super.key,
    required this.child,
    this.localizationsDelegates,
    this.supportedLocales,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: child,
      localizationsDelegates: localizationsDelegates ?? [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: supportedLocales ?? [
        const Locale('en', ''),
        const Locale('ar', ''),
      ],
    );
  }
}

// Mock Setup Helpers
class MockSetupHelper {
  static void setupSupabaseAuth(
    MockSupabaseClient mockClient,
    MockGoTrueClient mockAuth, {
    MockUser? currentUser,
  }) {
    when(() => mockClient.auth).thenReturn(mockAuth);
    when(() => mockAuth.currentUser).thenReturn(currentUser);
  }

  static void setupSuccessfulLogin(
    MockGoTrueClient mockAuth,
    MockAuthResponse mockResponse,
    MockUser mockUser,
  ) {
    when(() => mockAuth.signInWithPassword(
      email: any(named: 'email'),
      password: any(named: 'password'),
    )).thenAnswer((_) async => mockResponse);
    
    when(() => mockResponse.user).thenReturn(mockUser);
  }

  static void setupFailedLogin(
    MockGoTrueClient mockAuth,
    String errorMessage,
  ) {
    when(() => mockAuth.signInWithPassword(
      email: any(named: 'email'),
      password: any(named: 'password'),
    )).thenThrow(AuthException(errorMessage));
  }
}

// Test Constants
class TestConstants {
  static const validEmail = 'test@altijwal.com';
  static const invalidEmail = 'invalid-email';
  static const validPassword = 'password123';
  static const shortPassword = '123';
  static const longPassword = 'verylongpasswordthatmeetsallrequirements123';

  // Cairo coordinates for location testing
  static const cairoLatitude = 30.0444;
  static const cairoLongitude = 31.2357;

  // Test geofence radius
  static const defaultGeofenceRadius = 1000.0; // 1km

  // Test user IDs
  static const adminUserId = 'admin-user-id';
  static const managerUserId = 'manager-user-id';
  static const agentUserId = 'agent-user-id';
  static const clientUserId = 'client-user-id';
}

// Test Matchers
class CustomMatchers {
  /// Matches a DateTime that is approximately equal to the expected value
  /// within a tolerance of [tolerance] milliseconds
  static Matcher approximatelyEqual(DateTime expected, {int tolerance = 1000}) {
    return predicate<DateTime>(
      (actual) {
        final difference = actual.difference(expected).inMilliseconds.abs();
        return difference <= tolerance;
      },
      'approximately equal to $expected within ${tolerance}ms',
    );
  }

  /// Matches a double that is within the specified range
  static Matcher withinRange(double min, double max) {
    return predicate<double>(
      (actual) => actual >= min && actual <= max,
      'within range $min to $max',
    );
  }

  /// Matches a location coordinate that is valid
  static Matcher validLatitude() {
    return predicate<double>(
      (actual) => actual >= -90.0 && actual <= 90.0,
      'valid latitude (-90 to 90)',
    );
  }

  /// Matches a location coordinate that is valid
  static Matcher validLongitude() {
    return predicate<double>(
      (actual) => actual >= -180.0 && actual <= 180.0,
      'valid longitude (-180 to 180)',
    );
  }
}

// Test Utilities
class TestUtils {
  /// Pumps the widget and waits for all animations and async operations
  static Future<void> pumpAndSettleWithDelay(
    WidgetTester tester, {
    Duration delay = const Duration(milliseconds: 100),
  }) async {
    await tester.pumpAndSettle();
    await tester.binding.delayed(delay);
    await tester.pumpAndSettle();
  }

  /// Finds a widget by its text content (case-insensitive)
  static Finder findByTextIgnoreCase(String text) {
    return find.byWidgetPredicate(
      (widget) => widget is Text && 
                   widget.data?.toLowerCase() == text.toLowerCase(),
    );
  }

  /// Enters text in the nth TextFormField
  static Future<void> enterTextInField(
    WidgetTester tester,
    int fieldIndex,
    String text,
  ) async {
    final textFields = find.byType(TextFormField);
    expect(textFields, findsAtLeastNWidgets(fieldIndex + 1));
    
    await tester.enterText(textFields.at(fieldIndex), text);
    await tester.pump();
  }

  /// Taps a button by its text content
  static Future<void> tapButtonWithText(
    WidgetTester tester,
    String buttonText,
  ) async {
    final button = find.widgetWithText(ElevatedButton, buttonText);
    expect(button, findsOneWidget);
    
    await tester.tap(button);
    await tester.pump();
  }

  /// Verifies that a snackbar with specific text is shown
  static void expectSnackBar(WidgetTester tester, String message) {
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text(message), findsOneWidget);
  }

  /// Simulates a successful network response delay
  static Future<void> simulateNetworkDelay({
    Duration delay = const Duration(milliseconds: 500),
  }) async {
    await Future.delayed(delay);
  }
}

// Integration Test Helpers
class IntegrationTestHelper {
  /// Sets up the app for integration testing with mock backend
  static Future<void> setupAppForTesting() async {
    // Initialize any required services for integration testing
    // This would include setting up test database connections,
    // mock services, etc.
  }

  /// Cleans up after integration tests
  static Future<void> tearDownAfterTesting() async {
    // Clean up test data, close connections, etc.
  }

  /// Creates a test user in the database for integration testing
  static Future<AppUser> createTestUserInDatabase({
    String role = 'agent',
  }) async {
    // This would create an actual user in the test database
    // For now, return a mock user
    return TestDataGenerator.createTestUser(role: role);
  }

  /// Creates a test campaign in the database for integration testing
  static Future<Campaign> createTestCampaignInDatabase({
    String status = 'active',
  }) async {
    // This would create an actual campaign in the test database
    // For now, return a mock campaign
    return TestDataGenerator.createTestCampaign(status: status);
  }
}