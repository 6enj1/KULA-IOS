//
//  AppState.swift
//  KULA
//
//  Global App State Management
//

import SwiftUI
import Combine
import CoreLocation

// MARK: - App State
@MainActor
final class AppState: ObservableObject {
    // Authentication
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    @Published var error: String?

    // Data
    @Published var restaurants: [Restaurant] = []
    @Published var bags: [Bag] = []
    @Published var orders: [Order] = []
    @Published var savedBagIds: Set<String> = []
    @Published var categories: [FoodCategory] = []

    // Filter state
    @Published var filterOptions: FilterOptions = FilterOptions.load()

    // Search state
    @Published var searchText: String = ""
    @Published var isSearchActive: Bool = false
    @Published var isRecording: Bool = false

    // Navigation
    @Published var selectedBag: Bag?
    @Published var selectedRestaurant: Restaurant?

    // Address Picker
    @Published var showAddressPicker: Bool = false

    // Directions Sheet
    @Published var showDirectionsSheet: Bool = false

    // Location — single source of truth for all API calls
    // In DEBUG, use hardcoded Johannesburg default so the simulator always has data.
    // In production, nil means "no location resolved" → UI shows "Enable location" banner.
    #if DEBUG
    @Published var effectiveLatitude: Double? = -26.1255
    @Published var effectiveLongitude: Double? = 28.0347
    #else
    @Published var effectiveLatitude: Double?
    @Published var effectiveLongitude: Double?
    #endif
    @Published var isUsingManualAddress: Bool = false
    private var locationCancellable: AnyCancellable?
    private var lastFetchedLocation: CLLocation?
    private var didSyncLocationThisSession = false

    /// Whether a usable location has been resolved (GPS, manual, or server-stored).
    var hasLocation: Bool { effectiveLatitude != nil && effectiveLongitude != nil }

    // Services
    private let authService = AuthService.shared
    private let bagService = BagService.shared
    private let orderService = OrderService.shared

    // Auth state flags to prevent double-submit and race conditions
    private var isAuthenticating = false

