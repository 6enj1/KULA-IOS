//
//  DirectionsSheetView.swift
//  KULA
//
//  Directions & Business Info Modal
//

import SwiftUI
import MapKit

struct DirectionsSheetView: View {
    let restaurant: Restaurant
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager.shared
    @State private var showCopiedToast = false
    @State private var resolvedAddress: String?

    private var userCoord: CLLocationCoordinate2D {
        locationManager.currentLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }

    private var businessCoord: CLLocationCoordinate2D {
        if let lat = restaurant.latitude, let lng = restaurant.longitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        return CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }

    private var hasValidCoordinates: Bool {
        userCoord.latitude != 0 && userCoord.longitude != 0 &&
        businessCoord.latitude != 0 && businessCoord.longitude != 0
    }

    /// Address derived from coordinates (falls back to stored address while loading)
    private var displayAddress: String {
        resolvedAddress ?? restaurant.address
    }

    var body: some View {
        ZStack {
            // Background
            AppBackgroundGradient()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .background {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .environment(\.colorScheme, .dark)
                            }
                    }

                    Spacer()

                    Text("Directions")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Spacer()

                    // Invisible spacer for centering
                    Color.clear
                        .frame(width: 32, height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        // Map Preview
                        mapSection

                        // Business Info Card
                        businessInfoCard

                        // Info Rows Card
                        infoRowsCard

                        // Open in Maps Button
                        openInMapsButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }

            // Copied Toast
            if showCopiedToast {
                VStack {
                    Spacer()
                    Text("Address copied")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background {
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                        }
                        .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            reverseGeocodeBusinessLocation()
        }
    }

    // MARK: - Reverse Geocode
    private func reverseGeocodeBusinessLocation() {
        let coord = businessCoord
        guard coord.latitude != 0 && coord.longitude != 0 else { return }

        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            guard let placemark = placemarks?.first else { return }
            let parts = [
                placemark.subThoroughfare,
                placemark.thoroughfare,
                placemark.locality
            ].compactMap { $0 }
            if !parts.isEmpty {
                resolvedAddress = parts.joined(separator: " ")
            }
        }
    }

