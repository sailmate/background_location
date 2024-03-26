import Flutter
import UIKit
import CoreLocation
import SQLite

public class SwiftBackgroundLocationPlugin: NSObject, FlutterPlugin, CLLocationManagerDelegate {
    static var locationManager: CLLocationManager?
    static var channel: FlutterMethodChannel?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftBackgroundLocationPlugin()

        SwiftBackgroundLocationPlugin.channel = FlutterMethodChannel(name: "com.almoullim.background_location/methods", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: SwiftBackgroundLocationPlugin.channel!)
        SwiftBackgroundLocationPlugin.channel?.setMethodCallHandler(instance.handle)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        SwiftBackgroundLocationPlugin.locationManager = CLLocationManager()
        SwiftBackgroundLocationPlugin.locationManager?.delegate = self
        SwiftBackgroundLocationPlugin.locationManager?.requestWhenInUseAuthorization()

        SwiftBackgroundLocationPlugin.channel?.invokeMethod("location", arguments: "method")

        if (call.method == "start_location_service") {
            SwiftBackgroundLocationPlugin.locationManager?.pausesLocationUpdatesAutomatically = false
            SwiftBackgroundLocationPlugin.locationManager?.allowsBackgroundLocationUpdates = true
            if #available(iOS 11.0, *) {
                SwiftBackgroundLocationPlugin.locationManager?.showsBackgroundLocationIndicator = true;
            }

            SwiftBackgroundLocationPlugin.channel?.invokeMethod("location", arguments: "start_location_service")

            let args = call.arguments as? Dictionary<String, Any>
            let distanceFilter = args?["distance_filter"] as? Double
            SwiftBackgroundLocationPlugin.locationManager?.distanceFilter = distanceFilter ?? 0

            SwiftBackgroundLocationPlugin.locationManager?.startUpdatingLocation()
        } else if (call.method == "stop_location_service") {
            SwiftBackgroundLocationPlugin.locationManager?.pausesLocationUpdatesAutomatically = true
            SwiftBackgroundLocationPlugin.channel?.invokeMethod("location", arguments: "stop_location_service")
            SwiftBackgroundLocationPlugin.locationManager?.stopUpdatingLocation()
            SwiftBackgroundLocationPlugin.locationManager?.allowsBackgroundLocationUpdates = false
            if #available(iOS 11.0, *) {
                SwiftBackgroundLocationPlugin.locationManager?.showsBackgroundLocationIndicator = false;
            }
        }
        result(true)
    }

    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways {

        }
    }

    func getDocumentsDirectory() -> String {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return "\(documentsDirectory)/sailmate_tracks.db"
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        do {
            let db = try Connection(getDocumentsDirectory())

            let tracks = Table("tracks")
            for location in locations {
                let lat = Expression<Double>("lat")
                let lon = Expression<Double>("lon")
                let speed = Expression<Double>("speed")
                let insert = tracks.insert(lat <- location.coordinate.latitude, lon <- location.coordinate.longitude, speed <- location.speed)
                let rowid = try db.run(insert)
            }
            let transformedLocations = locations.map {(location) -> [String : Any] in
                [
                    "speed": location.speed,
                    "altitude": location.altitude,
                    "latitude": location.coordinate.latitude,
                    "longitude": location.coordinate.longitude,
                    "accuracy": location.horizontalAccuracy,
                    "bearing": location.course,
                    "time": location.timestamp.timeIntervalSince1970 * 1000,
                    "is_mock": false
                ] as [String : Any]
            }
        } catch {
            print (error)
        }
    }
}
