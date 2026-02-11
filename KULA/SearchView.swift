//
//  SearchView.swift
//  KULA
//
//  Dedicated Search Screen (Uber Eats inspired)
//

import SwiftUI
import Speech
import AVFoundation

// MARK: - Search Destination
enum SearchDestination: Hashable {
    case categoryResults(String)
    case keywordResults(String)
    case restaurantDetail(String)
}

// MARK: - Search Mode
enum SearchMode: Hashable {
    case category(String)
    case keyword(String)
}

// MARK: - Search View
struct SearchView: View {
    @Binding var showSearch: Bool
    var searchNamespace: Namespace.ID
    @EnvironmentObject var appState: AppState
    @FocusState private var isSearchFocused: Bool
    @StateObject private var speechRecognizer = SpeechRecognizer()

    @State private var searchText: String = ""
    @State private var recentSearches: [String] = UserDefaults.standard.stringArray(forKey: "recentSearches") ?? []

    @State private var keyboardHeight: CGFloat = 0
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppBackgroundGradient()

                VStack(spacing: 0) {
                    // Header
                    header
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.top, DesignSystem.Spacing.md)

                    // Content
                    ScrollView {
                        if searchText.isEmpty {
                            emptyStateContent
                        } else {
                            searchResultsContent
                        }
                    }
                    .scrollDismissesKeyboard(.immediately)
                }

                // Floating Search Bar + Home Button at bottom
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        searchBar
                        homeButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, keyboardHeight > 0 ? keyboardHeight + 12 : 24)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationBarHidden(true)
            .navigationDestination(for: SearchDestination.self) { destination in
                switch destination {
                case .categoryResults(let category):
                    SearchResultsView(
                        title: category,
                        searchMode: .category(category),
                        navigationPath: $navigationPath
                    )
                case .keywordResults(let keyword):
                    SearchResultsView(
                        title: "'\(keyword)'",
                        searchMode: .keyword(keyword),
                        navigationPath: $navigationPath
                    )
                case .restaurantDetail(let restaurantId):
                    if let restaurant = appState.restaurant(for: restaurantId) {
                        RestaurantDetailView(
                            restaurant: restaurant,
                            navigationPath: $navigationPath
                        )
                    }
                }
            }
        }
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
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Text("Search")
                .font(DesignSystem.Typography.largeTitle)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Spacer()
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))

            TextField("Search", text: $searchText)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white)
                .tint(DesignSystem.Colors.accent)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .onSubmit {
                    if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                        saveRecentSearch(searchText)
                        navigationPath.append(SearchDestination.keywordResults(searchText))
                    }
                }

            // Mic / Clear button
            if searchText.isEmpty {
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    if speechRecognizer.isRecording {
                        speechRecognizer.stopRecording()
                    } else {
                        isSearchFocused = false
                        speechRecognizer.requestPermission { authorized in
                            guard authorized else { return }
                            speechRecognizer.startRecording { transcript in
                                searchText = transcript
                            }
                        }
                    }
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(speechRecognizer.isRecording ? DesignSystem.Colors.accent : .white.opacity(0.5))
                        .symbolEffect(.pulse, isActive: speechRecognizer.isRecording)
                }
            } else {
                Button {
                    searchText = ""
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
        let isKeyboardVisible = keyboardHeight > 0

        return Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            if isKeyboardVisible {
                isSearchFocused = false
            } else {
                showSearch = false
            }
        } label: {
            Image(systemName: isKeyboardVisible ? "xmark" : "house")
                .font(.system(size: isKeyboardVisible ? 15 : 17, weight: .semibold))
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
                        .matchedGeometryEffect(id: "searchCircle", in: searchNamespace)
                }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isKeyboardVisible)
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
    }

    // MARK: - Empty State Content
    private var emptyStateContent: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Recent Searches
            if !recentSearches.isEmpty {
                recentSearchesSection
            }

            // Order Again
            orderAgainSection

            // Top Categories
            topCategoriesSection
        }
        .padding(.top, DesignSystem.Spacing.xl)
        .padding(.bottom, 120)
    }

    // MARK: - Recent Searches Section
    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Recent searches")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Spacer()

                Button {
                    withAnimation {
                        recentSearches.removeAll()
                        UserDefaults.standard.set(recentSearches, forKey: "recentSearches")
                    }
                } label: {
                    Text("Clear")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(recentSearches, id: \.self) { search in
                        RecentSearchChip(text: search) {
                            saveRecentSearch(search)
                            navigationPath.append(SearchDestination.keywordResults(search))
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
        }
    }

    // MARK: - Order Again Section
    // Restaurants from past orders
    private var orderAgainRestaurants: [SearchRestaurant] {
        let pastOrderRestaurantIds = Set(appState.pastOrders.map { $0.restaurantId })
        return appState.restaurants
            .filter { pastOrderRestaurantIds.contains($0.id) }
            .prefix(5)
            .map { SearchRestaurant(id: $0.id, name: $0.name, subtitle: $0.address, icon: $0.foodIcon, etaMinutes: Int($0.distanceKm * 5)) }
    }

    private var orderAgainSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Order again")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            if orderAgainRestaurants.isEmpty {
                Text("Complete your first order to see suggestions here")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(orderAgainRestaurants) { restaurant in
                            OrderAgainItem(restaurant: restaurant) {
                                navigationPath.append(SearchDestination.restaurantDetail(restaurant.id))
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }
            }
        }
    }

    // MARK: - Top Categories Section
    private var topCategoriesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Top categories")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            if appState.categories.isEmpty {
                Text("Loading categories...")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
            } else {
                FlowLayout(spacing: DesignSystem.Spacing.sm) {
                    ForEach(appState.categories) { category in
                        CategoryChip(category: SearchCategory(id: category.id, name: category.name, emoji: "")) {
                            navigationPath.append(SearchDestination.categoryResults(category.name))
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
        }
    }

    // MARK: - Search Results Content
    private var searchResultsContent: some View {
        let matchingRecents = recentSearches.filter {
            $0.lowercased().hasPrefix(searchText.lowercased())
        }
        let matchingRestaurants = appState.restaurants.filter {
            $0.name.lowercased().contains(searchText.lowercased())
        }

        let foodTypes = Set(appState.bags.map { $0.foodType })
        let matchingSuggestions = Array(foodTypes).filter {
            $0.lowercased().hasPrefix(searchText.lowercased())
        }

        return VStack(spacing: 0) {
            // A) Recent searches that match
            ForEach(Array(matchingRecents.enumerated()), id: \.element) { index, recent in
                SearchResultRow(
                    icon: "clock",
                    title: recent,
                    subtitle: nil,
                    showRestaurantAvatar: false
                ) {
                    saveRecentSearch(recent)
                    navigationPath.append(SearchDestination.keywordResults(recent))
                }

                searchDivider
            }

            // B) Restaurant matches
            ForEach(Array(matchingRestaurants.enumerated()), id: \.element.id) { index, restaurant in
                SearchResultRow(
                    icon: restaurant.foodIcon,
                    title: restaurant.name,
                    subtitle: restaurant.address,
                    showRestaurantAvatar: true
                ) {
                    isSearchFocused = false
                    navigationPath.append(SearchDestination.restaurantDetail(restaurant.id))
                }

                searchDivider
            }

            // C) Suggestion matches (food type categories)
            ForEach(Array(matchingSuggestions.enumerated()), id: \.element) { index, suggestion in
                SearchResultRow(
                    icon: "magnifyingglass",
                    title: suggestion,
                    subtitle: nil,
                    showRestaurantAvatar: false
                ) {
                    saveRecentSearch(suggestion)
                    navigationPath.append(SearchDestination.categoryResults(suggestion))
                }

                searchDivider
            }

            // D) Final "Search for" row (always shown)
            SearchResultRow(
                icon: "magnifyingglass",
                title: "Search for '\(searchText)'",
                subtitle: nil,
                showRestaurantAvatar: false,
                isAccented: true
            ) {
                saveRecentSearch(searchText)
                navigationPath.append(SearchDestination.keywordResults(searchText))
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.top, DesignSystem.Spacing.lg)
        .padding(.bottom, 120)
    }

    // MARK: - Search Divider
    private var searchDivider: some View {
        Divider()
            .background(DesignSystem.Colors.glassBorder.opacity(0.5))
            .padding(.leading, 56)
    }

    // MARK: - Save Recent Search
    private func saveRecentSearch(_ query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        // Remove if already exists (to move to front)
        recentSearches.removeAll { $0.lowercased() == query.lowercased() }

        // Add to front
        recentSearches.insert(query, at: 0)

        // Keep only last 10
        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
        }

        // Save to UserDefaults
        UserDefaults.standard.set(recentSearches, forKey: "recentSearches")
    }
}

// MARK: - Search Results View
struct SearchResultsView: View {
    let title: String
    let searchMode: SearchMode
    @Binding var navigationPath: NavigationPath
    @EnvironmentObject var appState: AppState
    @State private var selectedBag: Bag?

    private var bags: [Bag] {
        switch searchMode {
        case .category(let name):
            return appState.bagsForCategory(name)
        case .keyword(let keyword):
            return appState.filteredBags(searchText: keyword)
        }
    }

    var body: some View {
        ZStack {
            AppBackgroundGradient()

            if bags.isEmpty {
                // Empty state
                VStack(spacing: DesignSystem.Spacing.lg) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)

                    Text("No bags found")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Text("Try a different search term or category")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, DesignSystem.Spacing.xl)
            } else {
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Text("\(bags.count) result\(bags.count == 1 ? "" : "s")")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DesignSystem.Spacing.lg)

                        LazyVStack(spacing: DesignSystem.Spacing.md) {
                            ForEach(bags) { bag in
                                if let restaurant = appState.restaurant(for: bag.restaurantId) {
                                    BagListingCard(
                                        bag: bag,
                                        restaurant: restaurant,
                                        isSaved: bagBinding(for: bag.id)
                                    ) {
                                        selectedBag = bag
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    }
                    .padding(.top, DesignSystem.Spacing.md)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
        }
        .navigationDestination(item: $selectedBag) { bag in
            if let restaurant = appState.restaurant(for: bag.restaurantId) {
                BagDetailView(bag: bag, restaurant: restaurant)
            }
        }
    }

    private func bagBinding(for bagId: String) -> Binding<Bool> {
        Binding(
            get: { appState.isSaved(bagId: bagId) },
            set: { _ in appState.toggleSaved(bagId: bagId) }
        )
    }
}

// MARK: - Restaurant Detail View
struct RestaurantDetailView: View {
    let restaurant: Restaurant
    @Binding var navigationPath: NavigationPath
    @EnvironmentObject var appState: AppState
    @State private var selectedBag: Bag?

    private var bags: [Bag] {
        appState.bagsForRestaurant(restaurant.id)
    }

    var body: some View {
        ZStack {
            AppBackgroundGradient()

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Restaurant header
                    restaurantHeader

                    // Restaurant info card
                    restaurantInfoCard

                    // Bags section
                    bagsSection
                }
                .padding(.top, DesignSystem.Spacing.md)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(restaurant.name)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
        }
        .navigationDestination(item: $selectedBag) { bag in
            BagDetailView(bag: bag, restaurant: restaurant)
        }
    }

    // MARK: - Restaurant Header
    private var restaurantHeader: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Icon
            ZStack {
                Circle()
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
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(width: 80, height: 80)
            .overlay {
                Circle()
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

            // Name
            Text(restaurant.name)
                .font(DesignSystem.Typography.title2)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            // Rating
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignSystem.Colors.warning)
                Text(String(format: "%.1f", restaurant.rating))
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text("(\(restaurant.ratingCount))")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    // MARK: - Restaurant Info Card
    private var restaurantInfoCard: some View {
        GlassCard(padding: DesignSystem.Spacing.lg, cornerRadius: DesignSystem.CornerRadius.xl) {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Address
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(DesignSystem.Colors.accent)
                    Text(restaurant.address)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    Spacer()
                }

                // Distance
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(DesignSystem.Colors.accent)
                    Text(String(format: "%.1f km away", restaurant.distanceKm))
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    Spacer()
                }

                // Open status
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(restaurant.isOpenNow ? DesignSystem.Colors.success : DesignSystem.Colors.error)
                    if restaurant.isOpenNow {
                        HStack(spacing: 4) {
                            Text("Open now")
                                .font(DesignSystem.Typography.body)
                                .foregroundStyle(DesignSystem.Colors.success)
                            if let closing = restaurant.closingTimeToday {
                                Text("until \(closing)")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                            }
                        }
                    } else {
                        Text("Closed")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.error)
                    }
                    Spacer()
                }

                // Phone (if available)
                if let phone = restaurant.phone {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "phone.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(DesignSystem.Colors.accent)
                        Text(phone)
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        Spacer()
                    }
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    // MARK: - Bags Section
    private var bagsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Available bags")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            if bags.isEmpty {
                VStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "bag")
                        .font(.system(size: 40))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)

                    Text("No bags available")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    Text("Check back later for new surprise bags")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.xxl)
            } else {
                LazyVStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(bags) { bag in
                        BagListingCard(
                            bag: bag,
                            restaurant: restaurant,
                            isSaved: bagBinding(for: bag.id)
                        ) {
                            selectedBag = bag
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
        }
    }

    private func bagBinding(for bagId: String) -> Binding<Bool> {
        Binding(
            get: { appState.isSaved(bagId: bagId) },
            set: { _ in appState.toggleSaved(bagId: bagId) }
        )
    }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    var showRestaurantAvatar: Bool = false
    var isAccented: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Left icon or avatar
                if showRestaurantAvatar {
                    // Restaurant circular avatar
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        DesignSystem.Colors.primaryGreen.opacity(0.5),
                                        DesignSystem.Colors.deepTeal
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .frame(width: 44, height: 44)
                } else {
                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(isAccented ? DesignSystem.Colors.accent : .white.opacity(0.5))
                        .frame(width: 44, height: 44)
                }

                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isAccented ? DesignSystem.Colors.accent : DesignSystem.Colors.textPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(.vertical, subtitle != nil ? 10 : 12)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent Search Chip
struct RecentSearchChip: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))

                Text(text)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .overlay {
                        Capsule()
                            .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Order Again Item
struct OrderAgainItem: View {
    let restaurant: SearchRestaurant
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                // Avatar
                ZStack {
                    Circle()
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

                    Image(systemName: restaurant.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(width: 64, height: 64)
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

                // Name
                Text(restaurant.name)
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                // ETA
                Text("\(restaurant.etaMinutes) min")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .frame(width: 80)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    let category: SearchCategory
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(category.emoji)
                    .font(.system(size: 16))

                Text(category.name)
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .overlay {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.08), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search Mock Data
struct SearchRestaurant: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let icon: String
    let etaMinutes: Int
}

struct SearchCategory: Identifiable {
    let id: String
    let name: String
    let emoji: String
}

// SearchMockData removed - using real API data from AppState

// MARK: - Preview Helper
private struct SearchViewPreviewWrapper: View {
    @State private var showSearch = true
    @Namespace private var previewNamespace

    var body: some View {
        SearchView(showSearch: $showSearch, searchNamespace: previewNamespace)
            .environmentObject(AppState())
    }
}

#Preview {
    SearchViewPreviewWrapper()
}
