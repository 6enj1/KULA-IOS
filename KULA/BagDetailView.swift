//
//  BagDetailView.swift
//  KULA
//
//  Bag Detail Screen
//

import SwiftUI

struct BagDetailView: View {
    let bag: Bag
    let restaurant: Restaurant

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var quantity: Int = 1
    @State private var showCheckout = false
    @State private var isSaved = false
    @State private var showDirections = false

    var body: some View {
        ZStack {
            AppBackgroundGradient()

            ScrollView {
                VStack(spacing: 0) {
                    // Hero Image Carousel
                    heroSection

                    // Content
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Restaurant Info
                        restaurantInfoSection

                        // What's in the bag
                        bagContentsSection

                        // Allergens
                        if !bag.allergens.isEmpty {
                            allergensSection
                        }

                        // Pickup Details
                        pickupSection

                        // Quantity Selector
                        quantitySection
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .padding(.bottom, 90) // CTA + navbar space
                }
            }

            // Sticky Bottom CTA
            VStack {
                Spacer()
                bottomCTA
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // Share button
                    Button {
                        // Share action
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    // Save button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isSaved.toggle()
                            appState.toggleSaved(bagId: bag.id)
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: isSaved ? "heart.fill" : "heart")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isSaved ? DesignSystem.Colors.saved : .white)
                    }
                }
            }
        }
        .onAppear {
            isSaved = appState.isSaved(bagId: bag.id)
        }
        .fullScreenCover(isPresented: $showCheckout) {
            CheckoutView(bag: bag, restaurant: restaurant, quantity: quantity)
        }
        .sheet(isPresented: $showDirections) {
            DirectionsSheetView(restaurant: restaurant)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: showDirections) { _, isShowing in
            appState.showDirectionsSheet = isShowing
        }
    }

    // MARK: - Hero Section
    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Hero image placeholder
            ZStack {
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.primaryGreen.opacity(0.6),
                        DesignSystem.Colors.deepTeal
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: restaurant.foodIcon)
                    .font(.system(size: 80))
                    .foregroundStyle(.white.opacity(0.2))

                // Gradient overlay
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 150)
                }
            }
            .frame(height: 280)

            // Badges overlay
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                // Selling fast
                if bag.quantityLeft <= 3 {
                    TagPill(text: "Only \(bag.quantityLeft) left!", style: .warning, icon: "flame.fill")
                }

                // Savings badge
                TagPill(text: "Save \(bag.savingsPercentage)%", style: .accent, icon: "leaf.fill")
            }
            .padding(DesignSystem.Spacing.lg)
        }
    }

    // MARK: - Restaurant Info Section
    private var restaurantInfoSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(restaurant.name)
                            .font(DesignSystem.Typography.title2)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        RatingRow(rating: restaurant.rating, count: restaurant.ratingCount)
                    }

                    Spacer()

                    // Distance badge (tappable)
                    Button {
                        showDirections = true
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 14))
                            Text(String(format: "%.1f km", restaurant.distanceKm))
                                .font(DesignSystem.Typography.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(DesignSystem.Colors.accent)
                    }
                }

                Divider()
                    .background(DesignSystem.Colors.glassBorder)

                // Address with open in maps
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)

                    Text(restaurant.address)
                        .font(DesignSystem.Typography.subheadline)
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
            }
        }
    }

    // MARK: - Bag Contents Section
    private var bagContentsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "bag.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(DesignSystem.Colors.accent)

                    Text("What's in the bag?")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }

                Text(bag.title)
                    .font(DesignSystem.Typography.title3)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text(bag.description)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Food type tag
                HStack(spacing: DesignSystem.Spacing.xs) {
                    TagPill(text: bag.foodType, style: .default)

                    ForEach(bag.badges, id: \.self) { badge in
                        TagPill(text: badge, style: .accent)
                    }
                }
            }
        }
    }

    // MARK: - Allergens Section
    private var allergensSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(DesignSystem.Colors.warning)

                    Text("Allergen Information")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }

                Text("This bag may contain:")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                FlowLayout(spacing: DesignSystem.Spacing.xs) {
                    ForEach(bag.allergens, id: \.self) { allergen in
                        TagPill(text: allergen, style: .allergen)
                    }
                }
            }
        }
    }

    // MARK: - Pickup Section
    private var pickupSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(DesignSystem.Colors.accent)

                    Text("Pickup Details")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }

                HStack(spacing: DesignSystem.Spacing.lg) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pickup Window")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)

                        Text(bag.pickupWindowFormatted)
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)

                        Text(formatDate(bag.pickupStart))
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                    }
                }

                // Important notice
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)

                    Text("Please arrive within the pickup window. Late pickups cannot be guaranteed.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
        }
    }

    // MARK: - Quantity Section
    private var quantitySection: some View {
        GlassCard {
            HStack {
                Text("Quantity")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Spacer()

                // Stepper
                HStack(spacing: DesignSystem.Spacing.md) {
                    Button {
                        if quantity > 1 {
                            quantity -= 1
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(quantity > 1 ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
                            .frame(width: 36, height: 36)
                            .background {
                                Circle()
                                    .fill(DesignSystem.Colors.glassFill)
                            }
                    }
                    .disabled(quantity <= 1)

                    Text("\(quantity)")
                        .font(DesignSystem.Typography.title3)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .frame(minWidth: 30)

                    Button {
                        if quantity < bag.quantityLeft {
                            quantity += 1
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(quantity < bag.quantityLeft ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
                            .frame(width: 36, height: 36)
                            .background {
                                Circle()
                                    .fill(DesignSystem.Colors.glassFill)
                            }
                    }
                    .disabled(quantity >= bag.quantityLeft)
                }
            }
        }
    }

    // MARK: - Bottom CTA
    private var bottomCTA: some View {
        VStack(spacing: 0) {
            // Subtle top border
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.15), .white.opacity(0.05), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.5)

            HStack(spacing: DesignSystem.Spacing.lg) {
                // Price
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("R\(Int(bag.priceNow * Double(quantity)))")
                            .font(DesignSystem.Typography.price)
                            .foregroundStyle(DesignSystem.Colors.accent)

                        Text("R\(Int(bag.priceWas * Double(quantity)))")
                            .font(DesignSystem.Typography.priceStrike)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .strikethrough()
                    }

                    Text("+ R2.50 platform fee")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }

                Spacer()

                // Reserve button
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showCheckout = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bag.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Reserve")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background {
                        Capsule()
                            .fill(DesignSystem.Colors.accent)
                            .shadow(color: DesignSystem.Colors.accent.opacity(0.4), radius: 12, y: 4)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.md)
            .padding(.bottom, 80) // Clear the floating navbar
        }
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay {
                    LinearGradient(
                        colors: [.white.opacity(0.08), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea()
        }
    }

    // MARK: - Helpers
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        BagDetailView(
            bag: PreviewData.sampleBag,
            restaurant: PreviewData.sampleRestaurant
        )
    }
    .environmentObject(AppState())
}
