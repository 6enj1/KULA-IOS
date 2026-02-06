//
//  OrdersView.swift
//  KULA
//
//  Orders and Pickup Screen
//

import SwiftUI

// MARK: - Orders View
struct OrdersView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: OrderTab = .active
    @State private var selectedOrderForReview: Order?

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    enum OrderTab: String, CaseIterable {
        case active = "Active"
        case past = "Past"
    }

    var body: some View {
        ZStack {
            AppBackgroundGradient()

            VStack(spacing: DesignSystem.Spacing.lg) {
                // Header
                VStack(spacing: DesignSystem.Spacing.md) {
                    Text("My Orders")
                        .font(DesignSystem.Typography.title1)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Segmented control
                    GlassSegmentedControl(selection: $selectedTab)
                }
                .adaptivePadding()
                                .padding(.top, isRegularWidth ? DesignSystem.Spacing.xxl : DesignSystem.Spacing.md)

                // Content
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        if appState.isLoading {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(DesignSystem.Colors.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.top, DesignSystem.Spacing.xxl)
                        } else {
                            switch selectedTab {
                            case .active:
                                activeOrdersContent
                            case .past:
                                pastOrdersContent
                            }
                        }
                    }
                    .adaptivePadding()
                                        .padding(.bottom, isRegularWidth ? 140 : 120)
                }
                .refreshable {
                    await appState.refreshOrders()
                }
            }
        }
        .sheet(item: $selectedOrderForReview) { order in
            ReviewSheet(order: order)
                .presentationDetents(DesignSystem.Layout.sheetDetents(isRegular: isRegularWidth))
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Active Orders Content
    @ViewBuilder
    private var activeOrdersContent: some View {
        if appState.activeOrders.isEmpty {
            emptyStateView(
                icon: "bag",
                title: "No active orders",
                message: "When you reserve a bag, it will appear here"
            )
        } else {
            ForEach(appState.activeOrders) { order in
                ActiveOrderCard(order: order)
            }
        }
    }

    // MARK: - Past Orders Content
    @ViewBuilder
    private var pastOrdersContent: some View {
        if appState.pastOrders.isEmpty {
            emptyStateView(
                icon: "clock.arrow.circlepath",
                title: "No past orders",
                message: "Your order history will appear here"
            )
        } else {
            ForEach(appState.pastOrders) { order in
                PastOrderCard(order: order) {
                    selectedOrderForReview = order
                }
            }
        }
    }

    // MARK: - Empty State View
    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.glassFill)
                    .frame(width: 100, height: 100)

                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }

            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text(message)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xxxl)
    }
}

// MARK: - Active Order Card
struct ActiveOrderCard: View {
    let order: Order
    @EnvironmentObject var appState: AppState
    @State private var showImHereConfirmation = false
    @State private var showDirections = false

    private var restaurant: Restaurant? {
        appState.restaurant(for: order.restaurantId)
    }

    private var bag: Bag? {
        appState.bag(for: order.bagId)
    }

    var body: some View {
        GlassCard {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Header with status
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(restaurant?.name ?? "Restaurant")
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        Text(bag?.title ?? "Surprise Bag")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }

                    Spacer()

                    OrderStatusChip(status: order.status)
                }

                // QR Code - Large and centered
                VStack(spacing: DesignSystem.Spacing.md) {
                    QRCodeView(qrString: order.qrString, size: 180)

                    Text("Show this code at pickup")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }

                // Countdown Timer
                CountdownTimerView(targetDate: order.pickupStart)

                // Pickup details
                Divider()
                    .background(DesignSystem.Colors.glassBorder)

