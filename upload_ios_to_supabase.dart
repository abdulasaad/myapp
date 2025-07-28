import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

// This script uploads the iOS IPA file to Supabase storage

void main() async {
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://otsgnyqdzwiruxasmlbo.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im90c2dueXFkendpcnV4YXNtbGJvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjE0MTU5NjgsImV4cCI6MjAzNjk5MTk2OH0.ZgqIz6PDlt0_moong3PbKLNsKzpqMo8pFUZGVkvCmsA',
  );

  final supabase = Supabase.instance.client;

  try {
    // Read the IPA file
    final ipaFile = File('/Users/abdullahsaad/AL-Tijwal/myapp/myapp/build/ios/iphoneos/Al-Tijwal-iOS.ipa');
    if (!await ipaFile.exists()) {
      print('Error: IPA file not found!');
      exit(1);
    }

    final bytes = await ipaFile.readAsBytes();
    final fileName = 'Al-Tijwal-iOS-${DateTime.now().millisecondsSinceEpoch}.ipa';
    
    final sizeMB = (bytes.length / 1024 / 1024).toStringAsFixed(2);
    print('Uploading $sizeMB MB to Supabase...');

    // Upload to Supabase storage
    final response = await supabase.storage
        .from('app-updates')
        .uploadBinary(
          'ios/$fileName',
          bytes,
          fileOptions: FileOptions(
            contentType: 'application/octet-stream',
            cacheControl: '3600',
            upsert: true,
          ),
        );

    print('Upload successful!');
    
    // Get public URL
    final publicUrl = supabase.storage
        .from('app-updates')
        .getPublicUrl('ios/$fileName');

    print('Public URL: $publicUrl');
    
    // Calculate file size in MB
    final fileSizeMb = bytes.length / 1024 / 1024;
    
    print('\n=== iOS App Upload Complete ===');
    print('File: $fileName');
    print('Size: ${fileSizeMb.toStringAsFixed(2)} MB');
    print('URL: $publicUrl');
    print('\nTo add to app_versions table:');
    print('- version_code: [BUILD_NUMBER]');
    print('- version_name: [VERSION_NAME]');
    print('- download_url: $publicUrl');
    print('- file_size_mb: ${fileSizeMb.toStringAsFixed(2)}');
    print('- platform: ios');
    
  } catch (e) {
    print('Error uploading file: $e');
    exit(1);
  }

  exit(0);
}