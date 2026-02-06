//
//  BagService.swift
//  KULA
//
//  Bag & Restaurant API Service
//

import Foundation

class BagService {
    static let shared = BagService()
    private let client = APIClient.shared

    private init() {}

    // MARK: - Get Categories
    func getCategories() async throws -> [FoodCategory] {
        let response: [APICategory] = try await client.get(
            path: "/categories",
            authenticated: false
        )
        return response.map { $0.toFoodCategory() }
    }

    // MARK: - Get Bags
    func getBags(
        latitude: Double? = nil,
        longitude: Double? = nil,
        maxDistance: Double? = nil,
        minPrice: Double? = nil,
        maxPrice: Double? = nil,
        foodTypes: [String]? = nil,
        minRating: Double? = nil,
        search: String? = nil,
        sort: String? = nil,
        limit: Int = 20,
        page: Int = 1
    ) async throws -> [Bag] {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "page", value: "\(page)")
        ]

        if let lat = latitude, let lng = longitude {
            queryItems.append(URLQueryItem(name: "latitude", value: "\(lat)"))
            queryItems.append(URLQueryItem(name: "longitude", value: "\(lng)"))
        }

        if let maxDist = maxDistance {
            queryItems.append(URLQueryItem(name: "maxDistanceKm", value: "\(maxDist)"))
        }

        if let minP = minPrice {
            queryItems.append(URLQueryItem(name: "minPrice", value: "\(Int(minP * 100))"))
        }

        if let maxP = maxPrice {
            queryItems.append(URLQueryItem(name: "maxPrice", value: "\(Int(maxP * 100))"))
        }

        if let types = foodTypes, !types.isEmpty {
            queryItems.append(URLQueryItem(name: "foodTypes", value: types.joined(separator: ",")))
        }

        if let rating = minRating, rating > 0 {
            queryItems.append(URLQueryItem(name: "minRating", value: "\(rating)"))
        }

        if let searchText = search, !searchText.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: searchText))
        }

        if let sortBy = sort {
            queryItems.append(URLQueryItem(name: "sort", value: sortBy))
        }

        let response: [APIBag] = try await client.get(
            path: "/bags",
            queryItems: queryItems,
            authenticated: TokenManager.shared.isLoggedIn
        )

        return response.map { $0.toBag() }
    }

    // MARK: - Get Personalized Bags
    func getPersonalizedBags(latitude: Double? = nil, longitude: Double? = nil, limit: Int = 10) async throws -> [Bag] {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        if let lat = latitude, let lng = longitude {
            queryItems.append(URLQueryItem(name: "latitude", value: "\(lat)"))
            queryItems.append(URLQueryItem(name: "longitude", value: "\(lng)"))
        }

        let response: [APIBag] = try await client.get(
            path: "/bags/personalized",
            queryItems: queryItems
        )

        return response.map { $0.toBag() }
    }

    // MARK: - Get Bag Details
    func getBag(id: String, latitude: Double? = nil, longitude: Double? = nil) async throws -> (Bag, Restaurant?) {
        var queryItems: [URLQueryItem] = []

        if let lat = latitude, let lng = longitude {
            queryItems.append(URLQueryItem(name: "latitude", value: "\(lat)"))
            queryItems.append(URLQueryItem(name: "longitude", value: "\(lng)"))
        }

        let response: APIBag = try await client.get(
            path: "/bags/\(id)",
            queryItems: queryItems.isEmpty ? nil : queryItems,
            authenticated: TokenManager.shared.isLoggedIn
        )

        return (response.toBag(), response.restaurant?.toRestaurant())
    }

    // MARK: - Get Restaurants
    func getRestaurants(latitude: Double? = nil, longitude: Double? = nil, limit: Int = 20) async throws -> [Restaurant] {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        if let lat = latitude, let lng = longitude {
            queryItems.append(URLQueryItem(name: "latitude", value: "\(lat)"))
            queryItems.append(URLQueryItem(name: "longitude", value: "\(lng)"))
        }

        let response: [APIRestaurant] = try await client.get(
            path: "/restaurants",
            queryItems: queryItems,
            authenticated: false
        )

        return response.map { $0.toRestaurant() }
    }

    // MARK: - Get Restaurant Details
    func getRestaurant(id: String) async throws -> Restaurant {
        let response: APIRestaurant = try await client.get(
            path: "/restaurants/\(id)",
            authenticated: false
        )
        return response.toRestaurant()
    }

    // MARK: - Favorites
    func getFavorites() async throws -> [Bag] {
        let response: [APIBag] = try await client.get(path: "/favorites")
        return response.map { $0.toBag() }
    }

    func addFavorite(bagId: String) async throws -> Bool {
        let response: FavoriteResponse = try await client.post(path: "/favorites/\(bagId)")
        return response.isFavorited
    }

    func removeFavorite(bagId: String) async throws -> Bool {
        let response: FavoriteResponse = try await client.delete(path: "/favorites/\(bagId)")
        return response.isFavorited
    }

    func toggleFavorite(bagId: String, isFavorited: Bool) async throws -> Bool {
        if isFavorited {
            return try await removeFavorite(bagId: bagId)
        } else {
            return try await addFavorite(bagId: bagId)
        }
    }
}
