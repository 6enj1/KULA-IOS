//
//  ProfileView.swift
//  KULA
//
//  User Profile Screen
//

import SwiftUI
import CoreLocation

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject private var locationManager = LocationManager.shared
    @State private var showEditPreferences = false
    @State private var showPaymentMethods = false
    @State private var showOrderHistory = false
    @State private var showLogoutConfirmation = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("locationEnabled") private var locationEnabled = true

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    /// Display string for user's location
    private var locationDisplayString: String {
        // Check if location permission is denied/restricted first
        if locationManager.isDeniedOrRestricted {
            return "Location access denied"
        }

        // First try the user's saved location
        if let loc = appState.currentUser?.location {
            return String(format: "%.4f, %.4f", loc.latitude, loc.longitude)
        }

        // Fall back to current location from LocationManager (only if authorized)
        if locationManager.isAuthorized {
            if let address = locationManager.currentAddress, !address.isEmpty {
                return address
            }
            if let loc = locationManager.currentLocation {
                return String(format: "%.4f, %.4f", loc.coordinate.latitude, loc.coordinate.longitude)
            }
        }

        return "Location not set"
    }

    var body: some View {
        ZStack {
            AppBackgroundGradient()

            ScrollView {
                VStack(spacing: isRegularWidth ? DesignSystem.Spacing.xl : DesignSystem.Spacing.lg) {
                    // Profile Header
                    profileHeader
                        .padding(.top, isRegularWidth ? DesignSystem.Spacing.lg : 0)

                    // Stats/Loyalty Section
                    loyaltySection

                    // Preferences Section
                    preferencesSection

                    // Account Section
                    accountSection

                    // Settings Section
                    settingsSection

                    // Support Section
                    supportSection

                    // Sign Out
                    signOutButton

                    // App version
                    Text("KULA v1.0.0")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .padding(.top, DesignSystem.Spacing.md)
                }
                .adaptivePadding()
                                .padding(.bottom, isRegularWidth ? 140 : 120)
            }
        }
        .sheet(isPresented: $showEditPreferences) {
            EditPreferencesSheet()
                .presentationDetents(DesignSystem.Layout.sheetDetents(isRegular: isRegularWidth))
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPaymentMethods) {
            PaymentMethodsSheet()
                .presentationDetents(DesignSystem.Layout.sheetDetents(isRegular: isRegularWidth))
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showOrderHistory) {
            OrderHistorySheet()
                .presentationDetents(DesignSystem.Layout.sheetDetents(isRegular: isRegularWidth))
                .presentationDragIndicator(.visible)
        }
        .alert("Sign Out", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task {
                    await appState.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .onAppear {
            // Sync notification setting from user data
            if let user = appState.currentUser {
                notificationsEnabled = user.notificationsEnabled
            }

            // Request fresh location if authorized but no location yet
            if (locationManager.authorizationStatus == .authorizedWhenInUse ||
                locationManager.authorizationStatus == .authorizedAlways) &&
                locationManager.currentLocation == nil {
                locationManager.requestLocation()
            }
        }
    }

    // MARK: - Profile Header
    private var profileHeader: some View {
        GlassCard {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.accent,
                                    DesignSystem.Colors.primaryGreen
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)

                    Text(initials)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.currentUser?.name ?? "User")
                        .font(DesignSystem.Typography.title3)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Text(appState.currentUser?.email ?? "email@example.com")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                        Text(locationDisplayString)
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                }

                Spacer()

                // Edit button
                Button {
                    // Edit profile
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .frame(width: 36, height: 36)
                        .background {
                            Circle()
                                .fill(DesignSystem.Colors.accent.opacity(0.15))
                        }
                }
            }
        }
    }

    private var initials: String {
        let name = appState.currentUser?.name ?? "User"
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }

    // MARK: - Loyalty Section
    private var loyaltySection: some View {
        GlassCard {
            VStack(spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(DesignSystem.Colors.accent)

                    Text("KULA Points")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Spacer()

                    Text("\(appState.currentUser?.loyaltyPoints ?? 0)")
                        .font(DesignSystem.Typography.title2)
                        .foregroundStyle(DesignSystem.Colors.accent)
                }

                // Progress to next reward
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    HStack {
                        Text("50 points to your next reward")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        Spacer()
                        Text("\(appState.currentUser?.loyaltyPoints ?? 0)/200")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DesignSystem.Colors.glassFill)
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(DesignSystem.Colors.accent)
                                .frame(width: geometry.size.width * CGFloat(appState.currentUser?.loyaltyPoints ?? 0) / 200, height: 8)
                        }
                    }
                    .frame(height: 8)
                }

                // Stats row
                HStack(spacing: 0) {
                    statItem(value: "\(appState.orders.filter { $0.status == .collected }.count)", label: "Bags Saved")
                    Divider()
                        .frame(height: 40)
                        .background(DesignSystem.Colors.glassBorder)
                    statItem(value: "R\(totalSaved)", label: "Money Saved")
                    Divider()
                        .frame(height: 40)
                        .background(DesignSystem.Colors.glassBorder)
                    statItem(value: "\(co2Saved)kg", label: "CO₂ Saved")
                }
            }
        }
    }

    private var totalSaved: Int {
        // Mock calculation
        appState.orders.filter { $0.status == .collected }.count * 85
    }

    private var co2Saved: Double {
        // Mock calculation
        Double(appState.orders.filter { $0.status == .collected }.count) * 2.5
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Text(label)
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Preferences Section
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            sectionHeader("Preferences")

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    SettingsRow(
                        icon: "fork.knife",
                        title: "Food Preferences",
                        subtitle: currentPreferencesText
                    ) {
                        showEditPreferences = true
                    }
                }
            }
        }
    }

    private var currentPreferencesText: String {
        let prefs = appState.currentUser?.preferences ?? []
        if prefs.isEmpty {
            return "Not set"
        }
        return prefs.prefix(3).joined(separator: ", ") + (prefs.count > 3 ? "..." : "")
    }

    // MARK: - Account Section
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            sectionHeader("Account")

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    SettingsRow(
                        icon: "creditcard.fill",
                        title: "Payment",
                        subtitle: "Secure checkout via Yoco"
                    ) {
                        showPaymentMethods = true
                    }

                    Divider()
                        .background(DesignSystem.Colors.glassBorder)
                        .padding(.leading, 56)

                    SettingsRow(
                        icon: "clock.arrow.circlepath",
                        title: "Order History",
                        subtitle: "\(appState.orders.count) orders"
                    ) {
                        showOrderHistory = true
                    }
                }
            }
        }
    }

    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            sectionHeader("Settings")

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    // Notifications toggle
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(DesignSystem.Colors.accent)
                            .frame(width: 28)

                        Text("Push Notifications")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        Spacer()

                        Toggle("", isOn: $notificationsEnabled)
                            .tint(DesignSystem.Colors.accent)
                            .onChange(of: notificationsEnabled) { _, newValue in
                                Task {
                                    await appState.updateNotificationSetting(enabled: newValue)
                                }
                            }
                    }
                    .padding(DesignSystem.Spacing.md)

                    Divider()
                        .background(DesignSystem.Colors.glassBorder)
                        .padding(.leading, 56)

                    // Location toggle
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(DesignSystem.Colors.accent)
                            .frame(width: 28)

                        Text("Location Services")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        Spacer()

                        Toggle("", isOn: $locationEnabled)
                            .tint(DesignSystem.Colors.accent)
                    }
                    .padding(DesignSystem.Spacing.md)
                }
            }
        }
    }

    // MARK: - Support Section
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            sectionHeader("Support")

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    SettingsRow(
                        icon: "questionmark.circle.fill",
                        title: "Help Center"
                    ) {
                        // Open help center
                    }

                    Divider()
                        .background(DesignSystem.Colors.glassBorder)
                        .padding(.leading, 56)

                    SettingsRow(
                        icon: "envelope.fill",
                        title: "Contact Us"
                    ) {
                        // Open contact
                    }

                    Divider()
                        .background(DesignSystem.Colors.glassBorder)
                        .padding(.leading, 56)

                    SettingsRow(
                        icon: "doc.text.fill",
                        title: "Terms & Privacy"
                    ) {
                        // Open terms
                    }
                }
            }
        }
    }

    // MARK: - Sign Out Button
    private var signOutButton: some View {
        SecondaryButton("Sign Out", icon: "rectangle.portrait.and.arrow.right", style: .destructive) {
            showLogoutConfirmation = true
        }
        .padding(.top, DesignSystem.Spacing.md)
    }

    // MARK: - Helpers
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(DesignSystem.Typography.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(DesignSystem.Colors.textSecondary)
            .padding(.leading, DesignSystem.Spacing.xs)
    }
}

