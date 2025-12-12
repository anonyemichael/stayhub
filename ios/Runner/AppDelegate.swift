import Flutter
import UIKit
import GoogleMaps // ✨ ADDED

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // ✨ UPDATED: Google Maps API Key for iOS
    GMSServices.provideAPIKey("AIzaSyAfNikKB-fgVazhqOlgY8brKqkJUJefCxw")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
