// lib/models/app_user.dart

class AppUser {
  final String id;
  final String fullName;
  final String email;

  AppUser({required this.id, required this.fullName, required this.email});

  factory AppUser.fromJson(Map<String, dynamic> json) {
    // We assume the user data comes from the 'profiles' table,
    // which should be joined with the auth users table if needed.
    // For now, we assume 'full_name' is in the profiles table.
    return AppUser(
      id: json['id'],
      fullName: json['full_name'] ?? 'No Name',
      // The email is not in the profiles table, it's in auth.users
      // This is a simplified model. We'll fetch the email separately if needed
      // or preferably join the tables in the query.
      email: json['email'] ?? '',
    );
  }
}