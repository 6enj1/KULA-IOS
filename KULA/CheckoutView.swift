//
//  CheckoutView.swift
//  KULA
//
//  Checkout and Payment Screen
//

import SwiftUI

struct CheckoutView: View {
    let bag: Bag
    let restaurant: Restaurant
    let quantity: Int

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep: CheckoutStep = .summary
    @State private var selectedPaymentMethod: PaymentMethod = .card
    @State private var saveCard: Bool = true
    @State private var isProcessing: Bool = false
    @State private var createdOrder: Order?
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    enum CheckoutStep {
        case summary
        case payment
        case confirmation
    }

    enum PaymentMethod: String, CaseIterable {
        case card = "Pay with Card"  // Yoco checkout supports Apple Pay, cards, etc.

        var icon: String {
            switch self {
            case .card: return "creditcard.fill"
            }
        }
    }

    private var platformFee: Double { 2.50 }
    private var subtotal: Double { bag.priceNow * Double(quantity) }
    private var total: Double { subtotal + platformFee }

    var body: some View {
        ZStack {
            AppBackgroundGradient()

            VStack(spacing: 0) {
                // Header
                header

                // Progress indicator
                progressIndicator
                    .padding(.vertical, DesignSystem.Spacing.lg)

                // Content
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        switch currentStep {
                        case .summary:
                            summaryStep
                        case .payment:
                            paymentStep
                        case .confirmation:
                            confirmationStep
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .padding(.bottom, 120)
                }

                // Bottom CTA
                if currentStep != .confirmation {
                    bottomCTA
                }
            }
        }
        .alert("Payment Failed", isPresented: $showError) {
            Button("Try Again", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Button {
                if currentStep == .summary {
                    dismiss()
                } else if currentStep == .payment {
                    withAnimation {
                        currentStep = .summary
                    }
                }
            } label: {
                Image(systemName: currentStep == .summary ? "xmark" : "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(DesignSystem.Colors.glassFill)
                    }
            }
            .opacity(currentStep == .confirmation ? 0 : 1)

            Spacer()

            Text(currentStep == .confirmation ? "Order Confirmed" : "Checkout")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Spacer()

            // Placeholder for symmetry
            Circle()
                .fill(.clear)
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.top, DesignSystem.Spacing.md)
    }

    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(Array([CheckoutStep.summary, .payment, .confirmation].enumerated()), id: \.offset) { index, step in
                Capsule()
                    .fill(stepIndex(currentStep) >= index ? DesignSystem.Colors.accent : DesignSystem.Colors.glassFill)
                    .frame(height: 4)
                    .animation(.spring(response: 0.4), value: currentStep)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    private func stepIndex(_ step: CheckoutStep) -> Int {
        switch step {
        case .summary: return 0
        case .payment: return 1
        case .confirmation: return 2
        }
    }

    // MARK: - Summary Step
    private var summaryStep: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Order summary card
            GlassCard {
                VStack(spacing: DesignSystem.Spacing.md) {
                    HStack {
                        Text("Order Summary")
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Spacer()
                    }

                    Divider()
                        .background(DesignSystem.Colors.glassBorder)

                    // Restaurant & Bag info
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                        // Image placeholder
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

                            Image(systemName: restaurant.foodIcon)
                                .font(.system(size: 24))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .frame(width: 60, height: 60)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(restaurant.name)
                                .font(DesignSystem.Typography.headline)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)

                            Text(bag.title)
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)

                            Text("Qty: \(quantity)")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                        }

                        Spacer()
                    }

                    Divider()
                        .background(DesignSystem.Colors.glassBorder)

                    // Pickup info
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(DesignSystem.Colors.accent)

