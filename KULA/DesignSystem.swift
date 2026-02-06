//
//  DesignSystem.swift
//  KULA
//
//  Design System: Colors, Spacing, Typography, and Styles
//

import SwiftUI

// MARK: - Design System
enum DesignSystem {

    // MARK: - Layout (iPad Adaptive - Full Screen Scaling)
    enum Layout {
        /// Scale factor for iPad (1.0 on iPhone, 1.15-1.25 on iPad)
        static func scale(isRegular: Bool) -> CGFloat {
            isRegular ? 1.2 : 1.0
        }

        /// Horizontal padding - larger on iPad
        static func horizontalPadding(isRegular: Bool) -> CGFloat {
            isRegular ? 32 : Spacing.lg
        }

        /// Vertical spacing between sections - larger on iPad
        static func sectionSpacing(isRegular: Bool) -> CGFloat {
            isRegular ? 32 : Spacing.lg
        }

        /// Card corner radius - larger on iPad
        static func cardCornerRadius(isRegular: Bool) -> CGFloat {
            isRegular ? 24 : CornerRadius.large
        }

        /// Card internal padding - larger on iPad
        static func cardPadding(isRegular: Bool) -> CGFloat {
            isRegular ? 20 : Spacing.md
        }

        /// Grid columns for bag listings
        static func gridColumns(isRegular: Bool, screenWidth: CGFloat) -> Int {
            if !isRegular { return 1 }
            if screenWidth > 1100 { return 3 }
            return 2
        }

        /// Minimum card width for grid
        static func minCardWidth(isRegular: Bool) -> CGFloat {
            isRegular ? 340 : 300
        }

        /// Carousel card width - larger on iPad
        static func carouselCardWidth(isRegular: Bool) -> CGFloat {
            isRegular ? 200 : 140
        }

        /// Carousel card image height
        static func carouselImageHeight(isRegular: Bool) -> CGFloat {
            isRegular ? 140 : 100
        }

        /// Listing card image height
        static func listingImageHeight(isRegular: Bool) -> CGFloat {
            isRegular ? 180 : 140
        }

        /// Bottom padding for tab bar
        static func tabBarBottomPadding(isRegular: Bool) -> CGFloat {
            isRegular ? 48 : 24
        }

        /// Tab bar icon size
        static func tabBarIconSize(isRegular: Bool) -> CGFloat {
            isRegular ? 22 : 17
        }

        /// Tab bar item padding
        static func tabBarItemPadding(isRegular: Bool) -> CGFloat {
            isRegular ? 16 : 12
        }

        /// Button height - larger on iPad
        static func buttonHeight(isRegular: Bool) -> CGFloat {
            isRegular ? 64 : 56
        }

        /// Sheet detents
        static func sheetDetents(isRegular: Bool) -> Set<PresentationDetent> {
            isRegular ? [.medium, .large] : [.large]
        }
    }

    // MARK: - Scaled Typography for iPad
    enum ScaledTypography {
        static func largeTitle(isRegular: Bool) -> Font {
            .system(size: isRegular ? 40 : 34, weight: .bold, design: .rounded)
        }
        static func title1(isRegular: Bool) -> Font {
            .system(size: isRegular ? 34 : 28, weight: .bold, design: .rounded)
        }
        static func title2(isRegular: Bool) -> Font {
            .system(size: isRegular ? 28 : 22, weight: .semibold, design: .rounded)
        }
        static func title3(isRegular: Bool) -> Font {
            .system(size: isRegular ? 24 : 20, weight: .semibold, design: .rounded)
        }
        static func headline(isRegular: Bool) -> Font {
            .system(size: isRegular ? 20 : 17, weight: .semibold)
        }
        static func body(isRegular: Bool) -> Font {
            .system(size: isRegular ? 19 : 17, weight: .regular)
        }
        static func subheadline(isRegular: Bool) -> Font {
            .system(size: isRegular ? 17 : 15, weight: .regular)
        }
        static func caption(isRegular: Bool) -> Font {
            .system(size: isRegular ? 14 : 12, weight: .regular)
        }
        static func price(isRegular: Bool) -> Font {
            .system(size: isRegular ? 28 : 22, weight: .bold, design: .rounded)
        }
    }

    // MARK: - Colors
    enum Colors {
        // Primary palette
        static let primaryGreen = Color(red: 0.16, green: 0.49, blue: 0.42)
        static let deepTeal = Color(red: 0.08, green: 0.28, blue: 0.30)
        static let warmAmber = Color(red: 0.95, green: 0.65, blue: 0.25)
        static let accent = Color(red: 0.40, green: 0.85, blue: 0.65)

        // Background gradient colors
        static let gradientTop = Color(red: 0.04, green: 0.12, blue: 0.14)
        static let gradientMiddle = Color(red: 0.06, green: 0.18, blue: 0.20)
        static let gradientBottom = Color(red: 0.08, green: 0.10, blue: 0.12)
        static let gradientAccent = Color(red: 0.25, green: 0.18, blue: 0.10).opacity(0.4)

        // Glass effects
        static let glassFill = Color.white.opacity(0.08)
        static let glassBorder = Color.white.opacity(0.15)
        static let glassHighlight = Color.white.opacity(0.25)

        // Text colors
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.7)
        static let textTertiary = Color.white.opacity(0.5)

        // Status colors
        static let success = Color(red: 0.30, green: 0.80, blue: 0.50)
        static let warning = Color(red: 0.95, green: 0.70, blue: 0.25)
        static let error = Color(red: 0.95, green: 0.35, blue: 0.35)

