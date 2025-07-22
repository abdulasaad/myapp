// Simplified Campaign Model Tests
// Basic tests for the Campaign data model

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/campaign.dart';

void main() {
  group('Campaign Model Tests', () {
    test('should create campaign with all required fields', () {
      final now = DateTime.now();
      final campaign = Campaign(
        id: 'test-campaign',
        name: 'Test Campaign',
        description: 'A test campaign',
        startDate: now,
        endDate: now.add(Duration(days: 30)),
        status: 'active',
        packageType: 'basic',
        clientId: 'test-client',
        assignedManagerId: 'test-manager',
        createdAt: now,
      );

      expect(campaign.id, equals('test-campaign'));
      expect(campaign.name, equals('Test Campaign'));
      expect(campaign.status, equals('active'));
      expect(campaign.packageType, equals('basic'));
      expect(campaign.clientId, equals('test-client'));
      expect(campaign.assignedManagerId, equals('test-manager'));
    });

    test('should create campaign from JSON', () {
      final json = {
        'id': 'json-campaign',
        'name': 'JSON Campaign',
        'description': 'Campaign from JSON',
        'start_date': '2025-01-01T00:00:00.000Z',
        'end_date': '2025-01-31T23:59:59.000Z',
        'status': 'active',
        'package_type': 'premium',
        'client_id': 'json-client',
        'assigned_manager_id': 'json-manager',
        'created_at': '2025-01-01T10:00:00.000Z',
      };

      final campaign = Campaign.fromJson(json);

      expect(campaign.id, equals('json-campaign'));
      expect(campaign.name, equals('JSON Campaign'));
      expect(campaign.status, equals('active'));
      expect(campaign.packageType, equals('premium'));
      expect(campaign.clientId, equals('json-client'));
      expect(campaign.assignedManagerId, equals('json-manager'));
    });

    test('should handle optional fields correctly', () {
      final campaign = Campaign(
        id: 'minimal-campaign',
        name: 'Minimal Campaign',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(Duration(days: 10)),
        status: 'draft',
        packageType: 'basic',
        createdAt: DateTime.now(),
      );

      expect(campaign.description, isNull);
      expect(campaign.clientId, isNull);
      expect(campaign.assignedManagerId, isNull);
    });

    test('should handle different statuses', () {
      final statuses = ['draft', 'active', 'completed', 'cancelled'];
      
      for (final status in statuses) {
        final campaign = Campaign(
          id: 'campaign-$status',
          name: 'Test Campaign',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(Duration(days: 1)),
          status: status,
          packageType: 'basic',
          createdAt: DateTime.now(),
        );
        
        expect(campaign.status, equals(status));
      }
    });

    test('should handle different package types', () {
      final packageTypes = ['basic', 'premium', 'enterprise'];
      
      for (final packageType in packageTypes) {
        final campaign = Campaign(
          id: 'campaign-$packageType',
          name: 'Test Campaign',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(Duration(days: 1)),
          status: 'active',
          packageType: packageType,
          createdAt: DateTime.now(),
        );
        
        expect(campaign.packageType, equals(packageType));
      }
    });
  });
}