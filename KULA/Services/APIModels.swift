//
//  APIModels.swift
//  KULA
//
//  API Response Models (Codable)
//

import Foundation

// MARK: - API User
struct APIUser: Codable, Identifiable {
    let id: String
    let email: String?        // Optional for partial responses
    let name: String?         // Optional for partial responses
    let role: String?         // Optional for partial responses
    let phone: String?
    let avatarUrl: String?
    let preferences: [String]?
    let loyaltyPoints: Int?
    let latitude: Double?
    let longitude: Double?
    let notificationsEnabled: Bool?
    let createdAt: Date?      // Optional for partial responses

    func toUser() -> User {
        User(
            id: id,
            email: email ?? "",
            name: name ?? "",
            location: latitude != nil && longitude != nil
                ? UserLocation(latitude: latitude!, longitude: longitude!)
                : nil,
            preferences: preferences ?? [],
            loyaltyPoints: loyaltyPoints ?? 0,
            notificationsEnabled: notificationsEnabled ?? true
        )
    }
}

// MARK: - API Category
struct APICategory: Codable, Identifiable {
    let id: String
    let name: String
    let slug: String?  // Optional - not included when embedded in restaurants
    let icon: String
    let emoji: String?

    func toFoodCategory() -> FoodCategory {
        FoodCategory(id: id, name: name, icon: icon)
    }
}

// MARK: - API Opening Hours
struct APIOpeningHours: Codable {
    let dayOfWeek: String
    let openTime: String
    let closeTime: String
    let isClosed: Bool

    func toOpeningHours() -> OpeningHours {
        OpeningHours(
            dayOfWeek: dayOfWeek,
            openTime: openTime,
            closeTime: closeTime,
            isClosed: isClosed
        )
    }
}

// MARK: - API Restaurant
struct APIRestaurant: Codable, Identifiable {
    let id: String
    let name: String
    let slug: String?
    let description: String?
    let logoUrl: String?
    let heroImageUrl: String?
    let addressLine1: String?
    let city: String?
    let latitude: Double
    let longitude: Double
    let ratingAvg: Double
    let ratingCount: Int
    let distanceKm: Double?
    let phone: String?
    let categories: [APICategory]?
    let openingHours: [APIOpeningHours]?
    let totalOrders: Int?

    func toRestaurant() -> Restaurant {
        Restaurant(
            id: id,
            name: name,
            rating: ratingAvg,
            ratingCount: ratingCount,
            distanceKm: distanceKm ?? 0,
            address: [addressLine1, city].compactMap { $0 }.joined(separator: ", "),
            heroImageName: heroImageUrl ?? "",
            foodIcon: categories?.first?.icon ?? "fork.knife",
            latitude: latitude,
            longitude: longitude,
            phone: phone,
            openingHours: openingHours?.map { $0.toOpeningHours() } ?? [],
            totalOrders: totalOrders ?? 0
        )
    }
}

// MARK: - API Bag
struct APIBag: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let foodType: String
    let priceOriginal: Int
    let priceCurrent: Int
    let quantityTotal: Int
    let quantityRemaining: Int
    let pickupStart: Date
    let pickupEnd: Date
    let badges: [String]
    let allergens: [String]
    let dietaryInfo: [String]?
    let imageUrl: String?
    let isActive: Bool?
    let isSoldOut: Bool?
    let isFavorited: Bool?
    let distanceKm: Double?
    let savingsPercent: Int?
    let restaurant: APIRestaurant?
    let restaurantId: String?

    func toBag() -> Bag {
        Bag(
            id: id,
            restaurantId: restaurant?.id ?? restaurantId ?? "",
            title: title,
            description: description,
            priceNow: Double(priceCurrent) / 100.0, // Convert cents to Rands
            priceWas: Double(priceOriginal) / 100.0,
            pickupStart: pickupStart,
            pickupEnd: pickupEnd,
            quantityLeft: quantityRemaining,
            foodType: foodType,
            badges: badges,
            allergens: allergens
        )
    }
}

// MARK: - API Order
struct APIOrder: Codable, Identifiable {
    let id: String
    let orderNumber: String
    let quantity: Int
    let subtotal: Int
    let platformFee: Int
    let total: Int
    let status: String
    let pickupStart: Date
    let pickupEnd: Date
    let qrCode: String
    let customerArrivedAt: Date?
    let qrScannedAt: Date?
    let createdAt: Date
    let bag: APIBagSummary?
    let restaurant: APIRestaurantSummary?
    let review: APIReview?

    func toOrder() -> Order {
        Order(
            id: id,
            bagId: bag?.id ?? "",
            restaurantId: restaurant?.id ?? "",
            status: OrderStatus(rawValue: status.capitalized) ?? .paid,
            pickupStart: pickupStart,
            pickupEnd: pickupEnd,
            qrString: qrCode,
            createdAt: createdAt,
            quantity: quantity,
            totalPaid: Double(total) / 100.0,
            review: review?.toReview()
        )
    }
}

struct APIBagSummary: Codable {
    let id: String
    let title: String
    let imageUrl: String?
    let priceCurrent: Int?
}

struct APIRestaurantSummary: Codable {
    let id: String
    let name: String
    let addressLine1: String?
    let city: String?
    let latitude: Double?
    let longitude: Double?
    let phone: String?
}

// MARK: - API Review
struct APIReview: Codable {
    let id: String?
    let rating: Int
    let text: String?
    let createdAt: Date

    func toReview() -> Review {
        Review(rating: rating, text: text ?? "", createdAt: createdAt)
    }
}

// MARK: - Request Bodies
struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct RegisterRequest: Encodable {
    let email: String
    let password: String
    let name: String
    let role: String
}

struct SocialAuthRequest: Encodable {
    let provider: String
    let token: String
    let email: String?
    let name: String?
}

struct CreateOrderRequest: Encodable {
    let bagId: String
    let quantity: Int
}

struct CreateReviewRequest: Encodable {
    let rating: Int
    let text: String?
}

struct UpdateLocationRequest: Encodable {
    let latitude: Double
    let longitude: Double
}

struct UpdatePreferencesRequest: Encodable {
    let preferences: [String]
}

// MARK: - Simple Response Types
struct MessageResponse: Decodable {
    let message: String?
}

struct FavoriteResponse: Decodable {
    let isFavorited: Bool
}
