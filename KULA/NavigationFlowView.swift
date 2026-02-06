//
//  NavigationFlowView.swift
//  KULA
//
//  Directions Flow: Route Preview + Navigation
//

import SwiftUI
import MapKit
import CoreLocation
import Combine

// MARK: - Navigation Manager
class NavigationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = NavigationManager()

    private let locationManager = CLLocationManager()
    private var currentRoute: MKRoute?
    private var routeSteps: [MKRoute.Step] = []
    private var currentStepIndex: Int = 0

    @Published var userLocation: CLLocation?
    @Published var userHeading: CLLocationDirection = 0
    @Published var isNavigating: Bool = false
    @Published var isCalculatingRoute: Bool = false

    // Route info
    @Published var routeDuration: TimeInterval = 0
    @Published var routeDistance: CLLocationDistance = 0
    @Published var routeDescription: String = ""
    @Published var estimatedArrival: Date?

    // Current guidance
    @Published var currentInstruction: String = ""
    @Published var currentStreetName: String = ""
    @Published var distanceToNextStep: CLLocationDistance = 0
    @Published var nextTurnType: TurnType = .straight

    // Remaining journey
    @Published var remainingTime: TimeInterval = 0
    @Published var remainingDistance: CLLocationDistance = 0

    enum TurnType {
        case straight, slightLeft, slightRight, left, right, sharpLeft, sharpRight, uTurn, destination

        var icon: String {
            switch self {
            case .straight: return "arrow.up"
            case .slightLeft: return "arrow.up.left"
            case .slightRight: return "arrow.up.right"
            case .left: return "arrow.turn.up.left"
            case .right: return "arrow.turn.up.right"
            case .sharpLeft: return "arrow.turn.left.up"
            case .sharpRight: return "arrow.turn.right.up"
            case .uTurn: return "arrow.uturn.down"
            case .destination: return "flag.checkered"
            }
        }
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 5 // Update every 5 meters
        locationManager.activityType = .automotiveNavigation
    }

    // MARK: - Calculate Route
    func calculateRoute(to destination: CLLocationCoordinate2D, completion: @escaping (Bool) -> Void) {
        guard let userLocation = userLocation else {
            // Try to get current location first
            locationManager.requestLocation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.calculateRoute(to: destination, completion: completion)
            }
            return
        }

        isCalculatingRoute = true

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile
        request.requestsAlternateRoutes = true

        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            DispatchQueue.main.async {
                self?.isCalculatingRoute = false

                guard let route = response?.routes.first else {
                    #if DEBUG
                    print("[Navigation] Route calculation failed: \(error?.localizedDescription ?? "Unknown error")")
                    #endif
                    completion(false)
                    return
                }

                self?.currentRoute = route
                self?.routeSteps = route.steps
                self?.currentStepIndex = 0

                // Set route info
                self?.routeDuration = route.expectedTravelTime
                self?.routeDistance = route.distance
                self?.remainingTime = route.expectedTravelTime
                self?.remainingDistance = route.distance
                self?.estimatedArrival = Date().addingTimeInterval(route.expectedTravelTime)

                // Generate route description
                self?.routeDescription = self?.generateRouteDescription(route) ?? ""

                // Set initial guidance
                if let firstStep = route.steps.first(where: { !$0.instructions.isEmpty }) {
                    self?.updateGuidance(for: firstStep)
                }

                #if DEBUG
                print("[Navigation] Route calculated: \(route.distance / 1000) km, \(route.expectedTravelTime / 60) min")
                #endif
                completion(true)
            }
        }
    }

    private func generateRouteDescription(_ route: MKRoute) -> String {
        var majorRoads: [String] = []

        for step in route.steps {
            let instructions = step.instructions

            // Check for US highways and interstates
            if instructions.contains("I-") || instructions.contains("US-") ||
               instructions.contains("CA-") || instructions.contains("Highway") ||
               instructions.contains("Freeway") || instructions.contains("Expressway") ||
               instructions.contains("101") || instructions.contains("280") ||
               instructions.contains("80") {
                // Extract highway number
                let patterns = ["I-80", "I-280", "I-580", "US-101", "CA-1", "101", "280", "80"]
                for pattern in patterns {
                    if instructions.contains(pattern) {
                        let roadName = pattern.hasPrefix("I-") || pattern.hasPrefix("US-") || pattern.hasPrefix("CA-")
                            ? pattern
                            : "Hwy \(pattern)"
                        if !majorRoads.contains(roadName) {
                            majorRoads.append(roadName)
                        }
                        break
                    }
                }
            }

            // Also extract major street names from "onto X St" patterns
            if majorRoads.count < 2 {
                let ontoPatterns = ["onto ", "on "]
                for pattern in ontoPatterns {
                    if let range = instructions.range(of: pattern, options: .caseInsensitive) {
                        let streetPart = String(instructions[range.upperBound...])
                        let streetName = streetPart.components(separatedBy: CharacterSet.alphanumerics.inverted.subtracting(.whitespaces))
                            .prefix(3)
                            .joined(separator: " ")
                            .trimmingCharacters(in: .whitespaces)
                        if streetName.count > 3 && !majorRoads.contains(streetName) {
                            majorRoads.append(streetName)
                        }
                        break
                    }
                }
            }

            if majorRoads.count >= 2 { break }
        }

        if majorRoads.isEmpty {
            // Fallback: use the route name if available
            if !route.name.isEmpty {
                return "Via \(route.name)"
            }
            return "Via local roads"
        }
        return "Via " + majorRoads.prefix(2).joined(separator: " and ")
    }

    // MARK: - Start Navigation
    func startNavigation() {
        isNavigating = true
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        #if DEBUG
        print("[Navigation] Started")
        #endif
    }

    // MARK: - Stop Navigation
    func stopNavigation() {
        isNavigating = false
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        currentRoute = nil
        routeSteps = []
        currentStepIndex = 0
        #if DEBUG
        print("[Navigation] Stopped")
        #endif
    }

    // MARK: - Location Updates
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location

        if isNavigating {
            updateNavigationProgress(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        userHeading = newHeading.trueHeading
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        #if DEBUG
        print("[Navigation] Location error: \(error.localizedDescription)")
        #endif
    }

    // MARK: - Update Navigation Progress
    private func updateNavigationProgress(_ location: CLLocation) {
        guard let route = currentRoute, !routeSteps.isEmpty else { return }

        // Calculate remaining distance from current location to destination
        let destination = routeSteps.last?.polyline.coordinate ?? route.polyline.coordinate
        remainingDistance = location.distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude))

        // Estimate remaining time based on remaining distance and average speed
        let averageSpeed = route.distance / route.expectedTravelTime // meters per second
        remainingTime = remainingDistance / max(averageSpeed, 1)
        estimatedArrival = Date().addingTimeInterval(remainingTime)

        // Find current step based on location
        updateCurrentStep(location)
    }

    private func updateCurrentStep(_ location: CLLocation) {
        guard currentStepIndex < routeSteps.count else { return }

        let currentStep = routeSteps[currentStepIndex]

        // Calculate distance to end of current step
        let stepEndCoord = currentStep.polyline.points()[currentStep.polyline.pointCount - 1].coordinate
        let distanceToStepEnd = location.distance(from: CLLocation(latitude: stepEndCoord.latitude, longitude: stepEndCoord.longitude))

        distanceToNextStep = distanceToStepEnd

        // If we're close to the end of current step, move to next
        if distanceToStepEnd < 30 && currentStepIndex < routeSteps.count - 1 {
            currentStepIndex += 1
            if currentStepIndex < routeSteps.count {
                updateGuidance(for: routeSteps[currentStepIndex])
            }
        }

        // Check if we've arrived
        if currentStepIndex == routeSteps.count - 1 && distanceToStepEnd < 20 {
            nextTurnType = .destination
            currentInstruction = "You have arrived"
            currentStreetName = "Destination"
        }
    }

    private func updateGuidance(for step: MKRoute.Step) {
        currentInstruction = step.instructions
        currentStreetName = extractStreetName(from: step.instructions)
        distanceToNextStep = step.distance
        nextTurnType = determineTurnType(from: step.instructions)
    }

    private func extractStreetName(from instructions: String) -> String {
        // Try to extract the street name from instructions like "Turn right onto Main St"
        let patterns = ["onto ", "on ", "towards ", "to "]
        for pattern in patterns {
            if let range = instructions.range(of: pattern, options: .caseInsensitive) {
                let streetPart = String(instructions[range.upperBound...])
                // Clean up the street name
                return streetPart.components(separatedBy: CharacterSet.alphanumerics.inverted.subtracting(.whitespaces))
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: " ")
                    .prefix(4)
                    .joined(separator: " ")
            }
        }
        // If no pattern found, return a shortened version of instructions
        return String(instructions.prefix(25))
    }

    private func determineTurnType(from instructions: String) -> TurnType {
        let lower = instructions.lowercased()

        if lower.contains("destination") || lower.contains("arrive") {
            return .destination
        } else if lower.contains("sharp left") {
            return .sharpLeft
        } else if lower.contains("sharp right") {
            return .sharpRight
        } else if lower.contains("slight left") || lower.contains("bear left") {
            return .slightLeft
        } else if lower.contains("slight right") || lower.contains("bear right") {
            return .slightRight
        } else if lower.contains("u-turn") || lower.contains("make a u") {
            return .uTurn
        } else if lower.contains("turn left") || lower.contains("left onto") {
            return .left
        } else if lower.contains("turn right") || lower.contains("right onto") {
            return .right
        } else {
            return .straight
        }
    }

    // MARK: - Get Current Route
    func getRoute() -> MKRoute? {
        return currentRoute
    }

    // MARK: - Request Location
    func requestLocation() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        locationManager.requestLocation()
    }
}