                HStack(spacing: DesignSystem.Spacing.lg) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pickup Window")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)

                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 12))
                            Text(formatPickupWindow())
                        }
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Quantity")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)

                        Text("\(order.quantity) bag\(order.quantity > 1 ? "s" : "")")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                    }
                }

                // Address
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignSystem.Colors.accent)

                    Text(restaurant?.address ?? "Address")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    Spacer()

                    Button {
                        showDirections = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("Directions")
                                .font(DesignSystem.Typography.caption)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(DesignSystem.Colors.accent)
                    }
                }

                // I'm Here button
                if order.status == .paid {
                    SecondaryButton("I'm Here", icon: "hand.raised.fill") {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        Task {
                            await appState.markArrived(orderId: order.id)
                            showImHereConfirmation = true
                        }
                    }
                }
            }
        }
        .alert("Notification Sent", isPresented: $showImHereConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The restaurant has been notified that you've arrived. Please wait for your bag to be prepared.")
        }
        .fullScreenCover(isPresented: $showDirections) {
            if let restaurant = restaurant {
                RoutePreviewSheet(restaurant: restaurant)
            }
        }
    }

    private func formatPickupWindow() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: order.pickupStart)) - \(formatter.string(from: order.pickupEnd))"
    }
}

// MARK: - Past Order Card
struct PastOrderCard: View {
    let order: Order
    var onLeaveReview: () -> Void
    @EnvironmentObject var appState: AppState

    private var restaurant: Restaurant? {
        appState.restaurant(for: order.restaurantId)
    }

    private var bag: Bag? {
        appState.bag(for: order.bagId)
    }

    var body: some View {
        GlassCard {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Header
                HStack(alignment: .top) {
                    // Restaurant image placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        DesignSystem.Colors.primaryGreen.opacity(0.6),
                                        DesignSystem.Colors.deepTeal
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Image(systemName: restaurant?.foodIcon ?? "bag.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(width: 50, height: 50)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(restaurant?.name ?? "Restaurant")
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        Text(bag?.title ?? "Surprise Bag")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)

                        Text(formatDate(order.createdAt))
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        OrderStatusChip(status: order.status)

                        Text("R\(String(format: "%.2f", order.totalPaid))")
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                    }
                }

                // Review section
                if order.status == .collected {
                    Divider()
                        .background(DesignSystem.Colors.glassBorder)

                    if let review = order.review {
                        // Show existing review
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            HStack(spacing: 4) {
                                Text("Your review")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)

                                Spacer()

                                // Stars
                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: star <= review.rating ? "star.fill" : "star")
                                            .font(.system(size: 12))
                                            .foregroundStyle(DesignSystem.Colors.warmAmber)
                                    }
                                }
                            }

                            if !review.text.isEmpty {
                                Text(review.text)
                                    .font(DesignSystem.Typography.subheadline)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                                    .lineLimit(2)
                            }
                        }
                    } else {
                        // Leave review button
                        Button {
                            onLeaveReview()
                        } label: {
                            HStack {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 14))
                                Text("Leave a Review")
                                    .font(DesignSystem.Typography.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(DesignSystem.Colors.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .background {
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                    .fill(DesignSystem.Colors.accent.opacity(0.1))
                            }
                        }
                    }
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Review Sheet
struct ReviewSheet: View {
    let order: Order
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var rating: Int = 0
    @State private var reviewText: String = ""
    @FocusState private var isTextFocused: Bool

    private var restaurant: Restaurant? {
        appState.restaurant(for: order.restaurantId)
    }

    var body: some View {
        ZStack {
            AppBackgroundGradient()

            VStack(spacing: DesignSystem.Spacing.xl) {
                // Header
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("How was your experience?")
                        .font(DesignSystem.Typography.title2)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Text(restaurant?.name ?? "Restaurant")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .padding(.top, DesignSystem.Spacing.xl)

                // Star rating
                HStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                rating = star
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 40))
                                .foregroundStyle(star <= rating ? DesignSystem.Colors.warmAmber : DesignSystem.Colors.textTertiary)
                                .scaleEffect(star <= rating ? 1.1 : 1.0)
                        }
                    }
                }

                // Text field
                GlassCard(padding: 0) {
                    TextField("Share your thoughts (optional)", text: $reviewText, axis: .vertical)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .padding(DesignSystem.Spacing.md)
                        .frame(minHeight: 100, alignment: .top)
                        .focused($isTextFocused)
                }

                Spacer()

                // Submit button
                PrimaryButton("Submit Review", icon: "checkmark") {
                    Task {
                        await appState.addReview(orderId: order.id, rating: rating, text: reviewText)
                        dismiss()
                    }
                }
                .disabled(rating == 0)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
    }
}

#Preview {
    NavigationStack {
        OrdersView()
    }
    .environmentObject(AppState())
}
