import Flutter
import UIKit
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Check if GoogleService-Info.plist exists
    if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
       let _ = FirebaseOptions(contentsOfFile: path) {
      FirebaseApp.configure()
    } else {
      print("Warning: GoogleService-Info.plist not found in bundle")
      // For now, skip Firebase initialization to prevent crash
      // FirebaseApp.configure()
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
