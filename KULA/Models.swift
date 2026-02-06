//
//  Models.swift
//  KULA
//
//  Data Models and Mock Data
//

import Foundation
import SwiftUI

// MARK: - Opening Hours Model
struct OpeningHours: Hashable {
    let dayOfWeek: String
    let openTime: String  // "09:00"
    let closeTime: String // "21:00"
    let isClosed: Bool

    /// Returns true if the restaurant is currently open
    static func isOpenNow(hours: [OpeningHours]) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        // Convert to day name (1 = Sunday in Calendar, but API uses lowercase names)
        let dayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        let todayName = dayNames[weekday - 1]

        guard let todayHours = hours.first(where: { $0.dayOfWeek.lowercased() == todayName }) else {
            return false
        }

        if todayHours.isClosed { return false }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeString = formatter.string(from: now)

        return timeString >= todayHours.openTime && timeString <= todayHours.closeTime
    }

    /// Returns the closing time for today, or nil if closed
    static func closingTimeToday(hours: [OpeningHours]) -> String? {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        let dayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        let todayName = dayNames[weekday - 1]

        guard let todayHours = hours.first(where: { $0.dayOfWeek.lowercased() == todayName }),
              !todayHours.isClosed else {
            return nil
        }

        // Convert "21:00" to "9:00 PM"
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if let date = formatter.date(from: todayHours.closeTime) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        }
        return todayHours.closeTime
    }
}

// MARK: - Restaurant Model
struct Restaurant: Identifiable, Hashable {
    let id: String
    let name: String
    let rating: Double
    let ratingCount: Int
    let distanceKm: Double
    let address: String
    let heroImageName: String
    let foodIcon: String // SF Symbol for placeholder
    var latitude: Double?
    var longitude: Double?
    var phone: String?
    var openingHours: [OpeningHours]
    var totalOrders: Int

    init(id: String, name: String, rating: Double, ratingCount: Int, distanceKm: Double, address: String, heroImageName: String, foodIcon: String, latitude: Double? = nil, longitude: Double? = nil, phone: String? = nil, openingHours: [OpeningHours] = [], totalOrders: Int = 0) {
        self.id = id
        self.name = name
        self.rating = rating
        self.ratingCount = ratingCount
        self.distanceKm = distanceKm
        self.address = address
        self.heroImageName = heroImageName
        self.foodIcon = foodIcon
        self.latitude = latitude
        self.longitude = longitude
        self.phone = phone
        self.openingHours = openingHours
        self.totalOrders = totalOrders
    }

    var isOpenNow: Bool {
        OpeningHours.isOpenNow(hours: openingHours)
    }

    var closingTimeToday: String? {
        OpeningHours.closingTimeToday(hours: openingHours)
    }

    static func == (lhs: Restaurant, rhs: Restaurant) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Bag Model
struct Bag: Identifiable, Hashable {
    let id: String
    let restaurantId: String
    let title: String
    let description: String
    let priceNow: Double
    let priceWas: Double
    let pickupStart: Date
    let pickupEnd: Date
    let quantityLeft: Int
    let foodType: String
    let badges: [String]
    let allergens: [String]

    var pickupWindowFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: pickupStart)) - \(formatter.string(from: pickupEnd))"
    }

    var savingsPercentage: Int {
        Int(((priceWas - priceNow) / priceWas) * 100)
    }

    static func == (lhs: Bag, rhs: Bag) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Order Model
struct Order: Identifiable, Hashable {
    let id: String
    let bagId: String
    let restaurantId: String
    var status: OrderStatus
    let pickupStart: Date
    let pickupEnd: Date
    let qrString: String
    let createdAt: Date
    let quantity: Int
    let totalPaid: Double
    var review: Review?

    static func == (lhs: Order, rhs: Order) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Order Status
enum OrderStatus: String, CaseIterable {
    case paid = "Paid"
    case ready = "Ready"
    case collected = "Collected"
    case cancelled = "Cancelled"

    var color: Color {
        switch self {
        case .paid: return DesignSystem.Colors.warning
        case .ready: return DesignSystem.Colors.accent
        case .collected: return DesignSystem.Colors.success
        case .cancelled: return DesignSystem.Colors.error
        }
    }

    var icon: String {
        switch self {
        case .paid: return "creditcard.fill"
        case .ready: return "checkmark.circle.fill"
        case .collected: return "bag.fill.badge.checkmark"
        case .cancelled: return "xmark.circle.fill"
        }
    }
}

// MARK: - Review Model
struct Review: Hashable {
    let rating: Int
    let text: String
    let createdAt: Date
}

// MARK: - Location Model
struct UserLocation: Equatable {
    let latitude: Double
    let longitude: Double
}

// MARK: - User Model
struct User: Identifiable {
    let id: String
    var email: String
    var name: String
    var location: UserLocation?
    var preferences: [String]
    var loyaltyPoints: Int
    var notificationsEnabled: Bool

