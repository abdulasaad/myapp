// Debug file to test the exact service call
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Initialize Supabase (use your actual URL and anon key)
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  final supabase = Supabase.instance.client;
  final agentId = '263e832c-f73c-48f3-bfd2-1b567cbff0b1';

  try {
    print('Testing service call...');
    
    final response = await supabase
        .from('touring_task_assignments')
        .select('''
          *,
          touring_tasks (
            *,
            campaign_geofences (
              id,
              name,
              area_text,
              color
            )
          )
        ''')
        .eq('agent_id', agentId)
        .eq('status', 'assigned')
        .order('assigned_at', ascending: false);

    print('Response: $response');
    print('Count: ${response.length}');
    
  } catch (e) {
    print('Error: $e');
  }
}