// MARK: - Array Extension
extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - MKPolyline Extension
extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

// MARK: - Route Preview Sheet (Step 1)
struct RoutePreviewSheet: View {
    let restaurant: Restaurant
    let destinationCoordinate: CLLocationCoordinate2D

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @ObservedObject private var navigationManager = NavigationManager.shared
    @ObservedObject private var locationManager = LocationManager.shared

    @State private var showNavigation = false
    @State private var isLoadingRoute = true
    @State private var routeError: String?

    init(restaurant: Restaurant) {
        self.restaurant = restaurant
        // Use restaurant coordinates if available
        if let lat = restaurant.latitude, let lng = restaurant.longitude {
            self.destinationCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        } else {
            // Fallback - San Francisco (Ferry Building) for simulator testing
            self.destinationCoordinate = CLLocationCoordinate2D(latitude: 37.7956, longitude: -122.3933)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                AppBackgroundGradient()

                // Map section
                if let userLoc = locationManager.currentLocation {
                    RouteMapView(
                        userCoord: userLoc.coordinate,
                        businessCoord: destinationCoordinate,
                        showAlternateRoute: true,
                        route: navigationManager.getRoute()
                    )
                    .mask {
                        VStack(spacing: 0) {
                            Color.white
                            LinearGradient(
                                colors: [.white, .white.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 100)
                        }
                    }
                    .frame(height: geometry.size.height * 0.78)
                } else {
                    // Loading map placeholder
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .frame(height: geometry.size.height * 0.78)
                        .overlay {
                            ProgressView()
                                .tint(.white)
                        }
                }

                // Top bar
                topBar
                    .padding(.top, geometry.safeAreaInsets.top + DesignSystem.Spacing.xs)

                // Bottom section
                VStack(spacing: DesignSystem.Spacing.md) {
                    if isLoadingRoute {
                        loadingCard
                    } else if let error = routeError {
                        errorCard(error)
                    } else {
                        routeInfoCard
                    }
                    actionButtons
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .frame(height: geometry.size.height * 0.31)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showNavigation) {
            NavigationModeView(restaurant: restaurant, destinationCoordinate: destinationCoordinate)
        }
        .onAppear {
            loadRoute()
        }
    }

    private func loadRoute() {
        isLoadingRoute = true
        routeError = nil

        // Ensure we have user location
        if locationManager.currentLocation == nil {
            locationManager.requestLocation()
        }

        // Calculate route
        navigationManager.calculateRoute(to: destinationCoordinate) { success in
            isLoadingRoute = false
            if !success {
                routeError = "Unable to calculate route"
            }
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    }
                    .overlay {
                        Circle()
                            .fill(Color.black.opacity(0.3))
                    }
            }

            Spacer()

            VStack(spacing: 2) {
                Text("Navigate to")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                Text(restaurant.name)
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            }
            .overlay {
                Capsule()
                    .fill(Color.black.opacity(0.3))
            }

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    // MARK: - Loading Card
    private var loadingCard: some View {
        GlassCard(padding: DesignSystem.Spacing.lg, cornerRadius: DesignSystem.CornerRadius.xl) {
            HStack(spacing: DesignSystem.Spacing.md) {
                ProgressView()
                    .tint(.white)
                Text("Calculating best route...")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Spacer()
            }
        }
    }

    // MARK: - Error Card
    private func errorCard(_ error: String) -> some View {
        GlassCard(padding: DesignSystem.Spacing.md, cornerRadius: DesignSystem.CornerRadius.xl) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Spacer()
                }

                Button {
                    loadRoute()
                } label: {
                    Text("Retry")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
            }
        }
    }

