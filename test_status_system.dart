// test_status_system.dart
// Simple test script to verify the status system is working

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/services/user_status_service.dart';
import 'lib/services/connectivity_service.dart';
import 'lib/utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://jnuzpixgfskjcoqmgkxb.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpudXpwaXhnZnNramNvcW1na3hiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkyODI4NTksImV4cCI6MjA2NDg1ODg1OX0.9H9ukV77BtyfX8Vhnlz2KqJeqPv-hxIhGeZdNsOeaPk',
  );

  print('🧪 Testing Status System...');
  
  // Test 1: Check database functions exist
  print('\n📋 Test 1: Checking database functions...');
  try {
    await supabase.rpc('update_user_heartbeat', params: {
      'user_id': '00000000-0000-0000-0000-000000000000', // dummy UUID
      'status': 'active',
    });
    print('✅ update_user_heartbeat function exists');
  } catch (e) {
    if (e.toString().contains('violates foreign key constraint')) {
      print('✅ update_user_heartbeat function exists (foreign key expected)');
    } else {
      print('❌ update_user_heartbeat function error: $e');
    }
  }

  try {
    final response = await supabase.rpc('get_agents_with_last_location');
    print('✅ get_agents_with_last_location function exists');
    print('📊 Returned ${response.length} records');
  } catch (e) {
    print('❌ get_agents_with_last_location function error: $e');
  }

  // Test 2: Check profiles table has new columns
  print('\n📋 Test 2: Checking profiles table structure...');
  try {
    final response = await supabase
        .from('profiles')
        .select('id, full_name, connection_status, last_heartbeat')
        .limit(1);
    print('✅ Profiles table has new status columns');
    if (response.isNotEmpty) {
      print('📊 Sample profile: ${response.first}');
    }
  } catch (e) {
    print('❌ Profiles table structure error: $e');
  }

  // Test 3: Check active_agents table exists
  print('\n📋 Test 3: Checking active_agents table...');
  try {
    final response = await supabase
        .from('active_agents')
        .select('id, user_id, last_location, last_seen')
        .limit(1);
    print('✅ Active agents table exists');
    print('📊 Records: ${response.length}');
  } catch (e) {
    print('❌ Active agents table error: $e');
  }

  // Test 4: Initialize services
  print('\n📋 Test 4: Testing service initialization...');
  try {
    await ConnectivityService().initialize();
    print('✅ ConnectivityService initialized');
    print('📊 Is online: ${ConnectivityService().isOnline}');
  } catch (e) {
    print('❌ ConnectivityService error: $e');
  }

  try {
    await UserStatusService().initialize();
    print('✅ UserStatusService initialized');
    print('📊 Current status: ${UserStatusService().currentStatus}');
    print('📊 Status summary: ${UserStatusService().getStatusSummary()}');
  } catch (e) {
    print('❌ UserStatusService error: $e');
  }

  print('\n🎯 Status System Test Complete!');
  print('📝 Next steps:');
  print('   1. Login to the app to test user status tracking');
  print('   2. Check Live Map for status indicators');
  print('   3. Monitor console logs for heartbeat messages');
}