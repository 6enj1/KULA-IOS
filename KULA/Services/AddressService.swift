//
//  AddressService.swift
//  KULA
//
//  Address & Location API Service
//

import Foundation
import CoreLocation
import Combine
import MapKit
import UIKit

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private let manager = CLLocationManager()

    @Published var currentLocation: CLLocation?
    @Published var currentAddress: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLoading: Bool = false
    @Published var error: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        refreshAuthorizationStatus()
    }

    // MARK: - Authorization Helpers

    /// Whether location permission is authorized
    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    /// Whether location permission is denied or restricted (cannot request again)
    var isDeniedOrRestricted: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    /// Whether we can request permission (only when .notDetermined)
    var canRequestPermission: Bool {
        authorizationStatus == .notDetermined
    }

    /// Refresh authorization status - call on app foreground or scene change
    func refreshAuthorizationStatus() {
        let newStatus = manager.authorizationStatus
        let statusChanged = authorizationStatus != newStatus
        authorizationStatus = newStatus

        #if DEBUG
        print("[Location] Authorization status refreshed: \(authorizationStatus.rawValue)")
        #endif

        // Handle status appropriately
        if isAuthorized {
            // Only request location if authorized
            requestLocation()
        } else if isDeniedOrRestricted {
            // Clear cached location data when permission is denied/restricted
            clearLocationData()
        }

        // If status changed, this helps UI update
        if statusChanged {
            objectWillChange.send()
        }
    }

    /// Clear all cached location data
    func clearLocationData() {
        currentLocation = nil
        currentAddress = nil
        error = nil
        isLoading = false
        #if DEBUG
        print("[Location] Cleared cached location data")
        #endif
    }

    /// Request permission (only works if status is .notDetermined)
    func requestPermission() {
        guard canRequestPermission else {
            #if DEBUG
            print("[Location] Cannot request permission - status is \(authorizationStatus.rawValue)")
            #endif
            return
        }
        manager.requestWhenInUseAuthorization()
    }

    /// Open app settings (for when permission is denied)
    func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }

    /// Request a single location update (only if authorized)
    func requestLocation() {
        guard isAuthorized else {
            #if DEBUG
            print("[Location] Cannot request location - not authorized")
            #endif
            return
        }
        isLoading = true
        error = nil
        manager.requestLocation()
    }

    func startUpdatingLocation() {
        guard isAuthorized else { return }
        manager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isAuthorized, let location = locations.last else { return }
        currentLocation = location
        isLoading = false

        // Reverse geocode to get address
        reverseGeocode(location: location)

        #if DEBUG
        print("[Location] Updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        #endif
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.error = error.localizedDescription
        self.isLoading = false
        #if DEBUG
        print("[Location] Error: \(error.localizedDescription)")
        #endif
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let oldStatus = authorizationStatus
        authorizationStatus = manager.authorizationStatus

        #if DEBUG
        print("[Location] Authorization changed: \(oldStatus.rawValue) -> \(authorizationStatus.rawValue)")
        #endif

        if isAuthorized {
            requestLocation()
        } else if isDeniedOrRestricted {
            clearLocationData()
        }
    }

    // MARK: - Reverse Geocoding (using MapKit)
    private func reverseGeocode(location: CLLocation) {
        Task {
            do {
                let geocoder = CLGeocoder()
                let placemarks = try await geocoder.reverseGeocodeLocation(location)

                await MainActor.run {
                    if let placemark = placemarks.first {
                        let address = [
                            placemark.name,
                            placemark.locality,
                            placemark.administrativeArea
                        ].compactMap { $0 }.joined(separator: ", ")

                        self.currentAddress = address
                        #if DEBUG
                        print("[Location] Address: \(address)")
                        #endif
                    }
                }
            } catch {
                #if DEBUG
                print("[Location] Geocoding error: \(error.localizedDescription)")
                #endif
            }
        }
    }

    // MARK: - Helper
    var currentCoordinates: (latitude: Double, longitude: Double)? {
        guard isAuthorized, let location = currentLocation else { return nil }
        return (location.coordinate.latitude, location.coordinate.longitude)
    }
}

// MARK: - Address Service
class AddressService {
    static let shared = AddressService()
    private let client = APIClient.shared

    private init() {}

    // MARK: - Get Saved Addresses
    func getAddresses() async throws -> [SavedAddress] {
        let response: [APIAddress] = try await client.get(path: "/addresses")
        return response.map { $0.toSavedAddress() }
    }