    // MARK: - Route Info Card
    private var routeInfoCard: some View {
        GlassCard(padding: DesignSystem.Spacing.md, cornerRadius: DesignSystem.CornerRadius.xl) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                HStack(alignment: .center) {
                    // Duration
                    HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.xxs) {
                        Text("\(Int(navigationManager.routeDuration / 60))")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Text("min")
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }

                    Spacer()

                    // Distance & route info
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatDistance(navigationManager.routeDistance))
                            .font(DesignSystem.Typography.title3)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        Text(navigationManager.routeDescription)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }

                // Traffic & ETA row
                HStack(spacing: DesignSystem.Spacing.xs) {
                    HStack(spacing: 6) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.Colors.success)
                        Text("Arrive by \(formatTime(navigationManager.estimatedArrival))")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                        Text("Best route")
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(DesignSystem.Colors.accent)
                }
            }
        }
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            SecondaryButton("Leave later", icon: "clock") {
                dismiss()
            }

            PrimaryButton("Go now", icon: "arrow.triangle.turn.up.right.diamond.fill") {
                appState.showDirectionsSheet = true
                showNavigation = true
            }
            .disabled(isLoadingRoute || routeError != nil)
            .opacity(isLoadingRoute || routeError != nil ? 0.5 : 1)
        }
    }

    // MARK: - Helpers
    private func formatDistance(_ meters: CLLocationDistance) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        } else {
            return "\(Int(meters)) m"
        }
    }

    private func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "--:--" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Navigation Mode View (Step 2)