    // MARK: - Map Section
    private var mapSection: some View {
        ZStack(alignment: .topTrailing) {
            AnimatedRouteMapView(
                userCoord: userCoord,
                businessCoord: businessCoord,
                businessName: restaurant.name
            )
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            }

            // Distance Badge
            HStack(spacing: 4) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 12))
                Text(String(format: "%.1f km", restaurant.distanceKm))
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            }
            .padding(12)
        }
    }

    // MARK: - Business Info Card
    private var businessInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(restaurant.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Text(restaurantCategories)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        }
    }

    // MARK: - Info Rows Card
    private var infoRowsCard: some View {
        VStack(spacing: 0) {
            // Location Row
            infoRow(
                icon: "mappin.circle.fill",
                iconColor: .red,
                title: displayAddress,
                subtitle: nil
            ) {
                Button {
                    UIPasteboard.general.string = displayAddress
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showCopiedToast = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showCopiedToast = false
                        }
                    }
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            // Opening Hours Row (only show if we have hours data)
            if !restaurant.openingHours.isEmpty {
                rowDivider

                infoRow(
                    icon: "clock.fill",
                    iconColor: restaurant.isOpenNow ? .green : .red,
                    title: openingHoursTitle,
                    subtitle: nil
                ) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }

            rowDivider

            // Rating Row
            infoRow(
                icon: "star.fill",
                iconColor: .orange,
                title: "\(String(format: "%.1f", restaurant.rating)) (\(restaurant.ratingCount) ratings)",
                subtitle: nil
            ) {
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Reorder Stats Row (only show if we have orders)
            if restaurant.totalOrders > 0 {
                rowDivider

                infoRow(
                    icon: "person.2.fill",
                    iconColor: .blue,
                    title: reorderStatsTitle,
                    subtitle: nil
                ) {
                    EmptyView()
                }
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        }
    }

    private var openingHoursTitle: String {
        if restaurant.isOpenNow {
            if let closingTime = restaurant.closingTimeToday {
                return "Open until \(closingTime)"
            }
            return "Open now"
        } else {
            return "Closed"
        }
    }

    private var reorderStatsTitle: String {
        let count = restaurant.totalOrders
        if count >= 1000 {
            let thousands = Double(count) / 1000.0
            return String(format: "%.0fk+ people ordered", thousands)
        } else if count > 0 {
            return "\(count)+ people ordered"
        }
        return ""
    }

    // MARK: - Row Divider
    private var rowDivider: some View {
        Divider()
            .background(.white.opacity(0.1))
            .padding(.leading, 52)
    }

    // MARK: - Info Row Builder
    @ViewBuilder
    private func infoRow<Trailing: View>(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String?,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()

            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Open in Maps Button
    private var openInMapsButton: some View {
        Button {
            openInMaps()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("Open in Maps")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                Capsule()
                    .fill(DesignSystem.Colors.accent)
                    .shadow(color: DesignSystem.Colors.accent.opacity(0.4), radius: 12, y: 4)
            }
        }
    }

    // MARK: - Helpers
    private var restaurantCategories: String {
        // Display the food icon category name if available
        restaurant.foodIcon.isEmpty ? "Restaurant" : "Food & Drinks"
    }

    private func openInMaps() {
        let coordinate = businessCoord
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = restaurant.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }

}

// MARK: - Animated Route Map View (MKMapView wrapper)
struct AnimatedRouteMapView: UIViewRepresentable {
    let userCoord: CLLocationCoordinate2D
    let businessCoord: CLLocationCoordinate2D
    let businessName: String

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsUserLocation = false

        // Add annotations
        let userAnnotation = MKPointAnnotation()
        userAnnotation.coordinate = userCoord
        userAnnotation.title = "You"
        mapView.addAnnotation(userAnnotation)

        let businessAnnotation = MKPointAnnotation()
        businessAnnotation.coordinate = businessCoord
        businessAnnotation.title = businessName
        mapView.addAnnotation(businessAnnotation)

        // Add polyline overlay
        let polyline = MKPolyline(coordinates: [userCoord, businessCoord], count: 2)
        mapView.addOverlay(polyline)

        // Fit camera to show both pins with padding
        let points = [userCoord, businessCoord].map { MKMapPoint($0) }
        var mapRect = MKMapRect.null
        for point in points {
            mapRect = mapRect.union(MKMapRect(origin: point, size: MKMapSize(width: 1, height: 1)))
        }
        let padding = UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40)
        mapView.setVisibleMapRect(mapRect, edgePadding: padding, animated: false)

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        private var displayLink: CADisplayLink?
        private var animatedRenderer: AnimatedPolylineRenderer?

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = AnimatedPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(DesignSystem.Colors.accent)
                renderer.lineWidth = 3
                renderer.lineCap = .round
                renderer.lineJoin = .round
                animatedRenderer = renderer
                startAnimation()
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = annotation.title == "You" ? "user" : "business"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                view?.annotation = annotation
            }

            if annotation.title == "You" {
                view?.markerTintColor = .systemBlue
                view?.glyphImage = UIImage(systemName: "figure.stand")
            } else {
                view?.markerTintColor = UIColor(DesignSystem.Colors.accent)
                view?.glyphImage = UIImage(systemName: "bag.fill")
            }

            return view
        }

        private func startAnimation() {
            displayLink = CADisplayLink(target: self, selector: #selector(updateAnimation))
            displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            displayLink?.add(to: .main, forMode: .common)
        }

        @objc private func updateAnimation() {
            animatedRenderer?.updateDashPhase()
        }

        deinit {
            displayLink?.invalidate()
        }
    }
}

// MARK: - Animated Polyline Renderer
class AnimatedPolylineRenderer: MKPolylineRenderer {
    private var progress: CGFloat = 0 // 0 to 1
    private let animationSpeed: CGFloat = 0.003 // Very slow, smooth
    private let pulseLength: CGFloat = 0.15 // Length of the bright segment (15% of line)

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let path = self.path else { return }

        let adjustedLineWidth = lineWidth / zoomScale

        // Draw base line (subtle, solid)
        context.setStrokeColor(strokeColor?.withAlphaComponent(0.25).cgColor ?? UIColor.gray.cgColor)
        context.setLineWidth(adjustedLineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.addPath(path)
        context.strokePath()

        // Draw traveling glow pulse
        let pulseStart = max(0, progress - pulseLength)
        let pulseEnd = min(1, progress)

        // Create a bezier path for point calculations
        let bezierPath = UIBezierPath(cgPath: path)

        // Draw gradient pulse segment
        context.saveGState()

            // Clip to path area
            context.addPath(path)
            context.setLineWidth(adjustedLineWidth * 2.5)
            context.replacePathWithStrokedPath()
            context.clip()

            // Get start and end points for gradient
            let startPoint = bezierPath.point(at: pulseStart) ?? .zero
            let endPoint = bezierPath.point(at: pulseEnd) ?? .zero

            // Create gradient
            let colors = [
                strokeColor?.withAlphaComponent(0.0).cgColor ?? UIColor.clear.cgColor,
                strokeColor?.withAlphaComponent(0.9).cgColor ?? UIColor.white.cgColor,
                strokeColor?.withAlphaComponent(0.9).cgColor ?? UIColor.white.cgColor,
                strokeColor?.withAlphaComponent(0.0).cgColor ?? UIColor.clear.cgColor
            ] as CFArray
            let locations: [CGFloat] = [0, 0.3, 0.7, 1.0]

            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
                // Extend gradient beyond the pulse for smooth fade
                let dx = endPoint.x - startPoint.x
                let dy = endPoint.y - startPoint.y
                let extendedStart = CGPoint(x: startPoint.x - dx * 0.3, y: startPoint.y - dy * 0.3)
                let extendedEnd = CGPoint(x: endPoint.x + dx * 0.3, y: endPoint.y + dy * 0.3)

                context.drawLinearGradient(gradient, start: extendedStart, end: extendedEnd, options: [])
            }

