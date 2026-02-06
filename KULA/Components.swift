//
//  Components.swift
//  KULA
//
//  Reusable UI Components
//

import SwiftUI
import Combine
import CoreImage.CIFilterBuiltins

// MARK: - Glass Card Container
struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = DesignSystem.Spacing.md
    var cornerRadius: CGFloat = DesignSystem.CornerRadius.large

    init(
        padding: CGFloat = DesignSystem.Spacing.md,
        cornerRadius: CGFloat = DesignSystem.CornerRadius.large,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background {
                GlassBackground(cornerRadius: cornerRadius)
            }
            .applyShadow(DesignSystem.Shadows.soft)
    }
}

// MARK: - Primary Button
struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isLoading: Bool = false
    var isDisabled: Bool = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isPressed = false

    private var isRegular: Bool { horizontalSizeClass == .regular }
    private var buttonHeight: CGFloat { DesignSystem.Layout.buttonHeight(isRegular: isRegular) }

    init(
        _ title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            HStack(spacing: isRegular ? DesignSystem.Spacing.sm : DesignSystem.Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.black)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: isRegular ? 18 : 16, weight: .semibold))
                    }
                    Text(title)
                        .font(DesignSystem.ScaledTypography.headline(isRegular: isRegular))
                }
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: buttonHeight)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.accent,
                                    DesignSystem.Colors.accent.opacity(0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Glow effect
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                        .fill(DesignSystem.Colors.accent.opacity(0.3))
                        .blur(radius: 12)
                        .offset(y: 4)
                }
            }
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.15)) {
                        isPressed = false
                    }
                }
        )
        .accessibilityLabel(title)
    }
}

// MARK: - Secondary Button
struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var style: Style = .default

    enum Style {
        case `default`
        case destructive
    }

    @State private var isPressed = false

    init(
        _ title: String,
        icon: String? = nil,
        style: Style = .default,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    private var foregroundColor: Color {
        switch style {
        case .default: return DesignSystem.Colors.accent
        case .destructive: return DesignSystem.Colors.error
        }
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(DesignSystem.Typography.headline)
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                GlassBackground(cornerRadius: DesignSystem.CornerRadius.medium)
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                    .strokeBorder(foregroundColor.opacity(0.3), lineWidth: 1)
            }
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.15)) {
                        isPressed = false
                    }
                }
        )
        .accessibilityLabel(title)
    }
}

// MARK: - Social Auth Button
struct SocialAuthButton: View {
    let provider: Provider
    let action: () -> Void

    enum Provider {
        case apple
        case google
        case email

        var title: String {
            switch self {
            case .apple: return "Continue with Apple"
            case .google: return "Continue with Google"
            case .email: return "Continue with Email"
            }
        }

        var icon: String {
            switch self {
            case .apple: return "apple.logo"
            case .google: return "globe"
            case .email: return "envelope.fill"
            }
        }
    }

    @State private var isPressed = false

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: provider.icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(provider.title)
                    .font(DesignSystem.Typography.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                GlassBackground(cornerRadius: DesignSystem.CornerRadius.medium)
            }
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.15)) {
                        isPressed = false
                    }
                }
        )
        .accessibilityLabel(provider.title)
    }
}

// MARK: - Search Filter Bar
struct SearchFilterBar: View {
    @Binding var searchText: String
    var onFilterTap: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Search field
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)

                TextField("Search restaurants, cuisines...", text: $searchText)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .focused($isFocused)
                    .submitLabel(.search)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .frame(height: 44)
            .background {
                GlassBackground(cornerRadius: DesignSystem.CornerRadius.medium)
            }

            // Filter button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onFilterTap()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .frame(width: 44, height: 44)
                    .background {
                        GlassBackground(cornerRadius: DesignSystem.CornerRadius.medium)
                    }
            }
            .accessibilityLabel("Filters")
        }
    }
}

// MARK: - Tag Pill
struct TagPill: View {
    let text: String
    var style: Style = .default
    var icon: String? = nil

    enum Style {
        case `default`
        case accent
        case warning
        case allergen
    }

