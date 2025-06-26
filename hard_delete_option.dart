// Alternative: Hard Delete Implementation
// Replace the deleteUser function with this if you want true deletion

/// Delete user permanently (HARD DELETE - DANGEROUS!)
Future<bool> deleteUserPermanently(String userId) async {
  try {
    // IMPORTANT: This will permanently remove the user and all their data
    // This cannot be undone!
    
    // Step 1: Remove from user_groups
    await supabase
        .from('user_groups')
        .delete()
        .eq('user_id', userId);
    
    // Step 2: Delete from profiles table
    await supabase
        .from('profiles')
        .delete()
        .eq('id', userId);
    
    // Step 3: Delete from auth.users (this is the nuclear option)
    // Note: This requires admin privileges and may not work with RLS
    // You might need to use the Supabase admin API for this
    
    return true;
  } catch (e) {
    debugPrint('Error permanently deleting user: $e');
    return false;
  }
}

/// Soft delete (current implementation - RECOMMENDED)
Future<bool> deleteUserSafely(String userId) async {
  try {
    await supabase
        .from('profiles')
        .update({
          'status': 'offline',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);

    // Remove from all groups
    await supabase
        .from('user_groups')
        .delete()
        .eq('user_id', userId);

    return true;
  } catch (e) {
    debugPrint('Error deleting user: $e');
    return false;
  }
}