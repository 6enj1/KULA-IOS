//
//  HomeView.swift
//  KULA
//
//  Home / Discovery Feed Screen
//

import SwiftUI
import CoreLocation

// MARK: - Home View
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var locationManager = LocationManager.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showFilters: Bool = false
    @State private var selectedBag: Bag?
    @State private var selectedAddress: SavedAddress = HomeView.loadSavedAddress()

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    // Load persisted address from UserDefaults
    private static func loadSavedAddress() -> SavedAddress {
        guard let data = UserDefaults.standard.data(forKey: "selectedAddress"),
              let address = try? JSONDecoder().decode(PersistedAddress.self, from: data) else {
            return SavedAddress.currentLocation(address: nil, lat: nil, lng: nil)
        }
        return address.toSavedAddress()
    }

    // Save address to UserDefaults
    private func saveSelectedAddress(_ address: SavedAddress) {
        let persisted = PersistedAddress(from: address)
        if let data = try? JSONEncoder().encode(persisted) {
            UserDefaults.standard.set(data, forKey: "selectedAddress")
        }
    }

    var body: some View {
        ZStack {
            AppBackgroundGradient()

            ScrollView {
                VStack(spacing: DesignSystem.Layout.sectionSpacing(isRegular: isRegularWidth)) {
                    // Header
                    headerSection
                        .adaptivePadding()

                    // Location banner — denied/restricted OR no location + not yet asked
                    if locationManager.isDeniedOrRestricted || (!appState.hasLocation && locationManager.canRequestPermission) {
                        locationBanner
                            .adaptivePadding()
                    }

                    // Content based on state
                    if appState.isLoading {
                        loadingStateView
                    } else if let error = appState.error, appState.bags.isEmpty {
                        errorStateView(error: error)
                    } else if appState.searchText.isEmpty {
                        // For You Section
                        forYouSection

                        // Nearby Now Section
                        nearbySection
                            .adaptivePadding()
                    } else {
                        // Search Results
                        searchResultsSection
                            .adaptivePadding()
                    }
                }
                .padding(.top, isRegularWidth ? DesignSystem.Spacing.xxl : DesignSystem.Spacing.md)
                .padding(.bottom, isRegularWidth ? 160 : 120) // Tab bar space
            }
            .refreshable {
                await appState.retryLoading()
            }
        }
        .navigationDestination(item: $selectedBag) { bag in
            if let restaurant = appState.restaurant(for: bag.restaurantId) {
                BagDetailView(bag: bag, restaurant: restaurant)
            }
        }
        .sheet(isPresented: $showFilters) {
            FilterSheet()
                .presentationDetents(DesignSystem.Layout.sheetDetents(isRegular: isRegularWidth))
                .presentationDragIndicator(.visible)
                .if(isRegularWidth) { view in
                    view.presentationContentInteraction(.scrolls)
                }
        }
        .sheet(isPresented: $appState.showAddressPicker) {
            AddressPickerSheet(selectedAddress: $selectedAddress)
                .presentationDetents(DesignSystem.Layout.sheetDetents(isRegular: isRegularWidth))
                .presentationDragIndicator(.visible)
                .if(isRegularWidth) { view in
                    view.presentationContentInteraction(.scrolls)
                }
        }
        .task {
            // Only set current location on first load if using default current location
            if selectedAddress.id == "current" && selectedAddress.latitude == nil {
                // Request location if needed
                if locationManager.canRequestPermission {
                    locationManager.requestPermission()
                } else if locationManager.isAuthorized {
                    if locationManager.currentLocation == nil {
                        locationManager.requestLocation()
                    } else if let address = locationManager.currentAddress {
                        // Location already available, use it
                        selectedAddress = SavedAddress.currentLocation(
                            address: address,
                            lat: locationManager.currentLocation?.coordinate.latitude,
                            lng: locationManager.currentLocation?.coordinate.longitude
                        )
                    }
                }
                // If denied/restricted, don't request - user can tap the banner
            }
        }
        .onChange(of: locationManager.currentAddress) { _, newAddress in
            // Only update if user is using current location (not a saved address)
            if selectedAddress.id == "current" {
                selectedAddress = SavedAddress.currentLocation(
                    address: newAddress,
                    lat: locationManager.currentLocation?.coordinate.latitude,
                    lng: locationManager.currentLocation?.coordinate.longitude
                )
            }
        }
        .onChange(of: selectedAddress) { _, newAddress in
            saveSelectedAddress(newAddress)
            Task { await appState.setActiveAddress(newAddress) }
        }
        // When location authorization changes (e.g., user enables in Settings), update
        .onChange(of: locationManager.authorizationStatus) { _, newStatus in
            #if DEBUG
            print("[HomeView] Location authorization changed to: \(newStatus.rawValue)")
            #endif
            // If user just authorized and using current location, request location
            if locationManager.isAuthorized && selectedAddress.id == "current" {
                locationManager.requestLocation()
            }
        }
    }

    // MARK: - Loading State
    private var loadingStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .tint(DesignSystem.Colors.accent)
            Text("Loading surprise bags...")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            Spacer()
        }
        .frame(minHeight: 300)
    }

    // MARK: - Error State
    private func errorStateView(error: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Unable to load bags")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text(error)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await appState.retryLoading()
                }
            } label: {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .font(DesignSystem.Typography.body.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.accent)
                .clipShape(Capsule())
            }
            Spacer()
        }
        .frame(minHeight: 300)
        .padding(.horizontal, DesignSystem.Spacing.xl)
    }

    // MARK: - Location Banner
    /// Adapts to permission state:
    /// - `.notDetermined` → "Enable" button triggers permission prompt
    /// - `.denied`/`.restricted` → "Settings" button opens system Settings
    private var locationBanner: some View {
        GlassCard {
            HStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.warning.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: locationManager.isDeniedOrRestricted
                          ? "location.slash.fill" : "location.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(DesignSystem.Colors.warning)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(locationManager.isDeniedOrRestricted
                         ? "Location Access Disabled" : "Location Access Needed")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Text("Enable location to see bags near you")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                Spacer()

                Button {
                    if locationManager.canRequestPermission {
                        locationManager.requestPermission()
                    } else {
                        locationManager.openAppSettings()
                    }
                } label: {
                    Text(locationManager.isDeniedOrRestricted ? "Settings" : "Enable")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.accent)
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: isRegularWidth ? 6 : 4) {
                Text("Good \(greeting)")
                    .font(DesignSystem.ScaledTypography.subheadline(isRegular: isRegularWidth))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                Text("Discover Surprise Bags")
                    .font(DesignSystem.ScaledTypography.title1(isRegular: isRegularWidth))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }

            Spacer()

            // Location indicator - scales up on iPad
            Button {
                appState.showAddressPicker = true
            } label: {
                HStack(spacing: isRegularWidth ? 6 : 4) {
                    Image(systemName: selectedAddress.icon)
                        .font(.system(size: isRegularWidth ? 14 : 12))
                    Text(selectedAddress.shortName)
                        .font(DesignSystem.ScaledTypography.caption(isRegular: isRegularWidth))
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: isRegularWidth ? 12 : 10, weight: .semibold))
                }
                .foregroundStyle(DesignSystem.Colors.accent)
                .padding(.horizontal, isRegularWidth ? DesignSystem.Spacing.md : DesignSystem.Spacing.sm)
                .padding(.vertical, isRegularWidth ? DesignSystem.Spacing.sm : DesignSystem.Spacing.xs)
                .background {
                    Capsule()
                        .fill(DesignSystem.Colors.accent.opacity(0.15))
                }
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        default: return "evening"
        }
    }

    // MARK: - For You Section
    private var forYouSection: some View {
        VStack(alignment: .leading, spacing: isRegularWidth ? DesignSystem.Spacing.lg : DesignSystem.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: isRegularWidth ? 4 : 2) {
                    Text("For You")
                        .font(DesignSystem.ScaledTypography.title3(isRegular: isRegularWidth))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Text("Personalized picks based on your taste")
                        .font(DesignSystem.ScaledTypography.caption(isRegular: isRegularWidth))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }

                Spacer()

                Image(systemName: "sparkles")
                    .font(.system(size: isRegularWidth ? 20 : 16))
                    .foregroundStyle(DesignSystem.Colors.warmAmber)
            }
            .adaptivePadding()

            // Horizontal carousel - cards scale up on iPad
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: isRegularWidth ? DesignSystem.Spacing.xl : DesignSystem.Spacing.md) {
                    if appState.forYouBags.isEmpty {
                        Text("No bags available")
                            .font(DesignSystem.ScaledTypography.subheadline(isRegular: isRegularWidth))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .adaptivePadding()
                    } else {
                        ForEach(appState.forYouBags) { bag in
                            if let restaurant = appState.restaurant(for: bag.restaurantId) {
                                CompactBagCard(bag: bag, restaurant: restaurant, isRegularWidth: isRegularWidth) {
                                    selectedBag = bag
                                }
                            } else {
                                // Debug: Show bag even without restaurant match
                                Text("Bag: \(bag.title) (no restaurant match)")
                                    .font(DesignSystem.ScaledTypography.caption(isRegular: isRegularWidth))
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Layout.horizontalPadding(isRegular: isRegularWidth))
            }
        }
    }

    // MARK: - Nearby Section
    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: isRegularWidth ? DesignSystem.Spacing.lg : DesignSystem.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nearby Now")
                        .font(DesignSystem.ScaledTypography.title3(isRegular: isRegularWidth))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Text("Available for pickup soon")
                        .font(DesignSystem.ScaledTypography.caption(isRegular: isRegularWidth))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }

                Spacer()

                Button {
                    // View all
                } label: {
                    Text("View all")
                        .font(DesignSystem.ScaledTypography.caption(isRegular: isRegularWidth))
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
            }

            // Adaptive grid: 1 column on iPhone, 2-3 on iPad (uses full width)
            AdaptiveGrid(appState.nearbyBags) { bag, isRegular in
                if let restaurant = appState.restaurant(for: bag.restaurantId) {
                    BagListingCard(
                        bag: bag,
                        restaurant: restaurant,
                        isSaved: binding(for: bag.id)
                    ) {
                        selectedBag = bag
                    }
                }
            }
        }
    }

    // MARK: - Search Results Section
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: isRegularWidth ? DesignSystem.Spacing.lg : DesignSystem.Spacing.md) {
            let results = appState.filteredBags(searchText: appState.searchText)

            Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                .font(DesignSystem.ScaledTypography.subheadline(isRegular: isRegularWidth))
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            if results.isEmpty {
                // Empty state
                VStack(spacing: DesignSystem.Spacing.lg) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: isRegularWidth ? 64 : 48))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)

                    Text("No bags found")
                        .font(DesignSystem.ScaledTypography.headline(isRegular: isRegularWidth))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Text("Try adjusting your search or filters")
                        .font(DesignSystem.ScaledTypography.body(isRegular: isRegularWidth))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.xxxl)
            } else {
                // Adaptive grid for search results - uses full width
                AdaptiveGrid(results) { bag, isRegular in
                    if let restaurant = appState.restaurant(for: bag.restaurantId) {
                        BagListingCard(
                            bag: bag,
                            restaurant: restaurant,
                            isSaved: binding(for: bag.id)
                        ) {
                            selectedBag = bag
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helper
    private func binding(for bagId: String) -> Binding<Bool> {
        Binding(
            get: { appState.isSaved(bagId: bagId) },
            set: { _ in appState.toggleSaved(bagId: bagId) }
        )
    }
}

// MARK: - Filter Sheet
struct FilterSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var priceRange: ClosedRange<Double> = 0...200
    @State private var maxDistance: Double = 10.0
    @State private var selectedFoodTypes: Set<String> = []
    @State private var minRating: Double = 0

    var body: some View {
        ZStack {
            AppBackgroundGradient()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Reset") {
                        resetFilters()
                    }
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                    Spacer()

                    Text("Filters")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Spacer()

                    Button("Done") {
                        applyFilters()
                        dismiss()
                    }
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.accent)
                }
                .padding()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Price Range
                        filterSection("Price Range") {
                            VStack(spacing: DesignSystem.Spacing.sm) {
                                HStack {
                                    Text("R\(Int(priceRange.lowerBound))")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                    Spacer()
                                    Text("R\(Int(priceRange.upperBound))")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                }

                                // Custom range slider workaround
                                HStack(spacing: 0) {
                                    Slider(value: Binding(
                                        get: { priceRange.upperBound },
                                        set: { priceRange = priceRange.lowerBound...$0 }
                                    ), in: 0...200, step: 10)
                                    .tint(DesignSystem.Colors.accent)
                                }
                            }
                        }

                        // Distance
                        filterSection("Maximum Distance") {
                            VStack(spacing: DesignSystem.Spacing.sm) {
                                HStack {
                                    Text("\(String(format: "%.1f", maxDistance)) km")
                                        .font(DesignSystem.Typography.headline)
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                    Spacer()
                                }

                                Slider(value: $maxDistance, in: 0.5...20, step: 0.5)
                                    .tint(DesignSystem.Colors.accent)
                            }
                        }

                        // Food Types
                        filterSection("Food Type") {
                            FlowLayout(spacing: DesignSystem.Spacing.xs) {
                                ForEach(appState.categories) { category in
                                    FilterChip(
                                        title: category.name,
                                        isSelected: selectedFoodTypes.contains(category.name)
                                    ) {
                                        if selectedFoodTypes.contains(category.name) {
                                            selectedFoodTypes.remove(category.name)
                                        } else {
                                            selectedFoodTypes.insert(category.name)
                                        }
                                    }
                                }
                            }
                        }

                        // Minimum Rating
                        filterSection("Minimum Rating") {
                            HStack(spacing: DesignSystem.Spacing.md) {
                                ForEach([0, 3.0, 3.5, 4.0, 4.5], id: \.self) { rating in
                                    Button {
                                        minRating = rating
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    } label: {
                                        HStack(spacing: 4) {
                                            if rating > 0 {
                                                Image(systemName: "star.fill")
                                                    .font(.system(size: 12))
                                                Text(String(format: "%.1f+", rating))
                                            } else {
                                                Text("Any")
                                            }
                                        }
                                        .font(DesignSystem.Typography.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(minRating == rating ? .black : DesignSystem.Colors.textPrimary)
                                        .padding(.horizontal, DesignSystem.Spacing.sm)
                                        .padding(.vertical, DesignSystem.Spacing.xs)
                                        .background {
                                            Capsule()
                                                .fill(minRating == rating ? DesignSystem.Colors.accent : DesignSystem.Colors.glassFill)
                                        }
                                    }
                                }

                                Spacer()
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .padding(.bottom, 100)
                }

                // Apply button
                PrimaryButton("Apply Filters", icon: "slider.horizontal.3") {
                    applyFilters()
                    dismiss()
                }
                .padding(DesignSystem.Spacing.lg)
                .background {
                    GlassBackground(intensity: .heavy)
                        .ignoresSafeArea()
                }
            }
        }
        .onAppear {
            // Load current filters
            priceRange = appState.filterOptions.priceRange
            maxDistance = appState.filterOptions.maxDistance
            selectedFoodTypes = appState.filterOptions.foodTypes
            minRating = appState.filterOptions.minRating
        }
    }

    @ViewBuilder
    private func filterSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(title)
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            GlassCard(padding: DesignSystem.Spacing.md) {
                content()
            }
        }
    }

    private func resetFilters() {
        priceRange = 0...200
        maxDistance = 10.0
        selectedFoodTypes = []
        minRating = 0
    }

    private func applyFilters() {
        var options = FilterOptions()
        options.priceRange = priceRange
        options.maxDistance = maxDistance
        options.foodTypes = selectedFoodTypes
        options.minRating = minRating
        options.save()
        appState.filterOptions = options
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            Text(title)
                .font(DesignSystem.Typography.subheadline)
                .fontWeight(.medium)
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

// MARK: - Address Picker Sheet
struct AddressPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @Binding var selectedAddress: SavedAddress
    @StateObject private var locationManager = LocationManager.shared
    @State private var searchText: String = ""
    @State private var keyboardHeight: CGFloat = 0
    @State private var isInSearchMode: Bool = false
    @State private var savedAddresses: [SavedAddress] = []
    @State private var isLoadingAddresses: Bool = false
    @State private var addingLabelType: SavedAddress.AddressType? = nil
    @StateObject private var searchCompleter = AddressSearchCompleter()
    @FocusState private var isSearchFocused: Bool

    private var currentLocationAddress: SavedAddress {
        SavedAddress.currentLocation(
            address: locationManager.currentAddress,
            lat: locationManager.currentLocation?.coordinate.latitude,
            lng: locationManager.currentLocation?.coordinate.longitude
        )
    }

    private var filteredAddresses: [SavedAddress] {
        if searchText.isEmpty {
            return savedAddresses
        } else {
            return savedAddresses.filter { address in
                address.name.localizedCaseInsensitiveContains(searchText) ||
                address.fullAddress.localizedCaseInsensitiveContains(searchText) ||
                address.shortName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        ZStack {
            // Background
            AppBackgroundGradient()

            VStack(spacing: 0) {
                // Header
                Text("Addresses")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if isInSearchMode {
                            // Search Results
                            searchResultsSection
                        } else {
                            // Quick Label Cards (Home, Work, + Add)
                            quickLabelCardsSection

                            // Explore Nearby (Current Location)
                            exploreNearbySection

                            // Saved Addresses
                            savedAddressesSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, keyboardHeight > 0 ? keyboardHeight + 80 : 120)
                    .animation(.easeInOut(duration: 0.2), value: isInSearchMode)
                }
                .scrollDismissesKeyboard(.immediately)
                .onChange(of: isSearchFocused) { _, focused in
                    if focused {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isInSearchMode = true
                        }
                    }
                }
            }

            // Bottom floating search bar + home button
            VStack {
                Spacer()
                HStack(spacing: 10) {
                    searchField
                    homeButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, keyboardHeight > 0 ? keyboardHeight + 12 : 24)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    keyboardHeight = keyboardFrame.height
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                keyboardHeight = 0
            }
        }
        .onAppear {
            // Request location permission and get current location
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestPermission()
            } else if locationManager.authorizationStatus == .authorizedWhenInUse ||
                      locationManager.authorizationStatus == .authorizedAlways {
                locationManager.requestLocation()
            }

            // Load saved addresses from API
            loadSavedAddresses()
        }
    }

    // MARK: - Load Addresses
    private func loadSavedAddresses() {
        isLoadingAddresses = true
        Task {
            do {
                let addresses = try await AddressService.shared.getAddresses()
                await MainActor.run {
                    savedAddresses = addresses
                    isLoadingAddresses = false
                }
            } catch {
                #if DEBUG
                print("[Home] Failed to load addresses: \(error)")
                #endif
                await MainActor.run {
                    isLoadingAddresses = false
                }
            }
        }
    }

    // MARK: - Search Field
    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))

            TextField("Search for an address", text: $searchText)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white)
                .tint(DesignSystem.Colors.accent)
                .focused($isSearchFocused)
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 24, height: 24)
                        .background {
                            Circle()
                                .fill(.white.opacity(0.15))
                                .overlay {
                                    Circle()
                                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                                }
                        }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.1), .white.opacity(0.03), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .overlay {
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .white.opacity(0.1), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
        }
        .shadow(color: .black.opacity(0.2), radius: 15, y: 8)
    }

    // MARK: - Home Button
    private var homeButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            if isInSearchMode {
                // Exit search mode
                isSearchFocused = false
                searchText = ""
                withAnimation(.easeInOut(duration: 0.2)) {
                    isInSearchMode = false
                }
            } else {
                dismiss()
            }
        } label: {
            Image(systemName: isInSearchMode ? "xmark" : "house")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 48, height: 48)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .overlay {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.12),
                                            .white.opacity(0.04),
                                            .clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.3),
                                            .white.opacity(0.1),
                                            .white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                }
        }
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
    }

    // MARK: - Search Results
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Show address suggestions from search completer
            if !searchCompleter.suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(searchCompleter.suggestions) { suggestion in
                        Button {
                            selectSuggestion(suggestion)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(DesignSystem.Colors.accent)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.title)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white)
                                        .lineLimit(1)

                                    if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.5))
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 4)
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .background(.white.opacity(0.1))
                            .padding(.leading, 44)
                    }
                }
            } else if searchText.isEmpty {
                // Show prompt when no search text
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.2))

                    Text("Search for an address")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.6))

                    Text("Type a street, city, or landmark")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else if searchCompleter.isSearching {
                // Loading state
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                }
                .padding(.vertical, 40)
            } else {
                // No results
                VStack(spacing: 12) {
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("No addresses found")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
        .onChange(of: searchText) { _, newValue in
            searchCompleter.search(query: newValue)
        }
    }

    private func selectSuggestion(_ suggestion: AddressSuggestion) {
        Task {
            if let result = await searchCompleter.getDetails(for: suggestion) {
                await MainActor.run {
                    if let labelType = addingLabelType {
                        // Save as label
                        saveSuggestionAsLabel(result, type: labelType)
                    } else {
                        // Just select it
                        let address = SavedAddress(
                            id: UUID().uuidString,
                            name: result.name,
                            shortName: result.name,
                            fullAddress: result.address,
                            icon: "mappin.circle.fill",
                            type: .saved,
                            latitude: result.latitude,
                            longitude: result.longitude
                        )
                        selectAddress(address)
                    }
                }
            }
        }
    }

    private func saveSuggestionAsLabel(_ result: AddressResult, type: SavedAddress.AddressType) {
        let label = type == .home ? "Home" : type == .work ? "Work" : "Saved"
        let typeString = type == .home ? "home" : type == .work ? "work" : "other"

        Task {
            do {
                let newAddress = try await AddressService.shared.addAddress(
                    label: label,
                    addressType: typeString,
                    addressLine1: result.address,
                    city: result.city,
                    province: result.province,
                    postalCode: result.postalCode,
                    latitude: result.latitude,
                    longitude: result.longitude
                )
                await MainActor.run {
                    savedAddresses.append(newAddress)
                    addingLabelType = nil
                    searchText = ""
                    isSearchFocused = false
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isInSearchMode = false
                    }
                }
            } catch {
                #if DEBUG
                print("[Home] Failed to save address: \(error)")
                #endif
            }
        }
    }

    // MARK: - Quick Label Cards
    private var homeAddress: SavedAddress? {
        savedAddresses.first { $0.type == .home }
    }

    private var workAddress: SavedAddress? {
        savedAddresses.first { $0.type == .work }
    }

    private var quickLabelCardsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Home Card
                QuickLabelCard(
                    icon: "house.fill",
                    label: "Home",
                    address: homeAddress,
                    accentColor: .orange
                ) {
                    if let home = homeAddress {
                        selectAddress(home)
                    } else {
                        startAddingLabel(.home)
                    }
                }

                // Work Card
                QuickLabelCard(
                    icon: "briefcase.fill",
                    label: "Work",
                    address: workAddress,
                    accentColor: DesignSystem.Colors.accent
                ) {
                    if let work = workAddress {
                        selectAddress(work)
                    } else {
                        startAddingLabel(.work)
                    }
                }

                // Add Label Card
                Button {
                    startAddingLabel(.saved)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.accent)
                            .frame(width: 32, height: 32)
                            .background {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(DesignSystem.Colors.accent.opacity(0.15))
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add Label")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)

                            Text("Save address")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                            }
                    }
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func startAddingLabel(_ type: SavedAddress.AddressType) {
        addingLabelType = type
        withAnimation(.easeInOut(duration: 0.2)) {
            isInSearchMode = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isSearchFocused = true
        }
    }

    // MARK: - Explore Nearby
    private var exploreNearbySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Explore nearby")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.6))
                .textCase(.uppercase)

            Button {
                selectAddress(currentLocationAddress)
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        if locationManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.accent))
                                .frame(width: 36, height: 36)
                        } else {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(DesignSystem.Colors.accent)
                                .frame(width: 36, height: 36)
                        }
                    }
                    .background(DesignSystem.Colors.accent.opacity(0.15))
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use current location")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)

                        if let error = locationManager.error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red.opacity(0.8))
                                .lineLimit(1)
                        } else {
                            Text(currentLocationAddress.fullAddress)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if locationManager.authorizationStatus == .denied {
                        Text("Enable in Settings")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(14)
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Saved Addresses
    @ViewBuilder
    private var savedAddressesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saved addresses")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.6))
                .textCase(.uppercase)

            if isLoadingAddresses {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                }
                .padding(.vertical, 30)
            } else if savedAddresses.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("No saved addresses")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Add addresses from the profile settings")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(savedAddresses.enumerated()), id: \.element.id) { index, address in
                        Button {
                            selectAddress(address)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: address.icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(iconColor(for: address.type))
                                    .frame(width: 36, height: 36)
                                    .background(iconColor(for: address.type).opacity(0.15))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(address.name)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white)

                                    Text(address.fullAddress)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.6))
                                        .lineLimit(1)
                                }

                                Spacer()
                            }
                            .padding(14)
                        }
                        .buttonStyle(.plain)

                        if index < savedAddresses.count - 1 {
                            Divider()
                                .background(.white.opacity(0.1))
                                .padding(.leading, 62)
                        }
                    }
                }
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                }
            }
        }
    }

    // MARK: - Helpers
    private func selectAddress(_ address: SavedAddress) {
        isSearchFocused = false
        isInSearchMode = false
        selectedAddress = address
        dismiss()
    }

    private func iconColor(for type: SavedAddress.AddressType) -> Color {
        switch type {
        case .home: return .orange
        case .work: return DesignSystem.Colors.accent
        case .current: return .green
        case .saved: return .purple
        }
    }
}

// MARK: - Quick Label Card
struct QuickLabelCard: View {
    let icon: String
    let label: String
    let address: SavedAddress?
    let accentColor: Color
    let onTap: () -> Void

    private var hasAddress: Bool { address != nil }

    private var addressPreview: String {
        guard let addr = address else { return "Add address" }
        let short = addr.fullAddress.components(separatedBy: ",").first ?? addr.fullAddress
        return short.count > 18 ? String(short.prefix(16)) + "…" : short
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(hasAddress ? accentColor : .gray.opacity(0.6))
                    .frame(width: 32, height: 32)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(hasAddress ? accentColor.opacity(0.15) : Color.gray.opacity(0.1))
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    Text(addressPreview)
                        .font(.caption)
                        .foregroundStyle(hasAddress ? .white.opacity(0.6) : .gray.opacity(0.5))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                    }
            }
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environmentObject(AppState())
}

#Preview("Address Picker") {
    AddressPickerSheet(selectedAddress: .constant(SavedAddress.currentLocation(address: nil, lat: nil, lng: nil)))
        .environmentObject(AppState())
}