    private var backgroundColor: Color {
        switch style {
        case .default: return DesignSystem.Colors.glassFill
        case .accent: return DesignSystem.Colors.accent.opacity(0.2)
        case .warning: return DesignSystem.Colors.sellingFast.opacity(0.2)
        case .allergen: return DesignSystem.Colors.warning.opacity(0.15)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .default: return DesignSystem.Colors.textSecondary
        case .accent: return DesignSystem.Colors.accent
        case .warning: return DesignSystem.Colors.sellingFast
        case .allergen: return DesignSystem.Colors.warning
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(DesignSystem.Typography.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, DesignSystem.Spacing.xs)
        .padding(.vertical, DesignSystem.Spacing.xxs)
        .background {
            Capsule()
                .fill(backgroundColor)
                .overlay {
                    Capsule()
                        .strokeBorder(foregroundColor.opacity(0.3), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Rating Row
struct RatingRow: View {
    let rating: Double
    let count: Int
    var style: Style = .default

    enum Style {
        case `default`
        case compact
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: style == .compact ? 10 : 12, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.warmAmber)

            Text(String(format: "%.1f", rating))
                .font(style == .compact ? DesignSystem.Typography.caption : DesignSystem.Typography.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Text("(\(count))")
                .font(style == .compact ? DesignSystem.Typography.caption2 : DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
    }
}

// MARK: - QR Code View
struct QRCodeView: View {
    let qrString: String
    var size: CGFloat = 200

    var body: some View {
        ZStack {
            // White background for contrast
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                .fill(.white)

            // QR Code
            if let qrImage = generateQRCode(from: qrString) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(DesignSystem.Spacing.md)
            } else {
                // Fallback placeholder
                Image(systemName: "qrcode")
                    .font(.system(size: 80))
                    .foregroundStyle(.black)
            }
        }
        .frame(width: size, height: size)
        .applyShadow(DesignSystem.Shadows.medium)
        .accessibilityLabel("QR Code for pickup")
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        let scale = size / outputImage.extent.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }

        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Bag Listing Card
struct BagListingCard: View {
    let bag: Bag
    let restaurant: Restaurant
    @Binding var isSaved: Bool
    var onTap: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isPressed = false

    private var isRegular: Bool { horizontalSizeClass == .regular }
    private var imageHeight: CGFloat { DesignSystem.Layout.listingImageHeight(isRegular: isRegular) }
    private var cornerRadius: CGFloat { DesignSystem.Layout.cardCornerRadius(isRegular: isRegular) }
    private var contentPadding: CGFloat { DesignSystem.Layout.cardPadding(isRegular: isRegular) }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Hero Image
                ZStack(alignment: .topTrailing) {
                    // Image placeholder with gradient
                    ZStack {
                        Rectangle()
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

                        // Food icon placeholder
                        Image(systemName: restaurant.foodIcon)
                            .font(.system(size: isRegular ? 48 : 40))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(height: imageHeight)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: cornerRadius,
                            topTrailingRadius: cornerRadius
                        )
                    )

                    // Badges
                    VStack(alignment: .trailing, spacing: 6) {
                        // Save button
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                isSaved.toggle()
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: isSaved ? "heart.fill" : "heart")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(isSaved ? DesignSystem.Colors.saved : .white)
                                .frame(width: 36, height: 36)
                                .background {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                }
                        }

                        // Selling Fast badge
                        if bag.quantityLeft <= 3 {
                            TagPill(text: "Selling Fast!", style: .warning, icon: "flame.fill")
                        }
                    }
                    .padding(DesignSystem.Spacing.sm)
                }

                // Content
                VStack(alignment: .leading, spacing: isRegular ? DesignSystem.Spacing.sm : DesignSystem.Spacing.xs) {
                    // Restaurant name and rating
                    HStack {
                        Text(restaurant.name)
                            .font(DesignSystem.ScaledTypography.headline(isRegular: isRegular))
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        RatingRow(rating: restaurant.rating, count: restaurant.ratingCount, style: isRegular ? .default : .compact)
                    }

                    // Bag title
                    Text(bag.title)
                        .font(DesignSystem.ScaledTypography.subheadline(isRegular: isRegular))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)

                    // Tags
                    HStack(spacing: isRegular ? 8 : 6) {
                        TagPill(text: bag.foodType, style: .default)
                        Text("•")
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                        Text(String(format: "%.1f km", restaurant.distanceKm))
                            .font(DesignSystem.ScaledTypography.caption(isRegular: isRegular))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }

                    // Price and pickup time
                    HStack {
                        // Price
                        HStack(alignment: .firstTextBaseline, spacing: isRegular ? 8 : 6) {
                            Text("R\(Int(bag.priceNow))")
                                .font(DesignSystem.ScaledTypography.price(isRegular: isRegular))
                                .foregroundStyle(DesignSystem.Colors.accent)

                            Text("R\(Int(bag.priceWas))")
                                .font(DesignSystem.ScaledTypography.caption(isRegular: isRegular))
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                .strikethrough()
                        }

                        Spacer()

                        // Pickup time
                        HStack(spacing: isRegular ? 6 : 4) {
                            Image(systemName: "clock")
                                .font(.system(size: isRegular ? 14 : 12))
                            Text(bag.pickupWindowFormatted)
                                .font(DesignSystem.ScaledTypography.caption(isRegular: isRegular))
                        }
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
                .padding(contentPadding)
                .background {
                    UnevenRoundedRectangle(
                        bottomLeadingRadius: cornerRadius,
                        bottomTrailingRadius: cornerRadius
                    )
                    .fill(DesignSystem.Colors.glassFill)
                }
            }
            .background {
                GlassBackground(cornerRadius: cornerRadius)
            }
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.15)) {
                        isPressed = false
                    }
                }
        )
        .accessibilityLabel("\(restaurant.name), \(bag.title), R\(Int(bag.priceNow))")
    }
}