struct NavigationModeView: View {
    let restaurant: Restaurant
    let destinationCoordinate: CLLocationCoordinate2D

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @ObservedObject private var navigationManager = NavigationManager.shared
    @State private var isFollowMode: Bool = true

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Full screen map
                if let userLoc = navigationManager.userLocation {
                    NavigationMapView(
                        userCoord: userLoc.coordinate,
                        businessCoord: destinationCoordinate,
                        userHeading: navigationManager.userHeading,
                        route: navigationManager.getRoute(),
                        isFollowMode: $isFollowMode
                    )
                    .ignoresSafeArea()
                } else {
                    Color.black
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView()
                                .tint(.white)
                        }
                }

                // Gradient overlays
                VStack {
                    LinearGradient(
                        colors: [.black.opacity(0.6), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 200)

                    Spacer()

                    LinearGradient(
                        colors: [.clear, DesignSystem.Colors.gradientBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 300)
                }
                .ignoresSafeArea()

                VStack {
                    // Top guidance banner
                    guidanceBanner
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.top, geometry.safeAreaInsets.top + DesignSystem.Spacing.xs)

                    Spacer()

                    // Recenter button (only shows when not in follow mode)
                    if !isFollowMode {
                        HStack {
                            Spacer()
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isFollowMode = true
                                }
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "location.north.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Recenter")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background {
                                    Capsule()
                                        .fill(DesignSystem.Colors.accent)
                                        .shadow(color: DesignSystem.Colors.accent.opacity(0.4), radius: 8, y: 4)
                                }
                            }
                            .padding(.trailing, DesignSystem.Spacing.md)
                        }
                        .transition(.scale.combined(with: .opacity))
                        .padding(.bottom, DesignSystem.Spacing.md)
                    }

                    // Bottom info panel
                    bottomPanel
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            navigationManager.startNavigation()
        }
        .onDisappear {
            navigationManager.stopNavigation()
            appState.showDirectionsSheet = false
        }
    }

    // MARK: - Guidance Banner
    private var guidanceBanner: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Turn arrow with accent glow
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                    .fill(DesignSystem.Colors.accent)
                    .frame(width: 64, height: 64)

                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                    .fill(DesignSystem.Colors.accent.opacity(0.4))
                    .frame(width: 64, height: 64)
                    .blur(radius: 12)
                    .offset(y: 4)

                Image(systemName: navigationManager.nextTurnType.icon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.black)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.xxs) {
                    Text(formatDistanceShort(navigationManager.distanceToNextStep))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }

                Text(navigationManager.currentStreetName)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Close button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background {
                        GlassBackground(cornerRadius: 18)
                    }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background {
            GlassBackground(cornerRadius: DesignSystem.CornerRadius.xl)
        }
        .applyShadow(DesignSystem.Shadows.medium)
    }

    // MARK: - Bottom Panel
    private var bottomPanel: some View {
        VStack(spacing: 0) {
            // Main info
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text(formatTime(navigationManager.estimatedArrival))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    HStack(spacing: DesignSystem.Spacing.xs) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                            Text("\(Int(navigationManager.remainingTime / 60)) min")
                        }
                        Text("•")
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.swap")
                                .font(.system(size: 12))
                            Text(formatDistance(navigationManager.remainingDistance))
                        }
                    }
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                Spacer()

                // Quick action buttons
                HStack(spacing: DesignSystem.Spacing.sm) {
                    quickActionButton(icon: "speaker.wave.2.fill", label: "Sound")
                    quickActionButton(icon: "magnifyingglass", label: "Search")
                    quickActionButton(icon: "exclamationmark.triangle.fill", label: "Report")
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.md)

            // Destination bar
            HStack(spacing: DesignSystem.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.accent.opacity(0.2))
                        .frame(width: 32, height: 32)
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.accent)
                }

                Text(restaurant.name)
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    dismiss()
                } label: {
                    Text("End")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.Colors.error)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background {
                            Capsule()
                                .fill(DesignSystem.Colors.error.opacity(0.15))
                                .overlay {
                                    Capsule()
                                        .strokeBorder(DesignSystem.Colors.error.opacity(0.3), lineWidth: 1)
                                }
                        }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.glassFill)
        }
        .background {
            GlassBackground(cornerRadius: DesignSystem.CornerRadius.xxl)
        }
        .applyShadow(DesignSystem.Shadows.medium)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.bottom, DesignSystem.Spacing.xxl)
    }

    private func quickActionButton(icon: String, label: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: DesignSystem.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background {
                        GlassBackground(cornerRadius: DesignSystem.CornerRadius.medium)
                    }
                Text(label)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
        }
    }

    // MARK: - Helpers
    private func formatDistance(_ meters: CLLocationDistance) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        } else {
            return "\(Int(meters)) m"
        }
    }

    private func formatDistanceShort(_ meters: CLLocationDistance) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        } else {
            return "\(Int(meters)) m"
        }
    }

    private func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "--:--" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Route Map View (for preview with multiple routes)