// MARK: - Edit Preferences Sheet
struct EditPreferencesSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPreferences: Set<String> = []

    var body: some View {
        ZStack {
            AppBackgroundGradient()

            VStack(spacing: DesignSystem.Spacing.xl) {
                // Header
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("Food Preferences")
                        .font(DesignSystem.Typography.title2)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Text("Select your favorite cuisines")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .padding(.top, DesignSystem.Spacing.xl)

                // Chips
                FlowLayout(spacing: DesignSystem.Spacing.xs) {
                    ForEach(appState.categories) { category in
                        PreferenceChipView(
                            category: category,
                            isSelected: selectedPreferences.contains(category.name)
                        ) {
                            if selectedPreferences.contains(category.name) {
                                selectedPreferences.remove(category.name)
                            } else {
                                selectedPreferences.insert(category.name)
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)

                Spacer()

                // Save button
                PrimaryButton("Save Preferences", icon: "checkmark") {
                    Task {
                        await appState.updatePreferences(Array(selectedPreferences))
                        dismiss()
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
        }
        .onAppear {
            selectedPreferences = Set(appState.currentUser?.preferences ?? [])
        }
    }
}

// MARK: - Payment Methods Sheet
struct PaymentMethodsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppBackgroundGradient()

            VStack(spacing: DesignSystem.Spacing.xl) {
                // Header
                Text("Payment")
                    .font(DesignSystem.Typography.title2)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .padding(.top, DesignSystem.Spacing.xl)

                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Info card
                    GlassCard {
                        VStack(spacing: DesignSystem.Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(DesignSystem.Colors.accent.opacity(0.15))
                                    .frame(width: 60, height: 60)

                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(DesignSystem.Colors.accent)
                            }

                            Text("Secure Checkout")
                                .font(DesignSystem.Typography.headline)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)

                            Text("Payments are processed securely through Yoco at checkout. Your card details are never stored on our servers.")
                                .font(DesignSystem.Typography.body)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    // Accepted payment methods
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Accepted Payment Methods")
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)

                        GlassCard {
                            VStack(spacing: DesignSystem.Spacing.md) {
                                paymentMethodRow(icon: "creditcard.fill", title: "Credit & Debit Cards", subtitle: "Visa, Mastercard, Amex")
                                Divider().background(DesignSystem.Colors.glassBorder)
                                paymentMethodRow(icon: "apple.logo", title: "Apple Pay", subtitle: "Quick & secure")
                                Divider().background(DesignSystem.Colors.glassBorder)
                                paymentMethodRow(icon: "banknote.fill", title: "SnapScan", subtitle: "South African mobile payments")
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)

                Spacer()

                // Done button
                PrimaryButton("Done", icon: "checkmark") {
                    dismiss()
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
        }
    }

    private func paymentMethodRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text(subtitle)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(DesignSystem.Colors.success)
        }
    }
}

// MARK: - Order History Sheet
struct OrderHistorySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            OrdersView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                        }
                    }
                }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
    .environmentObject(AppState())
}