// MARK: - Compact Bag Card (for carousel)
struct CompactBagCard: View {
    let bag: Bag
    let restaurant: Restaurant
    var isRegularWidth: Bool = false
    var onTap: () -> Void

    @State private var isPressed = false

    // iPad gets larger cards - uses Layout dimensions
    private var cardWidth: CGFloat { DesignSystem.Layout.carouselCardWidth(isRegular: isRegularWidth) }
    private var imageHeight: CGFloat { DesignSystem.Layout.carouselImageHeight(isRegular: isRegularWidth) }
    private var iconSize: CGFloat { isRegularWidth ? 40 : 30 }
    private var cornerRadius: CGFloat { DesignSystem.Layout.cardCornerRadius(isRegular: isRegularWidth) }
    private var contentPadding: CGFloat { DesignSystem.Layout.cardPadding(isRegular: isRegularWidth) }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Image
                ZStack {
                    Rectangle()
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

                    Image(systemName: restaurant.foodIcon)
                        .font(.system(size: iconSize))
                        .foregroundStyle(.white.opacity(0.3))

                    // Selling Fast badge
                    if bag.quantityLeft <= 3 {
                        VStack {
                            HStack {
                                Spacer()
                                TagPill(text: "Selling Fast!", style: .warning, icon: "flame.fill")
                                    .padding(8)
                            }
                            Spacer()
                        }
                    }
                }
                .frame(height: imageHeight)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: cornerRadius,
                        topTrailingRadius: cornerRadius
                    )
                )

                // Content
                VStack(alignment: .leading, spacing: isRegularWidth ? 6 : 4) {
                    Text(restaurant.name)
                        .font(DesignSystem.ScaledTypography.subheadline(isRegular: isRegularWidth))
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("R\(Int(bag.priceNow))")
                            .font(DesignSystem.ScaledTypography.headline(isRegular: isRegularWidth))
                            .foregroundStyle(DesignSystem.Colors.accent)

                        Text("R\(Int(bag.priceWas))")
                            .font(DesignSystem.ScaledTypography.caption(isRegular: isRegularWidth))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .strikethrough()
                    }
                }
                .padding(contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    UnevenRoundedRectangle(
                        bottomLeadingRadius: cornerRadius,
                        bottomTrailingRadius: cornerRadius
                    )
                    .fill(DesignSystem.Colors.glassFill)
                }
            }
            .frame(width: cardWidth)
            .background {
                GlassBackground(cornerRadius: cornerRadius)
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.15)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Glass Segmented Control
struct GlassSegmentedControl<T: Hashable & CaseIterable>: View where T: RawRepresentable, T.RawValue == String {
    @Binding var selection: T
    @Namespace private var segmentAnimation

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(T.allCases), id: \.self) { segment in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selection = segment
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text(segment.rawValue)
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(selection == segment ? .black : DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .frame(maxWidth: .infinity)
                        .background {
                            if selection == segment {
                                Capsule()
                                    .fill(DesignSystem.Colors.accent)
                                    .matchedGeometryEffect(id: "segment", in: segmentAnimation)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background {
            GlassBackground(cornerRadius: DesignSystem.CornerRadius.pill)
        }
    }
}

// MARK: - Order Status Chip
struct OrderStatusChip: View {
    let status: OrderStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)

            Text(status.rawValue)
                .font(DesignSystem.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(status.color)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background {
            Capsule()
                .fill(status.color.opacity(0.15))
                .overlay {
                    Capsule()
                        .strokeBorder(status.color.opacity(0.3), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Countdown Timer View
struct CountdownTimerView: View {
    let targetDate: Date
    @State private var timeRemaining: TimeInterval = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 4) {
            Text("Pickup starts in")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Text(formatTime(timeRemaining))
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.accent)
        }
        .onAppear {
            timeRemaining = max(0, targetDate.timeIntervalSince(Date()))
        }
        .onReceive(timer) { _ in
            timeRemaining = max(0, targetDate.timeIntervalSince(Date()))
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Preference Chip
struct PreferenceChip: View {
    let title: String
    let icon: String
    @Binding var isSelected: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isSelected.toggle()
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(isSelected ? .black : DesignSystem.Colors.textPrimary)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background {
                Capsule()
                    .fill(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.glassFill)
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                isSelected ? .clear : DesignSystem.Colors.glassBorder,
                                lineWidth: 1
                            )
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var showChevron: Bool = true
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                }

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
            .padding(DesignSystem.Spacing.md)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

#Preview("Components") {
    ZStack {
        AppBackgroundGradient()

        ScrollView {
            VStack(spacing: 20) {
                PrimaryButton("Reserve Your Bag", icon: "bag.fill") {}

                SecondaryButton("Cancel Order", icon: "xmark", style: .destructive) {}

                TagPill(text: "Selling Fast!", style: .warning, icon: "flame.fill")

                RatingRow(rating: 4.8, count: 234)

                QRCodeView(qrString: "KULA-ORDER-12345", size: 150)
            }
            .padding()
        }
    }
}