    // MARK: - Initialization
    init() {
        // Subscribe to device GPS updates (2s debounce to avoid spam during initial acquisition)
        locationCancellable = LocationManager.shared.$currentLocation
            .compactMap { $0 }
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] location in
                guard let self else { return }
                Task { @MainActor in
                    self.handleDeviceLocationUpdate(location)
                }
            }

        // Check if user has stored tokens - but DON'T set isAuthenticated yet
        // We need to validate tokens with the backend first
        if TokenManager.shared.isLoggedIn {
            Task {
                await validateSessionAndLoadData()
            }
        }
    }

    /// Validates stored tokens by fetching user data. Only sets isAuthenticated on success.
    private func validateSessionAndLoadData() async {
        #if DEBUG
        print("[AppState] Validating stored session...")
        #endif
        isLoading = true

        do {
            // Validate tokens by fetching current user
            currentUser = try await authService.getCurrentUser()
            #if DEBUG
            print("[AppState] Session valid, user loaded")
            #endif

            // Session is valid - now safe to set authenticated
            isAuthenticated = true

            // Load remaining data
            await loadInitialData()
        } catch let error as APIError {
            if case .unauthorized = error {
                // Tokens are invalid/expired - clear them
                #if DEBUG
                print("[AppState] Session invalid, clearing tokens")
                #endif
                TokenManager.shared.clearTokens()
                isAuthenticated = false
                currentUser = nil
            } else {
                // Other API error - tokens might still be valid
                // Don't clear tokens, but don't authenticate either
                #if DEBUG
                print("[AppState] API error during validation: \(error)")
                #endif
                self.error = "Unable to connect. Please try again."
            }
        } catch {
            #if DEBUG
            print("[AppState] Unknown error during validation: \(error)")
            #endif
            self.error = "Unable to connect. Please try again."
        }

        isLoading = false
    }

    // MARK: - Load Initial Data
    func loadInitialData() async {
        #if DEBUG
        print("[AppState] loadInitialData() called")
        #endif
        isLoading = true
        error = nil

        do {
            // Load user if authenticated
            if TokenManager.shared.isLoggedIn {
                currentUser = try await authService.getCurrentUser()
                #if DEBUG
                print("[AppState] User loaded")
                #endif
            }

            // Load categories
            categories = try await bagService.getCategories()
            #if DEBUG
            print("[AppState] Categories loaded: \(categories.count)")
            #endif

            // Resolve best available location for initial data fetch
            resolveInitialLocation()

            // Only fetch bags/restaurants if we have a resolved location
            if let lat = effectiveLatitude, let lng = effectiveLongitude {
                async let bagsResult = bagService.getBags(
                    latitude: lat,
                    longitude: lng,
                    maxDistance: filterOptions.maxDistance
                )
                async let restaurantsResult = bagService.getRestaurants(
                    latitude: lat,
                    longitude: lng
                )

                bags = try await bagsResult
                restaurants = try await restaurantsResult

                #if DEBUG
                print("[AppState] Bags loaded: \(bags.count)")
                print("[AppState] Restaurants loaded: \(restaurants.count)")
                #endif
            } else {
                #if DEBUG
                print("[AppState] No location resolved — skipping bag/restaurant fetch")
                #endif
            }

            // Load orders if authenticated
            if isAuthenticated {
                orders = try await orderService.getOrders()
                #if DEBUG
                print("[AppState] Orders loaded: \(orders.count)")
                #endif

                // Load favorites
                let favorites = try await bagService.getFavorites()
                savedBagIds = Set(favorites.map { $0.id })
                #if DEBUG
                print("[AppState] Favorites loaded: \(savedBagIds.count)")
                #endif
            }

            #if DEBUG
            print("[AppState] All data loaded successfully!")
            #endif
        } catch let error as APIError {
            if case .unauthorized = error {
                // Token expired or invalid - force re-login
                #if DEBUG
                print("[AppState] Unauthorized - clearing tokens")
                #endif
                TokenManager.shared.clearTokens()
                isAuthenticated = false
                currentUser = nil
                self.error = "Session expired. Please sign in again."
            } else {
                self.error = error.localizedDescription
                #if DEBUG
                print("[AppState] Error loading data: \(error)")
                #endif
            }
        } catch {
            self.error = error.localizedDescription
            #if DEBUG
            print("[AppState] Error loading data: \(error)")
            #endif
        }

        isLoading = false
    }

    // MARK: - Retry Loading
    func retryLoading() async {
        await loadInitialData()
    }

    // MARK: - Authentication Methods
    /// Sign in with email/password. Does NOT set isAuthenticated - let onboarding flow handle that.
    func signIn(email: String, password: String) async {
        // Prevent double-submit
        guard !isAuthenticating else {
            #if DEBUG
            print("[AppState] signIn() ignored - already authenticating")
            #endif
            return
        }

        #if DEBUG
        print("[AppState] signIn() called")
        #endif
        isAuthenticating = true
        isLoading = true
        error = nil

        do {
            currentUser = try await authService.login(email: email, password: password)
            #if DEBUG
            print("[AppState] Login successful")
            #endif
            // Don't set isAuthenticated here - let handlePostAuthNavigation() decide
            await loadInitialData()
        } catch {
            self.error = error.localizedDescription
            currentUser = nil // Ensure no partial state
        }

        isLoading = false
        isAuthenticating = false
    }

    /// Register new account. Does NOT set isAuthenticated - let onboarding flow handle that.
    func register(email: String, password: String, name: String) async {
        // Prevent double-submit
        guard !isAuthenticating else {
            #if DEBUG
            print("[AppState] register() ignored - already authenticating")
            #endif
            return
        }

        #if DEBUG
        print("[AppState] register() called")
        #endif
        isAuthenticating = true
        isLoading = true
        error = nil

        do {
            currentUser = try await authService.register(email: email, password: password, name: name)
            #if DEBUG
            print("[AppState] Registration successful")
            #endif
            // Don't set isAuthenticated here - let handlePostAuthNavigation() decide
            await loadInitialData()
        } catch {
            self.error = error.localizedDescription
            currentUser = nil // Ensure no partial state
        }

        isLoading = false
        isAuthenticating = false
    }

    /// Sign in with Apple. Does NOT set isAuthenticated - let onboarding flow handle that.
    func signInWithApple() async {
        // Prevent double-submit
        guard !isAuthenticating else {
            #if DEBUG
            print("[AppState] signInWithApple() ignored - already authenticating")
            #endif
            return
        }

        isAuthenticating = true
        isLoading = true
        error = nil

        do {
            // Get Apple credentials
            let appleResult = try await AppleSignInManager.shared.signIn()

            // Send to backend for authentication
            currentUser = try await authService.socialAuth(
                provider: "apple",
                token: appleResult.identityToken,
                email: appleResult.email,
                name: appleResult.displayName
            )
            // Don't set isAuthenticated here - let handlePostAuthNavigation() decide
            await loadInitialData()
        } catch let signInError as AppleSignInError {
            switch signInError {
            case .cancelled:
                // User cancelled - don't show error, clear any partial state
                #if DEBUG
                print("[AppState] Apple Sign In cancelled")
                #endif
                currentUser = nil
            default:
                self.error = signInError.localizedDescription
                currentUser = nil
                #if DEBUG
                print("[AppState] Apple Sign In error: \(signInError)")
                #endif
            }
        } catch {
            self.error = error.localizedDescription
            currentUser = nil
            #if DEBUG
            print("[AppState] Apple Sign In error: \(error)")
            #endif
        }

        isLoading = false
        isAuthenticating = false
    }

    /// Sign in with Google. Does NOT set isAuthenticated - let onboarding flow handle that.
    func signInWithGoogle() async {
        // Prevent double-submit
        guard !isAuthenticating else {
            #if DEBUG
            print("[AppState] signInWithGoogle() ignored - already authenticating")
            #endif
            return
        }

        isAuthenticating = true
        isLoading = true
        error = nil

        do {
            // Get Google credentials
            let googleResult = try await GoogleSignInManager.shared.signIn()

            // Send to backend for authentication
            currentUser = try await authService.socialAuth(
                provider: "google",
                token: googleResult.idToken,
                email: googleResult.email,
                name: googleResult.name
            )
            // Don't set isAuthenticated here - let handlePostAuthNavigation() decide
            await loadInitialData()
        } catch let signInError as GoogleSignInError {
            switch signInError {
            case .cancelled:
                // User cancelled - don't show error, clear any partial state
                #if DEBUG
                print("[AppState] Google Sign In cancelled")
                #endif
                currentUser = nil
            case .missingClientID:
                self.error = "Google Sign In not configured. Please contact support."
                currentUser = nil
                #if DEBUG
                print("[AppState] Google Sign In error: Missing client ID")
                #endif
            default:
                self.error = signInError.localizedDescription
                currentUser = nil
                #if DEBUG
                print("[AppState] Google Sign In error: \(signInError)")
                #endif
            }
        } catch {
            self.error = error.localizedDescription
            currentUser = nil
            #if DEBUG
            print("[AppState] Google Sign In error: \(error)")
            #endif
        }

        isLoading = false
        isAuthenticating = false
    }

    func signOut() async {
        await authService.logout()
        isAuthenticated = false
        currentUser = nil
        orders = []
        savedBagIds = []
    }

    // MARK: - Bag Actions
    func toggleSaved(bagId: String) {
        let wasActive = savedBagIds.contains(bagId)

        // Optimistic update
        if wasActive {
            savedBagIds.remove(bagId)
        } else {
            savedBagIds.insert(bagId)
        }

        // Sync with server
        Task {
            do {
                let isFavorited = try await bagService.toggleFavorite(bagId: bagId, isFavorited: wasActive)
                // Update based on server response
                if isFavorited {
                    savedBagIds.insert(bagId)
                } else {
                    savedBagIds.remove(bagId)
                }
            } catch {
                // Revert on error
                if wasActive {
                    savedBagIds.insert(bagId)
                } else {
                    savedBagIds.remove(bagId)
                }
                self.error = error.localizedDescription
            }
        }
    }

    func isSaved(bagId: String) -> Bool {
        savedBagIds.contains(bagId)
    }

    // MARK: - Order Actions
    func createOrder(bag: Bag, quantity: Int) async -> (Order?, String?) {
        isLoading = true
        error = nil

        do {
            let result = try await orderService.createOrder(bagId: bag.id, quantity: quantity)

            // Add order to local state
            orders.insert(result.order, at: 0)

            isLoading = false

            // Return order and payment URL
            return (result.order, result.paymentUrl)
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return (nil, nil)
        }
    }

    func openPayment(url: String) {
        orderService.openPaymentUrl(url)
    }

    func refreshOrders() async {
        do {
            orders = try await orderService.getOrders()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateOrderStatus(orderId: String, status: OrderStatus) {
        if let index = orders.firstIndex(where: { $0.id == orderId }) {
            orders[index].status = status
        }
    }

    func markArrived(orderId: String) async {
        do {
            let updated = try await orderService.markArrived(orderId: orderId)
            if let index = orders.firstIndex(where: { $0.id == orderId }) {
                orders[index] = updated
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addReview(orderId: String, rating: Int, text: String) async {
        do {
            try await orderService.submitReview(orderId: orderId, rating: rating, text: text)

            // Update local state
            if let index = orders.firstIndex(where: { $0.id == orderId }) {
                orders[index].review = Review(rating: rating, text: text, createdAt: Date())
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - User Actions
    func updatePreferences(_ preferences: [String]) async {
        // Always try to save to backend (requires authentication)
        do {
            try await authService.updatePreferences(preferences)
            #if DEBUG
            print("[AppState] Preferences saved: \(preferences)")
            #endif

            // Reload user to ensure local state is in sync
            currentUser = try await authService.getCurrentUser()
        } catch {
            self.error = error.localizedDescription
            #if DEBUG
            print("[AppState] Failed to save preferences: \(error)")
            #endif
        }
    }

    func updateLocation(_ location: UserLocation) async {
        guard var user = currentUser else { return }
        user.location = location
        currentUser = user

        // Also update effective coords so all API calls use the new location
        effectiveLatitude = location.latitude
        effectiveLongitude = location.longitude

        do {
            try await authService.updateLocation(latitude: location.latitude, longitude: location.longitude)
            await refreshDataForCurrentLocation()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateNotificationSetting(enabled: Bool) async {
        do {
            try await authService.updateNotifications(enabled: enabled)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addLoyaltyPoints(_ points: Int) {
        guard var user = currentUser else { return }
        user.loyaltyPoints += points
        currentUser = user
    }

    // MARK: - Device GPS Location

    /// Applies a 500m significant-change filter, updates effective coords, and refreshes data.
    /// Backend sync happens at most once per session to avoid excessive PATCH calls.
    private func handleDeviceLocationUpdate(_ location: CLLocation) {
        // Ignore GPS updates when user has manually picked a saved address
        guard !isUsingManualAddress else { return }

        // Significant-change filter: skip if moved less than 500m from last fetch
        if let last = lastFetchedLocation, location.distance(from: last) < 500 {
            return
        }

        #if DEBUG
        print("[AppState] Device location update: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        #endif

        lastFetchedLocation = location
        effectiveLatitude = location.coordinate.latitude
        effectiveLongitude = location.coordinate.longitude

        Task {
            await refreshDataForCurrentLocation()
        }

        // Sync to backend at most once per session
        if !didSyncLocationThisSession {
            didSyncLocationThisSession = true
            syncLocationToBackend(lat: location.coordinate.latitude, lng: location.coordinate.longitude)
        }
    }

    /// Fetches bags and restaurants using the current effective coordinates (parallel).
    func refreshDataForCurrentLocation() async {
        guard let lat = effectiveLatitude, let lng = effectiveLongitude else { return }
        do {
            async let bagsResult = bagService.getBags(
                latitude: lat,
                longitude: lng,
                maxDistance: filterOptions.maxDistance
            )
            async let restaurantsResult = bagService.getRestaurants(
                latitude: lat,
                longitude: lng
            )

            bags = try await bagsResult
            restaurants = try await restaurantsResult

            #if DEBUG
            print("[AppState] Data refreshed for (\(lat), \(lng)): \(bags.count) bags, \(restaurants.count) restaurants")
            #endif
        } catch {
            self.error = error.localizedDescription
            #if DEBUG
            print("[AppState] Error refreshing data for location: \(error)")
            #endif
        }
    }

    /// Fire-and-forget PATCH to keep the server in sync with device location.
    private func syncLocationToBackend(lat: Double, lng: Double) {
        Task {
            do {
                try await authService.updateLocation(latitude: lat, longitude: lng)
                #if DEBUG
                print("[AppState] Location synced to backend: \(lat), \(lng)")
                #endif
            } catch {
                #if DEBUG
                print("[AppState] Failed to sync location to backend: \(error)")
                #endif
            }
        }
    }

    /// Priority: manual address > device GPS > server-stored > (DEBUG-only hardcoded).
    /// In production, coords remain nil if no source is available → UI shows "Enable location".
    private func resolveInitialLocation() {
        // 1. Manual address — effective coords already set by setActiveAddress
        if isUsingManualAddress, effectiveLatitude != nil {
            #if DEBUG
            print("[AppState] Keeping manual address: \(effectiveLatitude!), \(effectiveLongitude!)")
            #endif
            return
        }

        // 2. Device GPS
        if let deviceLocation = LocationManager.shared.currentLocation {
            effectiveLatitude = deviceLocation.coordinate.latitude
            effectiveLongitude = deviceLocation.coordinate.longitude
            lastFetchedLocation = deviceLocation
            #if DEBUG
            print("[AppState] Using device GPS: \(deviceLocation.coordinate.latitude), \(deviceLocation.coordinate.longitude)")
            #endif
            return
        }

        // 3. Server-stored user location (restores state from last session)
        if let serverLocation = currentUser?.location {
            effectiveLatitude = serverLocation.latitude
            effectiveLongitude = serverLocation.longitude
            #if DEBUG
            print("[AppState] Using server location: \(serverLocation.latitude), \(serverLocation.longitude)")
            #endif
            return
        }

        // 4. DEBUG-only hardcoded fallback — never used in production
        #if DEBUG
        if effectiveLatitude == nil {
            effectiveLatitude = -26.1255
            effectiveLongitude = 28.0347
            print("[AppState] Using DEBUG hardcoded default")
        }
        #endif
        // Production: coords remain nil → HomeView shows "Enable location" banner
    }

    /// Called by HomeView when user picks an address from the picker.
    /// Toggles `isUsingManualAddress` and re-fetches data for the selected address.
    func setActiveAddress(_ address: SavedAddress) async {
        if address.type == .current {
            // Switching back to "Current Location" — re-enable GPS-driven updates
            isUsingManualAddress = false
            if let deviceLocation = LocationManager.shared.currentLocation {
                effectiveLatitude = deviceLocation.coordinate.latitude
                effectiveLongitude = deviceLocation.coordinate.longitude
                lastFetchedLocation = deviceLocation
            }
        } else {
            // User picked a saved address — override GPS
            isUsingManualAddress = true
            if let lat = address.latitude, let lng = address.longitude {
                effectiveLatitude = lat
                effectiveLongitude = lng
            }
        }

        #if DEBUG
        print("[AppState] Active address set: \(address.name) (manual=\(isUsingManualAddress)) -> (\(effectiveLatitude), \(effectiveLongitude))")
        #endif

        await refreshDataForCurrentLocation()
    }

    // MARK: - Helper Methods
    func restaurant(for id: String) -> Restaurant? {
        let result = restaurants.first { $0.id == id }
        #if DEBUG
        if result == nil && !restaurants.isEmpty {
            print("[AppState] No restaurant found for id: \(id)")
        }
        #endif
        return result
    }

    func bag(for id: String) -> Bag? {
        bags.first { $0.id == id }
    }

    var activeOrders: [Order] {
        orders.filter { $0.status == .paid || $0.status == .ready }
    }

    var pastOrders: [Order] {
        orders.filter { $0.status == .collected || $0.status == .cancelled }
    }

    // MARK: - Filtered & Sorted Bags
    var forYouBags: [Bag] {
        Array(bags.sorted { $0.savingsPercentage > $1.savingsPercentage }.prefix(5))
    }

    var nearbyBags: [Bag] {
        bags.sorted { bag1, bag2 in
            let dist1 = restaurant(for: bag1.restaurantId)?.distanceKm ?? 999
            let dist2 = restaurant(for: bag2.restaurantId)?.distanceKm ?? 999
            return dist1 < dist2
        }
    }

    func filteredBags(searchText: String) -> [Bag] {
        var result = bags

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { bag in
                let restaurant = self.restaurant(for: bag.restaurantId)
                return bag.title.localizedCaseInsensitiveContains(searchText) ||
                       bag.foodType.localizedCaseInsensitiveContains(searchText) ||
                       bag.description.localizedCaseInsensitiveContains(searchText) ||
                       restaurant?.name.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        // Apply filter options
        result = result.filter { bag in
            // Price filter
            guard bag.priceNow >= filterOptions.priceRange.lowerBound &&
                  bag.priceNow <= filterOptions.priceRange.upperBound else { return false }

            // Distance filter
            if let restaurant = self.restaurant(for: bag.restaurantId),
               restaurant.distanceKm > filterOptions.maxDistance {
                return false
            }

            // Rating filter
            if let restaurant = self.restaurant(for: bag.restaurantId),
               restaurant.rating < filterOptions.minRating {
                return false
            }

            // Food type filter
            if !filterOptions.foodTypes.isEmpty &&
               !filterOptions.foodTypes.contains(bag.foodType) {
                return false
            }

            return true
        }

        return result
    }

    func bagsForCategory(_ name: String) -> [Bag] {
        filteredBags(searchText: "").filter {
            $0.foodType.localizedCaseInsensitiveCompare(name) == .orderedSame
        }
    }

    func bagsForRestaurant(_ id: String) -> [Bag] {
        bags.filter { $0.restaurantId == id }
    }

    // MARK: - Refresh Data
    func refreshBags() async {
        guard let lat = effectiveLatitude, let lng = effectiveLongitude else { return }
        do {
            bags = try await bagService.getBags(
                latitude: lat,
                longitude: lng,
                maxDistance: filterOptions.maxDistance,
                minPrice: filterOptions.priceRange.lowerBound,
                maxPrice: filterOptions.priceRange.upperBound,
                foodTypes: filterOptions.foodTypes.isEmpty ? nil : Array(filterOptions.foodTypes),
                minRating: filterOptions.minRating
            )
        } catch {
            self.error = error.localizedDescription
        }
    }
}