    // MARK: - Add Address
    func addAddress(
        label: String,
        addressType: String = "other",
        addressLine1: String,
        city: String,
        province: String,
        postalCode: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        isDefault: Bool? = nil
    ) async throws -> SavedAddress {
        let body = CreateAddressRequest(
            label: label,
            addressType: addressType,
            addressLine1: addressLine1,
            city: city,
            province: province,
            postalCode: postalCode,
            latitude: latitude,
            longitude: longitude,
            isDefault: isDefault
        )
        let response: APIAddress = try await client.post(path: "/addresses", body: body)
        return response.toSavedAddress()
    }

    // MARK: - Update Address
    func updateAddress(id: String, label: String?, addressLine1: String?) async throws -> SavedAddress {
        let body = UpdateAddressRequest(label: label, addressLine1: addressLine1)
        let response: APIAddress = try await client.patch(path: "/addresses/\(id)", body: body)
        return response.toSavedAddress()
    }

    // MARK: - Delete Address
    func deleteAddress(id: String) async throws {
        let _: MessageResponse = try await client.delete(path: "/addresses/\(id)")
    }

    // MARK: - Set Default Address
    func setDefaultAddress(id: String) async throws -> SavedAddress {
        let response: APIAddress = try await client.patch(path: "/addresses/\(id)/default", body: EmptyBody())
        return response.toSavedAddress()
    }
}

// MARK: - API Models
struct APIAddress: Codable, Identifiable {
    let id: String
    let label: String
    let addressType: String
    let addressLine1: String
    let addressLine2: String?
    let city: String
    let province: String?
    let postalCode: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?
    let isDefault: Bool?

    func toSavedAddress() -> SavedAddress {
        let type: SavedAddress.AddressType = {
            switch addressType.lowercased() {
            case "home": return .home
            case "work": return .work
            case "current": return .current
            default: return .saved
            }
        }()

        let icon: String = {
            switch type {
            case .home: return "house.fill"
            case .work: return "briefcase.fill"
            case .current: return "location.fill"
            case .saved: return "mappin.circle.fill"
            }
        }()

        let fullAddress = [addressLine1, city, province].compactMap { $0 }.joined(separator: ", ")

        return SavedAddress(
            id: id,
            name: label,
            shortName: label,
            fullAddress: fullAddress,
            icon: icon,
            type: type,
            latitude: latitude,
            longitude: longitude
        )
    }
}

struct CreateAddressRequest: Encodable {
    let label: String
    let addressType: String
    let addressLine1: String
    let city: String
    let province: String
    let postalCode: String
    let latitude: Double?
    let longitude: Double?
    let isDefault: Bool?
}

struct UpdateAddressRequest: Encodable {
    let label: String?
    let addressLine1: String?
}

struct EmptyBody: Encodable {}

// MARK: - Address Suggestion Model
struct AddressSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let completion: MKLocalSearchCompletion
}

// MARK: - Address Result Model
struct AddressResult {
    let name: String
    let address: String
    let city: String
    let province: String
    let postalCode: String
    let latitude: Double
    let longitude: Double
}

// MARK: - Address Search Completer
class AddressSearchCompleter: NSObject, ObservableObject {
    private let completer = MKLocalSearchCompleter()

    @Published var suggestions: [AddressSuggestion] = []
    @Published var isSearching: Bool = false

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func search(query: String) {
        guard !query.isEmpty else {
            suggestions = []
            isSearching = false
            return
        }

        isSearching = true
        completer.queryFragment = query
    }

    func getDetails(for suggestion: AddressSuggestion) async -> AddressResult? {
        let searchRequest = MKLocalSearch.Request(completion: suggestion.completion)
        let search = MKLocalSearch(request: searchRequest)

        do {
            let response = try await search.start()
            guard let mapItem = response.mapItems.first else { return nil }

            let placemark = mapItem.placemark

            // Build full address
            let addressComponents = [
                placemark.subThoroughfare,
                placemark.thoroughfare
            ].compactMap { $0 }.joined(separator: " ")

            let fullAddress = addressComponents.isEmpty ? suggestion.title : addressComponents

            return AddressResult(
                name: mapItem.name ?? suggestion.title,
                address: fullAddress,
                city: placemark.locality ?? "",
                province: placemark.administrativeArea ?? "",
                postalCode: placemark.postalCode ?? "",
                latitude: placemark.coordinate.latitude,
                longitude: placemark.coordinate.longitude
            )
        } catch {
            #if DEBUG
            print("[Address] Failed to get details: \(error)")
            #endif
            return nil
        }
    }
}

// MARK: - MKLocalSearchCompleterDelegate
extension AddressSearchCompleter: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.suggestions = completer.results.map { completion in
                AddressSuggestion(
                    title: completion.title,
                    subtitle: completion.subtitle,
                    completion: completion
                )
            }
            self.isSearching = false
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        #if DEBUG
        print("[Address] Search completer error: \(error.localizedDescription)")
        #endif
        DispatchQueue.main.async {
            self.isSearching = false
        }
    }
}