                        Text("Pickup: \(bag.pickupWindowFormatted)")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)

                        Spacer()
                    }

                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(DesignSystem.Colors.accent)

                        Text(restaurant.address)
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)

                        Spacer()
                    }
                }
            }

            // Price breakdown
            GlassCard {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    priceRow("Subtotal (\(quantity) bag\(quantity > 1 ? "s" : ""))", value: subtotal)
                    priceRow("Platform fee", value: platformFee)

                    Divider()
                        .background(DesignSystem.Colors.glassBorder)

                    HStack {
                        Text("Total")
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Spacer()
                        Text("R\(String(format: "%.2f", total))")
                            .font(DesignSystem.Typography.price)
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }

                    // Savings callout
                    HStack(spacing: 6) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 12))
                        Text("You're saving R\(Int(bag.priceWas * Double(quantity) - subtotal)) on this order!")
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .padding(.top, DesignSystem.Spacing.xs)
                }
            }
        }
    }

    // MARK: - Payment Step
    private var paymentStep: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Payment methods
            GlassCard {
                VStack(spacing: DesignSystem.Spacing.md) {
                    HStack {
                        Text("Payment Method")
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Spacer()
                    }

                    ForEach(PaymentMethod.allCases, id: \.self) { method in
                        paymentMethodRow(method)
                    }
                }
            }

            // Save card toggle (for card option)
            if selectedPaymentMethod == .card {
                GlassCard {
                    Toggle(isOn: $saveCard) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(DesignSystem.Colors.accent)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Save card for future orders")
                                    .font(DesignSystem.Typography.subheadline)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                                Text("Securely stored with 256-bit encryption")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                            }
                        }
                    }
                    .tint(DesignSystem.Colors.accent)
                }
            }

            // Security notice
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 14))
                Text("Your payment is secured with industry-standard encryption")
                    .font(DesignSystem.Typography.caption)
            }
            .foregroundStyle(DesignSystem.Colors.textTertiary)

            // Order total reminder
            GlassCard {
                HStack {
                    Text("Order Total")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Spacer()
                    Text("R\(String(format: "%.2f", total))")
                        .font(DesignSystem.Typography.price)
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
            }
        }
    }

    // MARK: - Confirmation Step
    private var confirmationStep: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Success animation
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.accent.opacity(0.15))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(DesignSystem.Colors.accent.opacity(0.1))
                    .frame(width: 160, height: 160)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(DesignSystem.Colors.accent)
            }
            .padding(.top, DesignSystem.Spacing.xl)

            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("You're all set!")
                    .font(DesignSystem.Typography.title1)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text("Show this QR code when you pick up your bag")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // QR Code
            if let order = createdOrder {
                QRCodeView(qrString: order.qrString, size: 200)
            }

            // Order details card
            GlassCard {
                VStack(spacing: DesignSystem.Spacing.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pickup at")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                            Text(restaurant.name)
                                .font(DesignSystem.Typography.headline)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Window")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                            Text(bag.pickupWindowFormatted)
                                .font(DesignSystem.Typography.headline)
                                .foregroundStyle(DesignSystem.Colors.accent)
                        }
                    }

                    Divider()
                        .background(DesignSystem.Colors.glassBorder)

                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(DesignSystem.Colors.accent)
                        Text(restaurant.address)
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        Spacer()
                    }
                }
            }

            // CTA buttons
            VStack(spacing: DesignSystem.Spacing.sm) {
                PrimaryButton("View My Orders", icon: "bag.fill") {
                    dismiss()
                }

                SecondaryButton("Back to Home", icon: "house.fill") {
                    dismiss()
                }
            }
            .padding(.top, DesignSystem.Spacing.md)
        }
    }

    // MARK: - Bottom CTA
    private var bottomCTA: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            PrimaryButton(
                currentStep == .summary ? "Continue to Payment" : "Pay R\(String(format: "%.2f", total))",
                icon: currentStep == .payment ? "lock.fill" : "arrow.right",
                isLoading: isProcessing
            ) {
                handleCTATap()
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background {
            GlassBackground(intensity: .heavy)
                .ignoresSafeArea()
        }
    }

    // MARK: - Helper Views
    private func priceRow(_ label: String, value: Double) -> some View {
        HStack {
            Text(label)
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            Spacer()
            Text("R\(String(format: "%.2f", value))")
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        }
    }

    private func paymentMethodRow(_ method: PaymentMethod) -> some View {
        Button {
            selectedPaymentMethod = method
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: method.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(method == selectedPaymentMethod ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
                    .frame(width: 24)

                Text(method.rawValue)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Spacer()

                ZStack {
                    Circle()
                        .strokeBorder(method == selectedPaymentMethod ? DesignSystem.Colors.accent : DesignSystem.Colors.glassBorder, lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if method == selectedPaymentMethod {
                        Circle()
                            .fill(DesignSystem.Colors.accent)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                    .fill(method == selectedPaymentMethod ? DesignSystem.Colors.accent.opacity(0.1) : .clear)
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                            .strokeBorder(method == selectedPaymentMethod ? DesignSystem.Colors.accent.opacity(0.3) : DesignSystem.Colors.glassBorder, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions
    private func handleCTATap() {
        switch currentStep {
        case .summary:
            withAnimation {
                currentStep = .payment
            }
        case .payment:
            processPayment()
        case .confirmation:
            dismiss()
        }
    }

    private func processPayment() {
        isProcessing = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        Task {
            // Create order and get payment URL (Yoco checkout - supports Apple Pay, cards, etc.)
            let (order, paymentUrl) = await appState.createOrder(bag: bag, quantity: quantity)

            if let order = order {
                createdOrder = order

                // Open Yoco checkout page
                if let paymentUrl = paymentUrl {
                    appState.openPayment(url: paymentUrl)
                }

                isProcessing = false

                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    currentStep = .confirmation
                }

                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                isProcessing = false
                errorMessage = appState.error ?? "Unable to process your order. Please try again."
                showError = true
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}

#Preview {
    CheckoutView(
        bag: PreviewData.sampleBag,
        restaurant: PreviewData.sampleRestaurant,
        quantity: 1
    )
    .environmentObject(AppState())
}
