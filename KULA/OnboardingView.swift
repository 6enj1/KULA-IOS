//
//  OnboardingView.swift
//  KULA
//
//  Onboarding and Authentication Screens
//

import SwiftUI
import CoreLocation

// MARK: - Onboarding View
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var locationManager = LocationManager.shared
    @State private var currentStep: OnboardingStep = .welcome
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var selectedPreferences: Set<String> = []
    @State private var showEmailAuth = false
    @State private var waitingForLocationPermission = false

    enum OnboardingStep {
        case welcome
        case location
        case preferences
    }

    var body: some View {
        ZStack {
            // Background
            AppBackgroundGradient()

            // Hero image overlay (gradient fade)
            VStack {
                ZStack {
                    // Placeholder hero with gradient overlay
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.primaryGreen.opacity(0.4),
                            DesignSystem.Colors.warmAmber.opacity(0.2),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 350)

                    // Food imagery placeholder
                    VStack {
                        Image(systemName: "leaf.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(DesignSystem.Colors.accent)
                            .shadow(color: DesignSystem.Colors.accent.opacity(0.5), radius: 20)

                        Text("KULA")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Save food. Save money.")
                            .font(DesignSystem.Typography.title3)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.top, 60)
                }

                Spacer()
            }
            .ignoresSafeArea()

            // Content
            VStack {
                Spacer()

                // Step Content
                Group {
                    switch currentStep {
                    case .welcome:
                        welcomeContent
                    case .location:
                        locationContent
                    case .preferences:
                        preferencesContent
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .sheet(isPresented: $showEmailAuth) {
            EmailAuthSheet(email: $email, password: $password) {
                handlePostAuthNavigation()
            }
            .environmentObject(appState)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Post-Auth Navigation
    /// Determines the next step based on whether user already has location/preferences set
    private func handlePostAuthNavigation() {
        guard let user = appState.currentUser else {
            #if DEBUG
            print("[Onboarding] No user loaded, checking location status")
            #endif
            // No user loaded - check if we need location permission
            if locationManager.isAuthorized {
                // Location already authorized, skip to preferences
                withAnimation {
                    currentStep = .preferences
                }
            } else {
                // Need location permission (or denied - show location step)
                withAnimation {
                    currentStep = .location
                }
            }
            return
        }

        #if DEBUG
        print("[Onboarding] User loaded - location: \(user.location != nil), preferences: \(user.preferences)")
        #endif

        // Check if user has location set OR location is already authorized at OS level
        let hasLocation = user.location != nil || locationManager.isAuthorized

        // Check if user has preferences set (non-empty array from backend)
        let hasPreferences = !user.preferences.isEmpty

        if hasLocation && hasPreferences {
            // User already completed onboarding - go directly to main app
            #if DEBUG
            print("[Onboarding] User has location + preferences, going to main app")
            #endif
            appState.isAuthenticated = true
        } else if hasPreferences && !hasLocation {
            // Has preferences but no location - show location step
            #if DEBUG
            print("[Onboarding] User has preferences but no location")
            #endif
            withAnimation {
                currentStep = .location
            }
        } else if hasLocation && !hasPreferences {
            // Has location (or authorized) but no preferences - show preferences
            #if DEBUG
            print("[Onboarding] User has location but no preferences")
            #endif
            withAnimation {
                currentStep = .preferences
            }
        } else {
            // Neither location nor preferences - start with location
            #if DEBUG
            print("[Onboarding] User has neither location nor preferences")
            #endif
            withAnimation {
                currentStep = .location
            }
        }
    }

    // MARK: - Welcome Content
    private var welcomeContent: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            GlassCard(padding: DesignSystem.Spacing.xl) {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text("Join the movement")
                            .font(DesignSystem.Typography.title2)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        Text("Rescue delicious food and help reduce waste")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: DesignSystem.Spacing.sm) {
                        SocialAuthButton(provider: .apple) {
                            Task {
                                await appState.signInWithApple()
                                // Only proceed if sign-in was successful
                                if appState.currentUser != nil && appState.error == nil {
                                    handlePostAuthNavigation()
                                }
                            }
                        }

                        SocialAuthButton(provider: .google) {
                            Task {
                                await appState.signInWithGoogle()
                                // Only proceed if sign-in was successful
                                if appState.currentUser != nil && appState.error == nil {
                                    handlePostAuthNavigation()
                                }
                            }
                        }

                        SocialAuthButton(provider: .email) {
                            showEmailAuth = true
                        }
                    }

                    // Terms
                    Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding(.bottom, DesignSystem.Spacing.xxxl)
    }

    // MARK: - Location Content
    private var locationContent: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            GlassCard(padding: DesignSystem.Spacing.xl) {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(locationManager.isDeniedOrRestricted
                                  ? DesignSystem.Colors.error.opacity(0.15)
                                  : DesignSystem.Colors.accent.opacity(0.15))
                            .frame(width: 80, height: 80)

                        Image(systemName: locationManager.isDeniedOrRestricted
                              ? "location.slash.fill"
                              : "location.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(locationManager.isDeniedOrRestricted
                                             ? DesignSystem.Colors.error
                                             : DesignSystem.Colors.accent)
                    }

                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text(locationManager.isDeniedOrRestricted
                             ? "Location Access Denied"
                             : "Find food near you")
                            .font(DesignSystem.Typography.title2)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        Text(locationManager.isDeniedOrRestricted
                             ? "To see Surprise Bags near you, please enable location access in Settings"
                             : "We'll show you the best Surprise Bags available in your area")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: DesignSystem.Spacing.sm) {
                        // Different button behavior based on authorization status
                        if locationManager.isDeniedOrRestricted {
                            // Permission denied - open Settings
                            PrimaryButton("Open Settings", icon: "gear") {
                                locationManager.openAppSettings()
                            }
                        } else if locationManager.canRequestPermission {
                            // Can request permission - request it
                            PrimaryButton("Enable Location", icon: "location.fill") {
                                waitingForLocationPermission = true
                                locationManager.requestPermission()
                            }
                        } else if locationManager.isAuthorized {
                            // Already authorized - check if user already completed onboarding
                            PrimaryButton("Continue", icon: "arrow.right") {
                                handlePostAuthNavigation()
                            }
                        }

                        Button {
                            // Skip location - but still check if user has preferences
                            handlePostAuthNavigation()
                        } label: {
                            Text(locationManager.isDeniedOrRestricted ? "Continue without location" : "Not now")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding(.bottom, DesignSystem.Spacing.xxxl)
        // Watch for authorization changes when user returns from Settings
        .onChange(of: locationManager.authorizationStatus) { oldValue, newValue in
            #if DEBUG
            print("[Onboarding] Location auth changed: \(oldValue.rawValue) -> \(newValue.rawValue)")
            #endif

            // If user just authorized (from Settings or prompt), re-evaluate next step
            if locationManager.isAuthorized {
                waitingForLocationPermission = false
                // Use handlePostAuthNavigation to check if user already has preferences
                handlePostAuthNavigation()
            }
        }
        // Re-check authorization when returning from Settings
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active && currentStep == .location {
                locationManager.refreshAuthorizationStatus()
            }
        }
    }

    // MARK: - Preferences Content
    private var preferencesContent: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            GlassCard(padding: DesignSystem.Spacing.xl) {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text("What do you love?")
                            .font(DesignSystem.Typography.title2)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        Text("Select your favorite cuisines for personalized recommendations")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // Preference chips
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

                    VStack(spacing: DesignSystem.Spacing.sm) {
                        PrimaryButton("Let's go!", icon: "arrow.right") {
                            Task {
                                await appState.updatePreferences(Array(selectedPreferences))
                                appState.isAuthenticated = true
                            }
                        }

                        Button {
                            appState.isAuthenticated = true
                        } label: {
                            Text("Skip for now")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding(.bottom, DesignSystem.Spacing.xxxl)
    }
}

// MARK: - Preference Chip View
struct PreferenceChipView: View {
    let category: FoodCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 14))
                Text(category.name)
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
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Email Auth Sheet
struct EmailAuthSheet: View {
    @EnvironmentObject var appState: AppState
    @Binding var email: String
    @Binding var password: String
    var onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var isRegisterMode = false
    @State private var name: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage: String?

    enum Field {
        case name, email, password, confirmPassword
    }

    private var isFormValid: Bool {
        if isRegisterMode {
            return !email.isEmpty && !password.isEmpty && !name.isEmpty && password == confirmPassword && password.count >= 12
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }

    private var passwordError: String? {
        guard isRegisterMode && !password.isEmpty else { return nil }
        if password.count < 12 {
            return "Password must be at least 12 characters"
        }
        if !password.contains(where: { $0.isUppercase }) {
            return "Password must contain an uppercase letter"
        }
        if !password.contains(where: { $0.isLowercase }) {
            return "Password must contain a lowercase letter"
        }
        if !password.contains(where: { $0.isNumber }) {
            return "Password must contain a number"
        }
        let specialChars = CharacterSet(charactersIn: "!@#$%^&*(),.?\":{}|<>")
        if password.unicodeScalars.filter({ specialChars.contains($0) }).isEmpty {
            return "Password must contain a special character"
        }
        return nil
    }

    var body: some View {
        ZStack {
            AppBackgroundGradient()

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Header
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text(isRegisterMode ? "Create Account" : "Sign in with Email")
                            .font(DesignSystem.Typography.title2)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        Text(isRegisterMode ? "Enter your details to get started" : "Enter your details to continue")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.top, DesignSystem.Spacing.xl)

                    // Fields
                    VStack(spacing: DesignSystem.Spacing.md) {
                        // Name field (register only)
                        if isRegisterMode {
                            GlassCard(padding: 0, cornerRadius: DesignSystem.CornerRadius.medium) {
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                                        .frame(width: 24)

                                    TextField("Full name", text: $name)
                                        .font(DesignSystem.Typography.body)
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                        .textContentType(.name)
                                        .focused($focusedField, equals: .name)
                                }
                                .padding(DesignSystem.Spacing.md)
                            }
                        }

                        // Email field
                        GlassCard(padding: 0, cornerRadius: DesignSystem.CornerRadius.medium) {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    .frame(width: 24)

                                TextField("Email address", text: $email)
                                    .font(DesignSystem.Typography.body)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress)
                                    .autocapitalization(.none)
                                    .focused($focusedField, equals: .email)
                            }
                            .padding(DesignSystem.Spacing.md)
                        }

                        // Password field
                        GlassCard(padding: 0, cornerRadius: DesignSystem.CornerRadius.medium) {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    .frame(width: 24)

                                SecureField("Password", text: $password)
                                    .font(DesignSystem.Typography.body)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                    .textContentType(isRegisterMode ? .newPassword : .password)
                                    .focused($focusedField, equals: .password)
                            }
                            .padding(DesignSystem.Spacing.md)
                        }

                        // Password error
                        if let error = passwordError {
                            Text(error)
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Confirm password field (register only)
                        if isRegisterMode {
                            GlassCard(padding: 0, cornerRadius: DesignSystem.CornerRadius.medium) {
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                                        .frame(width: 24)

                                    SecureField("Confirm password", text: $confirmPassword)
                                        .font(DesignSystem.Typography.body)
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                        .textContentType(.newPassword)
                                        .focused($focusedField, equals: .confirmPassword)
                                }
                                .padding(DesignSystem.Spacing.md)
                            }

                            if !confirmPassword.isEmpty && password != confirmPassword {
                                Text("Passwords do not match")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.error)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundStyle(DesignSystem.Colors.error)
                            .multilineTextAlignment(.center)
                    }

                    Spacer(minLength: DesignSystem.Spacing.xl)

                    // Continue button
                    PrimaryButton(isRegisterMode ? "Create Account" : "Sign In", icon: "arrow.right") {
                        Task {
                            errorMessage = nil
                            if isRegisterMode {
                                await appState.register(email: email, password: password, name: name)
                            } else {
                                await appState.signIn(email: email, password: password)
                            }

                            // Only proceed if sign-in was successful (user set and no error)
                            if appState.currentUser != nil && appState.error == nil {
                                dismiss()
                                onComplete()
                            } else if let error = appState.error {
                                errorMessage = error
                                appState.error = nil
                            } else {
                                errorMessage = "Sign in failed. Please try again."
                            }
                        }
                    }
                    .disabled(!isFormValid || passwordError != nil)

                    // Toggle mode
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isRegisterMode.toggle()
                            errorMessage = nil
                        }
                    } label: {
                        Text(isRegisterMode ? "Already have an account? **Sign In**" : "Don't have an account? **Register**")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
        }
        .onAppear {
            focusedField = isRegisterMode ? .name : .email
        }
    }
}

// MARK: - Flow Layout (for chips)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var maxHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += maxHeight + spacing
                    maxHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                maxHeight = max(maxHeight, size.height)
                x += size.width + spacing
                self.size.width = max(self.size.width, x - spacing)
            }

            self.size.height = y + maxHeight
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