struct RouteMapView: UIViewRepresentable {
    let userCoord: CLLocationCoordinate2D
    let businessCoord: CLLocationCoordinate2D
    let showAlternateRoute: Bool
    let route: MKRoute?

    private static let accentColor = UIColor(red: 0.40, green: 0.85, blue: 0.65, alpha: 1.0)

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.overrideUserInterfaceStyle = .dark

        // Set region to fit both points
        let center = CLLocationCoordinate2D(
            latitude: (userCoord.latitude + businessCoord.latitude) / 2,
            longitude: (userCoord.longitude + businessCoord.longitude) / 2
        )

        let latDelta = abs(userCoord.latitude - businessCoord.latitude) * 1.5
        let lonDelta = abs(userCoord.longitude - businessCoord.longitude) * 1.5
        let span = MKCoordinateSpan(
            latitudeDelta: max(latDelta, 0.02),
            longitudeDelta: max(lonDelta, 0.02)
        )
        mapView.setRegion(MKCoordinateRegion(center: center, span: span), animated: false)

        // Add destination annotation
        let businessAnnotation = MKPointAnnotation()
        businessAnnotation.coordinate = businessCoord
        businessAnnotation.title = "Destination"
        mapView.addAnnotation(businessAnnotation)

        // Add route overlay if available (with border effect)
        if let route = route {
            // Add border first (underneath)
            let borderPolyline = MKPolyline(coordinates: route.polyline.coordinates, count: route.polyline.pointCount)
            borderPolyline.title = "routeBorder"
            mapView.addOverlay(borderPolyline, level: .aboveRoads)

            // Add main line on top
            let mainPolyline = MKPolyline(coordinates: route.polyline.coordinates, count: route.polyline.pointCount)
            mainPolyline.title = "routeMain"
            mapView.addOverlay(mainPolyline, level: .aboveRoads)
        }

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Update route if changed
        if let route = route {
            // Remove old overlays
            uiView.removeOverlays(uiView.overlays)

            // Add border first (underneath)
            let borderPolyline = MKPolyline(coordinates: route.polyline.coordinates, count: route.polyline.pointCount)
            borderPolyline.title = "routeBorder"
            uiView.addOverlay(borderPolyline, level: .aboveRoads)

            // Add main line on top
            let mainPolyline = MKPolyline(coordinates: route.polyline.coordinates, count: route.polyline.pointCount)
            mainPolyline.title = "routeMain"
            uiView.addOverlay(mainPolyline, level: .aboveRoads)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                if polyline.title == "routeBorder" {
                    // Border/outline - darker and wider
                    renderer.strokeColor = UIColor.black.withAlphaComponent(0.6)
                    renderer.lineWidth = 12
                    renderer.lineCap = .round
                    renderer.lineJoin = .round
                } else if polyline.title == "routeMain" {
                    // Main route line
                    renderer.strokeColor = RouteMapView.accentColor
                    renderer.lineWidth = 8
                    renderer.lineCap = .round
                    renderer.lineJoin = .round
                } else {
                    // Default
                    renderer.strokeColor = RouteMapView.accentColor
                    renderer.lineWidth = 6
                    renderer.lineCap = .round
                    renderer.lineJoin = .round
                }
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            let identifier = "destination"
            var markerView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            if markerView == nil {
                markerView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            }
            markerView?.annotation = annotation
            markerView?.markerTintColor = RouteMapView.accentColor
            markerView?.glyphImage = UIImage(systemName: "flag.checkered")
            return markerView
        }
    }
}

