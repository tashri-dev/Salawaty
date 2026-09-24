import Combine
import CoreLocation
import Foundation

struct ResolvedLocation: Equatable {
    var latitude: Double
    var longitude: Double
    var name: String
    var timeZone: TimeZone
    var isDevice: Bool
}

enum LocationError: LocalizedError {
    case notFound
    var errorDescription: String? { "Place not found" }
}

/// Uses the Mac's location when permission is granted (and follows it when it changes),
/// otherwise falls back to a city the user typed in.
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var status: CLAuthorizationStatus
    @Published private(set) var resolved: ResolvedLocation?
    @Published private(set) var isLocating = false

    private let manager: CLLocationManager
    private let geocoder = CLGeocoder()
    private var lastDeviceLocation: CLLocation?
    private let defaults = UserDefaults.standard

    /// Ignore movements smaller than this (meters) to avoid needless recalculation.
    private let minimumMove: CLLocationDistance = 3000

    override init() {
        let m = CLLocationManager()
        manager = m
        status = m.authorizationStatus
        super.init()
        m.delegate = self
        m.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var isAuthorized: Bool { status == .authorizedAlways }
    var isDenied: Bool { status == .denied || status == .restricted }

    // MARK: Public API

    func start() {
        guard Prefs.useDeviceLocation else {
            stopDevice()
            applyManual()
            return
        }
        if status == .notDetermined {
            applyManual()
            manager.requestWhenInUseAuthorization()
        } else if isAuthorized {
            startDevice()
        } else {
            stopDevice()
            applyManual()
        }
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func refresh() {
        if Prefs.useDeviceLocation && isAuthorized {
            isLocating = true
            manager.requestLocation()
        } else {
            applyManual()
        }
    }

    /// Geocodes a city typed by the user and switches to it.
    func setManualLocation(query: String, completion: @escaping (Result<String, Error>) -> Void) {
        if geocoder.isGeocoding { geocoder.cancelGeocode() }
        geocoder.geocodeAddressString(query) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                guard let self else { return }
                guard let p = placemarks?.first, let loc = p.location else {
                    completion(.failure(error ?? LocationError.notFound))
                    return
                }
                let name = Self.displayName(for: p) ?? query
                self.defaults.set(loc.coordinate.latitude, forKey: PrefKey.manualLatitude)
                self.defaults.set(loc.coordinate.longitude, forKey: PrefKey.manualLongitude)
                self.defaults.set(name, forKey: PrefKey.manualName)
                self.defaults.set((p.timeZone ?? .current).identifier, forKey: PrefKey.manualTimeZone)
                self.defaults.set(false, forKey: PrefKey.useDeviceLocation) // explicit choice wins
                self.stopDevice()
                self.applyManual()
                completion(.success(name))
            }
        }
    }

    // MARK: Device location

    private func startDevice() {
        isLocating = true
        manager.requestLocation()
        if CLLocationManager.significantLocationChangeMonitoringAvailable() {
            manager.startMonitoringSignificantLocationChanges()
        }
        if resolved == nil { applyManual() } // show something while waiting
    }

    private func stopDevice() {
        manager.stopMonitoringSignificantLocationChanges()
        isLocating = false
    }

    private func handle(_ loc: CLLocation) {
        isLocating = false
        guard Prefs.useDeviceLocation else { return }
        if let last = lastDeviceLocation, resolved?.isDevice == true,
           last.distance(from: loc) < minimumMove { return }
        lastDeviceLocation = loc

        let coordName = String(format: "%.3f, %.3f", loc.coordinate.latitude, loc.coordinate.longitude)
        resolved = ResolvedLocation(latitude: loc.coordinate.latitude,
                                    longitude: loc.coordinate.longitude,
                                    name: coordName, timeZone: .current, isDevice: true)

        // Refine with a readable name and the correct time zone.
        if geocoder.isGeocoding { geocoder.cancelGeocode() }
        geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            DispatchQueue.main.async {
                guard let self, let p = placemarks?.first, self.lastDeviceLocation == loc,
                      Prefs.useDeviceLocation else { return }
                self.resolved = ResolvedLocation(latitude: loc.coordinate.latitude,
                                                 longitude: loc.coordinate.longitude,
                                                 name: Self.displayName(for: p) ?? coordName,
                                                 timeZone: p.timeZone ?? .current,
                                                 isDevice: true)
            }
        }
    }

    // MARK: Manual location

    private func applyManual() {
        guard let lat = defaults.object(forKey: PrefKey.manualLatitude) as? Double,
              let lng = defaults.object(forKey: PrefKey.manualLongitude) as? Double else {
            if resolved?.isDevice != true || !Prefs.useDeviceLocation { resolved = nil }
            return
        }
        let tz = defaults.string(forKey: PrefKey.manualTimeZone).flatMap(TimeZone.init(identifier:)) ?? .current
        resolved = ResolvedLocation(latitude: lat, longitude: lng,
                                    name: defaults.string(forKey: PrefKey.manualName) ?? "Custom location",
                                    timeZone: tz, isDevice: false)
    }

    private static func displayName(for p: CLPlacemark) -> String? {
        let parts = [p.locality ?? p.name, p.country].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.status = manager.authorizationStatus
            self.start()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        DispatchQueue.main.async { self.handle(loc) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isLocating = false
            if self.resolved == nil { self.applyManual() }
        }
    }
}