    var locationString: String {
        guard let loc = location else { return "Location not set" }
        // Format as coordinates if we don't have reverse geocoded address
        return String(format: "%.4f, %.4f", loc.latitude, loc.longitude)
    }
}

// MARK: - Filter Options
struct FilterOptions: Codable {
    var priceRangeLower: Double = 0
    var priceRangeUpper: Double = 200
    var maxDistance: Double = 10.0
    var foodTypes: Set<String> = []
    var pickupTime: PickupTimeFilter = .anytime
    var minRating: Double = 0

    var priceRange: ClosedRange<Double> {
        get { priceRangeLower...priceRangeUpper }
        set {
            priceRangeLower = newValue.lowerBound
            priceRangeUpper = newValue.upperBound
        }
    }

    enum PickupTimeFilter: String, CaseIterable, Codable {
        case anytime = "Anytime"
        case now = "Available Now"
        case today = "Today"
        case tomorrow = "Tomorrow"
    }

    // Persistence
    static func load() -> FilterOptions {
        guard let data = UserDefaults.standard.data(forKey: "filterOptions"),
              let options = try? JSONDecoder().decode(FilterOptions.self, from: data) else {
            return FilterOptions()
        }
        return options
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "filterOptions")
        }
    }
}

// MARK: - Cuisine/Food Type
struct FoodCategory: Identifiable {
    let id: String
    let name: String
    let icon: String
}

// MARK: - Saved Address Model
struct SavedAddress: Identifiable, Equatable {
    let id: String
    let name: String
    let shortName: String
    let fullAddress: String
    let icon: String
    let type: AddressType
    var latitude: Double?
    var longitude: Double?

    enum AddressType: String, Codable {
        case home, work, current, saved
    }

    static func currentLocation(address: String?, lat: Double?, lng: Double?) -> SavedAddress {
        // Extract just the locality/city for short display (e.g., "Cape Town" from "123 Main St, Cape Town, Western Cape")
        let shortName: String
        if let address = address {
            let components = address.components(separatedBy: ", ")
            // Use second component (locality) if available, otherwise first
            if components.count >= 2 {
                shortName = components[1]
            } else {
                shortName = components.first ?? address
            }
        } else {
            shortName = "Locating..."
        }

        return SavedAddress(
            id: "current",
            name: "Current Location",
            shortName: shortName,
            fullAddress: address ?? "Getting your location...",
            icon: "location.fill",
            type: .current,
            latitude: lat,
            longitude: lng
        )
    }
}

// MARK: - Persisted Address (for UserDefaults storage)
struct PersistedAddress: Codable {
    let id: String
    let name: String
    let shortName: String
    let fullAddress: String
    let icon: String
    let type: SavedAddress.AddressType
    let latitude: Double?
    let longitude: Double?

    init(from address: SavedAddress) {
        self.id = address.id
        self.name = address.name
        self.shortName = address.shortName
        self.fullAddress = address.fullAddress
        self.icon = address.icon
        self.type = address.type
        self.latitude = address.latitude
        self.longitude = address.longitude
    }

    func toSavedAddress() -> SavedAddress {
        SavedAddress(
            id: id,
            name: name,
            shortName: shortName,
            fullAddress: fullAddress,
            icon: icon,
            type: type,
            latitude: latitude,
            longitude: longitude
        )
    }
}

// MARK: - Preview Data (DEBUG only)
#if DEBUG
enum PreviewData {
    static let sampleRestaurant = Restaurant(
        id: "preview_rest",
        name: "Preview Restaurant",
        rating: 4.5,
        ratingCount: 100,
        distanceKm: 1.0,
        address: "1 Ferry Building, San Francisco",
        heroImageName: "",
        foodIcon: "fork.knife",
        latitude: 37.7956,
        longitude: -122.3933
    )

    static var sampleBag: Bag {
        Bag(
            id: "preview_bag",
            restaurantId: "preview_rest",
            title: "Preview Bag",
            description: "This is a preview bag for SwiftUI previews only.",
            priceNow: 45,
            priceWas: 120,
            pickupStart: Date(),
            pickupEnd: Date().addingTimeInterval(3600),
            quantityLeft: 3,
            foodType: "Preview",
            badges: ["Preview"],
            allergens: []
        )
    }

    static var sampleOrder: Order {
        Order(
            id: "preview_order",
            bagId: "preview_bag",
            restaurantId: "preview_rest",
            status: .paid,
            pickupStart: Date(),
            pickupEnd: Date().addingTimeInterval(3600),
            qrString: "PREVIEW-QR",
            createdAt: Date(),
            quantity: 1,
            totalPaid: 47.50
        )
    }
}
#endif