        context.restoreGState()

        // Draw bright core of pulse
        let coreStart = max(0, progress - pulseLength * 0.4)
        let coreEnd = min(1, progress - pulseLength * 0.1)

        if coreEnd > coreStart {
            let coreStartPoint = bezierPath.point(at: coreStart) ?? .zero
            let coreEndPoint = bezierPath.point(at: coreEnd) ?? .zero

            context.setStrokeColor(strokeColor?.withAlphaComponent(1.0).cgColor ?? UIColor.white.cgColor)
            context.setLineWidth(adjustedLineWidth * 0.8)
            context.setLineCap(.round)
            context.move(to: coreStartPoint)
            context.addLine(to: coreEndPoint)
            context.strokePath()
        }
    }

    func updateDashPhase() {
        progress += animationSpeed

        if progress > 1 + pulseLength {
            progress = -pulseLength // Reset with lead-in
        }

        setNeedsDisplay()
    }
}

// MARK: - UIBezierPath Extensions for Point Along Path
extension UIBezierPath {
    var length: CGFloat {
        var length: CGFloat = 0
        var previousPoint: CGPoint = .zero

        cgPath.applyWithBlock { element in
            let points = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                previousPoint = points[0]
            case .addLineToPoint:
                length += hypot(points[0].x - previousPoint.x, points[0].y - previousPoint.y)
                previousPoint = points[0]
            case .addQuadCurveToPoint:
                length += hypot(points[1].x - previousPoint.x, points[1].y - previousPoint.y)
                previousPoint = points[1]
            case .addCurveToPoint:
                length += hypot(points[2].x - previousPoint.x, points[2].y - previousPoint.y)
                previousPoint = points[2]
            case .closeSubpath:
                break
            @unknown default:
                break
            }
        }
        return length
    }

    func point(at fraction: CGFloat) -> CGPoint? {
        let targetLength = length * max(0, min(1, fraction))
        var currentLength: CGFloat = 0
        var previousPoint: CGPoint = .zero
        var resultPoint: CGPoint?

        cgPath.applyWithBlock { element in
            guard resultPoint == nil else { return }

            let points = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                previousPoint = points[0]
            case .addLineToPoint:
                let segmentLength = hypot(points[0].x - previousPoint.x, points[0].y - previousPoint.y)
                if currentLength + segmentLength >= targetLength {
                    let remainder = targetLength - currentLength
                    let ratio = segmentLength > 0 ? remainder / segmentLength : 0
                    resultPoint = CGPoint(
                        x: previousPoint.x + (points[0].x - previousPoint.x) * ratio,
                        y: previousPoint.y + (points[0].y - previousPoint.y) * ratio
                    )
                }
                currentLength += segmentLength
                previousPoint = points[0]
            case .addQuadCurveToPoint, .addCurveToPoint:
                let endPoint = element.pointee.type == .addQuadCurveToPoint ? points[1] : points[2]
                let segmentLength = hypot(endPoint.x - previousPoint.x, endPoint.y - previousPoint.y)
                if currentLength + segmentLength >= targetLength {
                    let remainder = targetLength - currentLength
                    let ratio = segmentLength > 0 ? remainder / segmentLength : 0
                    resultPoint = CGPoint(
                        x: previousPoint.x + (endPoint.x - previousPoint.x) * ratio,
                        y: previousPoint.y + (endPoint.y - previousPoint.y) * ratio
                    )
                }
                currentLength += segmentLength
                previousPoint = endPoint
            case .closeSubpath:
                break
            @unknown default:
                break
            }
        }

        return resultPoint ?? previousPoint
    }
}

#Preview {
    DirectionsSheetView(restaurant: PreviewData.sampleRestaurant)
}
