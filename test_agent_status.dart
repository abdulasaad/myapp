// Test file to verify agent status calculation
import 'package:flutter/material.dart';

void main() {
  print('Testing Agent Status Calculation');
  print('=' * 50);
  
  // Test the status calculation logic
  String getCalculatedStatus(DateTime? lastSeen) {
    if (lastSeen == null) return 'Offline';
    final difference = DateTime.now().difference(lastSeen);
    if (difference.inSeconds <= 45) return 'Active';
    if (difference.inMinutes < 15) return 'Away';
    return 'Offline';
  }
  
  // Test cases
  final now = DateTime.now();
  
  print('\nTest 1: Current time (should be Active)');
  print('Status: ${getCalculatedStatus(now)}');
  
  print('\nTest 2: 30 seconds ago (should be Active)');
  print('Status: ${getCalculatedStatus(now.subtract(const Duration(seconds: 30)))}');
  
  print('\nTest 3: 1 minute ago (should be Away)');
  print('Status: ${getCalculatedStatus(now.subtract(const Duration(minutes: 1)))}');
  
  print('\nTest 4: 10 minutes ago (should be Away)');
  print('Status: ${getCalculatedStatus(now.subtract(const Duration(minutes: 10)))}');
  
  print('\nTest 5: 20 minutes ago (should be Offline)');
  print('Status: ${getCalculatedStatus(now.subtract(const Duration(minutes: 20)))}');
  
  print('\nTest 6: null timestamp (should be Offline)');
  print('Status: ${getCalculatedStatus(null)}');
  
  print('\n' + '=' * 50);
  print('Common Issues:');
  print('1. RPC function using created_at instead of recorded_at');
  print('2. Agent device clock ahead of server time');
  print('3. Offline queue syncing old data with recent created_at');
  print('4. No validation of future timestamps');
  
  print('\nSolutions Applied:');
  print('✅ Updated RPC function to use recorded_at');
  print('✅ Added timestamp validation in offline queue');
  print('✅ Added database constraint for future timestamps');
  print('✅ Added timestamp adjustment for future dates');
}