// MARK: - Navigation Map View (for active navigation)
struct NavigationMapView: UIViewRepresentable {
    let userCoord: CLLocationCoordinate2D
    let businessCoord: CLLocationCoordinate2D
    let userHeading: CLLocationDirection
    let route: MKRoute?
    @Binding var isFollowMode: Bool

    private static let accentColor = UIColor(red: 0.40, green: 0.85, blue: 0.65, alpha: 1.0)

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        context.coordinator.parent = self

        // Disable default user location (we'll use custom marker)
        mapView.showsUserLocation = false
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
        mapView.mapType = .standard
        mapView.overrideUserInterfaceStyle = .dark

        // Add pan gesture recognizer to detect user interaction
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapPan(_:)))
        panGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(panGesture)

        // Add pinch gesture recognizer
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapPinch(_:)))
        pinchGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(pinchGesture)

        // Add user marker (triangle/arrow)
        let userAnnotation = MKPointAnnotation()
        userAnnotation.coordinate = userCoord
        userAnnotation.title = "UserLocation"
        mapView.addAnnotation(userAnnotation)
        context.coordinator.userAnnotation = userAnnotation

        // Add destination
        let destAnnotation = MKPointAnnotation()
        destAnnotation.coordinate = businessCoord
        destAnnotation.title = "Destination"
        mapView.addAnnotation(destAnnotation)

        // Add route overlay with border effect (add border first, then main line on top)
        if let route = route {
            // Create border polyline (wider, darker)
            let borderPolyline = MKPolyline(coordinates: route.polyline.coordinates, count: route.polyline.pointCount)
            borderPolyline.title = "routeBorder"
            mapView.addOverlay(borderPolyline, level: .aboveRoads)

            // Create main route polyline
            let mainPolyline = MKPolyline(coordinates: route.polyline.coordinates, count: route.polyline.pointCount)
            mainPolyline.title = "routeMain"
            mapView.addOverlay(mainPolyline, level: .aboveRoads)
        }

        // Set initial camera - position user at lower-center
        setCameraForNavigation(mapView: mapView, animated: false)

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Update user annotation position
        if let userAnnotation = context.coordinator.userAnnotation {
            UIView.animate(withDuration: 0.3) {
                userAnnotation.coordinate = userCoord
            }
        }

        // Update user marker rotation
        if let userAnnotation = context.coordinator.userAnnotation,
           let annotationView = uiView.view(for: userAnnotation) {
            UIView.animate(withDuration: 0.3) {
                annotationView.transform = CGAffineTransform(rotationAngle: CGFloat(userHeading) * .pi / 180)
            }
        }

        // Update camera only if in follow mode
        if isFollowMode {
            setCameraForNavigation(mapView: uiView, animated: true)
        }
    }

    private func setCameraForNavigation(mapView: MKMapView, animated: Bool) {
        // Calculate a point slightly ahead of user in the direction of travel
        let offsetDistance: CLLocationDistance = 150 // meters ahead
        let headingRadians = userHeading * .pi / 180
        let latOffset = offsetDistance / 111320 * cos(headingRadians)
        let lngOffset = offsetDistance / (111320 * cos(userCoord.latitude * .pi / 180)) * sin(headingRadians)

        let lookAtCenter = CLLocationCoordinate2D(
            latitude: userCoord.latitude + latOffset,
            longitude: userCoord.longitude + lngOffset
        )

        // Camera looks at point ahead, positioned behind user
        let camera = MKMapCamera(
            lookingAtCenter: lookAtCenter,
            fromDistance: 600,
            pitch: 65,
            heading: userHeading
        )

        if animated {
            UIView.animate(withDuration: 0.5, delay: 0, options: [.curveEaseOut]) {
                mapView.setCamera(camera, animated: false)
            }
        } else {
            mapView.setCamera(camera, animated: false)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: NavigationMapView?
        var userAnnotation: MKPointAnnotation?

        @objc func handleMapPan(_ gesture: UIPanGestureRecognizer) {
            if gesture.state == .began || gesture.state == .changed {
                parent?.isFollowMode = false
            }
        }

        @objc func handleMapPinch(_ gesture: UIPinchGestureRecognizer) {
            if gesture.state == .began || gesture.state == .changed {
                parent?.isFollowMode = false
            }
        }

        // Allow multiple gesture recognizers
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                if polyline.title == "routeBorder" {
                    // Border/outline layer - darker and wider for 3D effect
                    renderer.strokeColor = UIColor.black.withAlphaComponent(0.7)
                    renderer.lineWidth = 18
                    renderer.lineCap = .round
                    renderer.lineJoin = .round
                } else if polyline.title == "routeMain" {
                    // Main route line - accent color with glow
                    renderer.strokeColor = NavigationMapView.accentColor
                    renderer.lineWidth = 12
                    renderer.lineCap = .round
                    renderer.lineJoin = .round
                } else {
                    // Default styling
                    renderer.strokeColor = NavigationMapView.accentColor
                    renderer.lineWidth = 10
                    renderer.lineCap = .round
                    renderer.lineJoin = .round
                }
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            // User location - triangular arrow marker
            if annotation.title == "UserLocation" {
                let identifier = "userArrow"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                }
                view?.annotation = annotation

                // Create triangular arrow image
                let size: CGFloat = 48
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
                let image = renderer.image { ctx in
                    let context = ctx.cgContext

                    // Draw outer glow
                    context.saveGState()
                    context.setShadow(offset: CGSize(width: 0, height: 2), blur: 8, color: NavigationMapView.accentColor.withAlphaComponent(0.6).cgColor)

                    // Draw triangle pointing up
                    let path = UIBezierPath()
                    path.move(to: CGPoint(x: size / 2, y: 4))  // Top point
                    path.addLine(to: CGPoint(x: size - 8, y: size - 8))  // Bottom right
                    path.addLine(to: CGPoint(x: size / 2, y: size - 16))  // Bottom center indent
                    path.addLine(to: CGPoint(x: 8, y: size - 8))  // Bottom left
                    path.close()

                    NavigationMapView.accentColor.setFill()
                    path.fill()

                    context.restoreGState()

                    // Draw white border
                    UIColor.white.setStroke()
                    path.lineWidth = 2
                    path.stroke()

                    // Draw inner highlight
                    let innerPath = UIBezierPath()
                    innerPath.move(to: CGPoint(x: size / 2, y: 10))
                    innerPath.addLine(to: CGPoint(x: size / 2 + 6, y: size - 18))
                    innerPath.addLine(to: CGPoint(x: size / 2, y: size - 20))
                    innerPath.close()

                    UIColor.white.withAlphaComponent(0.4).setFill()
                    innerPath.fill()
                }

                view?.image = image
                view?.centerOffset = CGPoint(x: 0, y: 0)
                view?.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)

                return view
            }

            // Destination marker
            let identifier = "destination"
            var markerView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            if markerView == nil {
                markerView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            }
            markerView?.annotation = annotation
            markerView?.markerTintColor = NavigationMapView.accentColor
            markerView?.glyphImage = UIImage(systemName: "flag.checkered")
            return markerView
        }
    }
}

#Preview("Route Preview") {
    RoutePreviewSheet(restaurant: PreviewData.sampleRestaurant)
        .environmentObject(AppState())
}

#Preview("Navigation Mode") {
    NavigationModeView(
        restaurant: PreviewData.sampleRestaurant,
        destinationCoordinate: CLLocationCoordinate2D(latitude: 37.7956, longitude: -122.3933)
    )
    .environmentObject(AppState())
}

// MARK: - Preview Helper for Navigation Map
struct NavigationMapPreviewWrapper: View {
    @State private var isFollowMode = true

    var body: some View {
        NavigationMapView(
            userCoord: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            businessCoord: CLLocationCoordinate2D(latitude: 37.7956, longitude: -122.3933),
            userHeading: 45,
            route: nil,
            isFollowMode: $isFollowMode
        )
    }
}