        // Semantic colors
        static let sellingFast = Color(red: 1.0, green: 0.45, blue: 0.35)
        static let saved = Color(red: 0.95, green: 0.35, blue: 0.45)
    }

    // MARK: - Spacing
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: - Corner Radius
    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let pill: CGFloat = 100
    }

    // MARK: - Shadows
    enum Shadows {
        static let soft = Shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        static let medium = Shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
        static let glow = Shadow(color: Colors.accent.opacity(0.3), radius: 16, x: 0, y: 0)
    }

    // MARK: - Typography
    enum Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title1 = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 17, weight: .regular)
        static let callout = Font.system(size: 16, weight: .regular)
        static let subheadline = Font.system(size: 15, weight: .regular)
        static let footnote = Font.system(size: 13, weight: .regular)
        static let caption = Font.system(size: 12, weight: .regular)
        static let caption2 = Font.system(size: 11, weight: .regular)

        // Special styles
        static let price = Font.system(size: 22, weight: .bold, design: .rounded)
        static let priceStrike = Font.system(size: 14, weight: .medium)
    }

    // MARK: - Blur Intensities
    enum BlurIntensity {
        case light
        case medium
        case heavy

        var radius: CGFloat {
            switch self {
            case .light: return 10
            case .medium: return 20
            case .heavy: return 40
            }
        }
    }

    // MARK: - Animation
    enum Animation {
        static let quick = SwiftUI.Animation.easeOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let smooth = SwiftUI.Animation.smooth(duration: 0.4)
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.75)
        static let bouncy = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.6)
    }
}

// MARK: - Shadow Struct
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extensions for Design System
extension View {
    func applyShadow(_ shadow: Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

// MARK: - App Background Gradient
struct AppBackgroundGradient: View {
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    DesignSystem.Colors.gradientTop,
                    DesignSystem.Colors.gradientMiddle,
                    DesignSystem.Colors.gradientBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Warm accent overlay
            RadialGradient(
                colors: [
                    DesignSystem.Colors.gradientAccent,
                    .clear
                ],
                center: .topTrailing,
                startRadius: 50,
                endRadius: 400
            )

            // Subtle teal accent
            RadialGradient(
                colors: [
                    DesignSystem.Colors.primaryGreen.opacity(0.15),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 100,
                endRadius: 500
            )

            // Noise texture overlay for premium feel
            NoiseTexture()
                .opacity(0.03)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Noise Texture
struct NoiseTexture: View {
    var body: some View {
        Canvas { context, size in
            for _ in 0..<Int(size.width * size.height * 0.02) {
                let x = CGFloat.random(in: 0..<size.width)
                let y = CGFloat.random(in: 0..<size.height)
                let opacity = Double.random(in: 0.3...1.0)

                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                    with: .color(.white.opacity(opacity))
                )
            }
        }
    }
}

// MARK: - Glass Background
struct GlassBackground: View {
    var intensity: DesignSystem.BlurIntensity = .medium
    var cornerRadius: CGFloat = 0

    var body: some View {
        ZStack {
            // Blur effect
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.8)

            // Glass fill
            Rectangle()
                .fill(DesignSystem.Colors.glassFill)

            // Top highlight rim
            VStack {
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.glassHighlight,
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 1)

                Spacer()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.glassBorder,
                            DesignSystem.Colors.glassBorder.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
}

// MARK: - Adaptive Grid (Full-Width, Multi-Column on iPad)
struct AdaptiveGrid<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let data: Data
    let spacing: CGFloat
    let content: (Data.Element, Bool) -> Content

    init(_ data: Data, spacing: CGFloat = DesignSystem.Spacing.md, @ViewBuilder content: @escaping (Data.Element, Bool) -> Content) {
        self.data = data
        self.spacing = spacing
        self.content = content
    }

    private var isRegular: Bool {
        horizontalSizeClass == .regular
    }

    private var columns: [GridItem] {
        let minWidth = DesignSystem.Layout.minCardWidth(isRegular: isRegular)
        let gridSpacing = isRegular ? DesignSystem.Spacing.lg : spacing
        return [GridItem(.adaptive(minimum: minWidth), spacing: gridSpacing)]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: isRegular ? DesignSystem.Spacing.lg : spacing) {
            ForEach(data) { item in
                content(item, isRegular)
            }
        }
    }
}

// MARK: - View Extension for iPad Adaptive Layouts
extension View {
    /// Applies iPad-scaled horizontal padding (larger on iPad)
    func adaptivePadding() -> some View {
        modifier(AdaptivePaddingModifier())
    }

    /// Applies iPad-scaled vertical spacing
    func adaptiveSpacing() -> some View {
        modifier(AdaptiveSpacingModifier())
    }
}

// MARK: - Adaptive Padding Modifier
struct AdaptivePaddingModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegular: Bool {
        horizontalSizeClass == .regular
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, DesignSystem.Layout.horizontalPadding(isRegular: isRegular))
    }
}

// MARK: - Adaptive Spacing Modifier
struct AdaptiveSpacingModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegular: Bool {
        horizontalSizeClass == .regular
    }

    func body(content: Content) -> some View {
        content
            .padding(.vertical, isRegular ? DesignSystem.Spacing.sm : 0)
    }
}

// MARK: - Conditional View Modifier
extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#Preview("Design System") {
    ZStack {
        AppBackgroundGradient()

        VStack(spacing: 20) {
            Text("KULA Design System")
                .font(DesignSystem.Typography.title1)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Glass Card Example")
                        .font(DesignSystem.Typography.headline)
                    Text("This is how text looks on glass.")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            .padding()
        }
    }
}
