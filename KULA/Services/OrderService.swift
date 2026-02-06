//
//  OrderService.swift
//  KULA
//
//  Order & Payment API Service
//

import Foundation
import UIKit

class OrderService {
    static let shared = OrderService()
    private let client = APIClient.shared

    private init() {}

    // MARK: - Get Orders
    func getOrders(status: String? = nil, limit: Int = 20, page: Int = 1) async throws -> [Order] {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "page", value: "\(page)")
        ]

        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }

        let response: [APIOrder] = try await client.get(
            path: "/orders",
            queryItems: queryItems
        )

        return response.map { $0.toOrder() }
    }

    // MARK: - Get Active Orders
    func getActiveOrders() async throws -> [Order] {
        let response: [APIOrder] = try await client.get(path: "/orders/active")
        return response.map { $0.toOrder() }
    }

    // MARK: - Get Past Orders
    func getPastOrders(limit: Int = 20, page: Int = 1) async throws -> [Order] {
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "page", value: "\(page)")
        ]

        let response: [APIOrder] = try await client.get(
            path: "/orders/past",
            queryItems: queryItems
        )

        return response.map { $0.toOrder() }
    }

    // MARK: - Get Order Details
    func getOrder(id: String) async throws -> Order {
        let response: APIOrder = try await client.get(path: "/orders/\(id)")
        return response.toOrder()
    }

    // MARK: - Create Order (with Yoco payment)
    struct CreateOrderResult {
        let order: Order
        let paymentUrl: String
        let checkoutId: String
    }

    func createOrder(bagId: String, quantity: Int) async throws -> CreateOrderResult {
        let body = CreateOrderRequest(bagId: bagId, quantity: quantity)
        let response: OrderWithCheckout = try await client.post(
            path: "/orders",
            body: body
        )

        return CreateOrderResult(
            order: response.order.toOrder(),
            paymentUrl: response.checkout.paymentUrl,
            checkoutId: response.checkout.id
        )
    }

    // MARK: - Open Payment URL
    func openPaymentUrl(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }

        DispatchQueue.main.async {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Check Payment Status
    struct PaymentStatus: Decodable {
        let orderId: String
        let orderNumber: String
        let orderStatus: String
        let paymentStatus: String
        let paidAt: Date?
    }

    func checkPaymentStatus(orderId: String) async throws -> PaymentStatus {
        return try await client.get(path: "/payments/status/\(orderId)")
    }

    // MARK: - Mark Arrived ("I'm Here")
    func markArrived(orderId: String) async throws -> Order {
        let response: APIOrder = try await client.post(path: "/orders/\(orderId)/arrived")
        return response.toOrder()
    }

    // MARK: - Cancel Order
    func cancelOrder(orderId: String, reason: String? = nil) async throws {
        struct CancelRequest: Encodable {
            let reason: String?
        }

        let _: MessageResponse = try await client.post(
            path: "/orders/\(orderId)/cancel",
            body: CancelRequest(reason: reason)
        )
    }

    // MARK: - Submit Review
    func submitReview(orderId: String, rating: Int, text: String?) async throws {
        let body = CreateReviewRequest(rating: rating, text: text)
        let _: APIReview = try await client.post(
            path: "/orders/\(orderId)/review",
            body: body
        )
    }
}
