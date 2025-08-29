# Profiles Query Sweep — Summary

- `lib/services/group_service.dart:91`\n``\n0089:         try {
0090:           final managerResponse = await supabase
0091:               .from('profiles')
0092:               .select('*')
0093:               .eq('id', groupResponse['manager_id'])\n``
- `lib/services/group_service.dart:266`\n``\n0264:       // Get non-agent users who are not in this group
0265:       final response = await supabase
0266:           .from('profiles')
0267:           .select('*')
0268:           .neq('role', 'agent')\n``
- `lib/services/group_service.dart:312`\n``\n0310:     try {
0311:       final response = await supabase
0312:           .from('profiles')
0313:           .select('*')
0314:           .eq('role', 'manager')\n``
- `lib/services/group_service.dart:329`\n``\n0327:     try {
0328:       final response = await supabase
0329:           .from('profiles')
0330:           .select('*')
0331:           .eq('role', 'agent')\n``
- `lib/services/group_service.dart:346`\n``\n0344:       // First get all agents
0345:       final allAgents = await supabase
0346:           .from('profiles')
0347:           .select('*')
0348:           .eq('role', 'agent')\n``
- `lib/services/group_service.dart:376`\n``\n0374:       // First get all agents
0375:       final allAgents = await supabase
0376:           .from('profiles')
0377:           .select('*')
0378:           .eq('role', 'agent')\n``
- `lib/services/group_service.dart:415`\n``\n0413:       // Get all agents and managers
0414:       final allMembers = await supabase
0415:           .from('profiles')
0416:           .select('*')
0417:           .or('role.eq.agent,role.eq.manager')\n``
- `lib/services/location_history_service.dart:24`\n``\n0022:       // Get current user's role
0023:       final userRoleResponse = await supabase
0024:           .from('profiles')
0025:           .select('role')
0026:           .eq('id', currentUser.id)\n``
- `lib/services/location_history_service.dart:34`\n``\n0032:         // Admins can see all agents (excluding managers and other admins)
0033:         final response = await supabase
0034:             .from('profiles')
0035:             .select('id, full_name, role')
0036:             .eq('role', 'agent')\n``
- `lib/services/location_history_service.dart:80`\n``\n0078:         // Get profiles for these group members (only agents)
0079:         final response = await supabase
0080:             .from('profiles')
0081:             .select('id, full_name, role')
0082:             .inFilter('id', memberIds)\n``
- `lib/screens/map/live_map_screen.dart:289`\n``\n0287:       // Get current user's role
0288:       final userRoleResponse = await supabase
0289:           .from('profiles')
0290:           .select('role')
0291:           .eq('id', currentUser.id)\n``
- `lib/screens/map/live_map_screen.dart:314`\n``\n0312:         try {
0313:           final allAgentsResponse = await supabase
0314:               .from('profiles')
0315:               .select('id, full_name, role, status, last_heartbeat')
0316:               .eq('role', 'agent')\n``
- `lib/screens/map/live_map_screen.dart:358`\n``\n0356:       } else if (userRole == 'manager') {
0357:         // Managers can see agents in their groups (including those without heartbeats)
0358:         return await supabase.rpc('get_agents_in_manager_groups', params: {
0359:           'manager_user_id': currentUser.id,
0360:         });\n``
- `lib/screens/map/live_map_screen.dart:419`\n``\n0417:       // Step 4: Get agent profiles and locations
0418:       final agentsResponse = await supabase
0419:           .from('profiles')
0420:           .select('id, full_name, email, status')
0421:           .inFilter('id', agentIds)\n``
- `lib/screens/manager/team_members_screen.dart:44`\n``\n0042:       // Check if current user is manager
0043:       final userProfile = await supabase
0044:           .from('profiles')
0045:           .select('role')
0046:           .eq('id', currentUser.id)\n``
- `lib/screens/manager/team_members_screen.dart:56`\n``\n0054:         // Use new group-specific function to show all agents in manager's groups
0055:         agentsResponse = await supabase
0056:             .rpc('get_agents_in_manager_groups', params: {
0057:               'manager_user_id': currentUser.id,
0058:             })\n``
- `lib/screens/campaigns/campaign_detail_screen.dart:80`\n``\n0078:     // ========== THE DEFINITIVE FIX IS HERE: Use the correct 'in' filter ==========
0079:     final agentsResponse = await supabase
0080:         .from('profiles')
0081:         .select('id, full_name, role, status')
0082:         .filter('id', 'in', '(${agentIds.join(',')})');\n``
- `lib/screens/campaigns/campaign_detail_screen.dart:231`\n``\n0229:   Future<void> _showAssignAgentDialog() async {
0230:     final allAgentsResponse =
0231:         await supabase.from('profiles').select('id, full_name').eq('role', 'agent');
0232:     final allAgents =
0233:         allAgentsResponse.map((json) => AppUser.fromJson(json)).toList();\n``
- `lib/screens/campaigns/campaign_detail_screen.dart:897`\n``\n0895:       
0896:       final response = await supabase
0897:           .from('profiles')
0898:           .select('role')
0899:           .eq('id', currentUser.id)\n``
