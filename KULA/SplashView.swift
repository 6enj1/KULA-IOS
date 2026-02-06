//
//  SplashView.swift
//  KULA
//
//  Professional Launch Screen Experience
//

import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0
    @State private var labelOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var shimmerOffset: CGFloat = -200
    @State private var isAnimationComplete = false

    // Smoke animation states
    @State private var smokeOffset1: CGFloat = 0
    @State private var smokeOffset2: CGFloat = 0
    @State private var smokeOffset3: CGFloat = 0
    @State private var smokeOpacity: Double = 0

    var onComplete: () -> Void

    // Brand colors
    private let gradientTop = Color(hex: "0A1F24")
    private let gradientBottom = Color(hex: "141A1F")
    private let labelGreen = Color(hex: "2EC58D")
    private let smokeGreen = Color(hex: "1A5C42")
    private let smokeEmerald = Color(hex: "0D4A3A")

    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [gradientTop, gradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Subtle ambient glow (teal accent)
            RadialGradient(
                colors: [
                    Color(hex: "2DD4BF").opacity(0.12),
                    Color.clear
                ],
                center: .center,
                startRadius: 50,
                endRadius: 300
            )
            .blur(radius: 60)
            .offset(y: -50)

            // MARK: - Rising Smoke Effect (Behind logo)
            smokeLayer
                .opacity(smokeOpacity)

            // Logo and branding
            VStack(spacing: 0) {
                Spacer()

                // Main logo with label
                VStack(spacing: 24) {
                    // Logo container
                    ZStack {
                        // Glow effect behind logo
                        Image("KulaLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 180, height: 180)
                            .blur(radius: 30)
                            .opacity(logoOpacity * 0.4)

                        // Main logo with shimmer
                        Image("KulaLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 180, height: 180)
                            .overlay {
                                // Shimmer effect
                                LinearGradient(
                                    colors: [
                                        .clear,
                                        .white.opacity(0.3),
                                        .clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: 100)
                                .offset(x: shimmerOffset)
                                .blur(radius: 5)
                            }
                            .mask {
                                Image("KulaLogo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 180, height: 180)
                            }
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                    // Brand name label
                    Text("KULA")
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .foregroundStyle(labelGreen)
                        .tracking(8)
                        .opacity(labelOpacity)
                }

                Spacer()

                // Bottom tagline
                Text("Powered by KULA")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1)
                    .opacity(textOpacity)
                    .padding(.bottom, 50)
            }
        }
        .onAppear {
            startAnimationSequence()
        }
    }

    // MARK: - Smoke Layer
    private var smokeLayer: some View {
        GeometryReader { geo in
            ZStack {
                // Layer 1: Subtle base mist
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                smokeEmerald.opacity(0.3),
                                smokeEmerald.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: geo.size.width * 1.2, height: 200)
                    .blur(radius: 40)
                    .offset(y: geo.size.height - 100 - smokeOffset1)

                // Layer 2: Rising wisps (left)
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                smokeGreen.opacity(0.25),
                                smokeGreen.opacity(0.08),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 250, height: 300)
                    .blur(radius: 50)
                    .offset(x: -60, y: geo.size.height - 50 - smokeOffset2)

                // Layer 3: Rising wisps (right)
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                smokeGreen.opacity(0.2),
                                smokeEmerald.opacity(0.06),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 180
                        )
                    )
                    .frame(width: 280, height: 350)
                    .blur(radius: 60)
                    .offset(x: 80, y: geo.size.height - 30 - smokeOffset3)

                // Layer 4: Central gentle mist
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [
                                smokeGreen.opacity(0.15),
                                Color.clear
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: geo.size.width, height: 400)
                    .blur(radius: 45)
                    .offset(y: geo.size.height - 150 - (smokeOffset1 * 0.5))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }

    private func startAnimationSequence() {
        // Phase 0: Start smoke rising
        withAnimation(.easeOut(duration: 0.8)) {
            smokeOpacity = 1
        }

        // Continuous smoke animation
        withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
            smokeOffset1 = 80
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                smokeOffset2 = 120
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                smokeOffset3 = 100
            }
        }

        // Phase 1: Logo fade in and scale up
        withAnimation(.easeOut(duration: 0.6)) {
            logoOpacity = 1
            logoScale = 1.0
        }

        // Phase 2: Shimmer effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: 0.8)) {
                shimmerOffset = 200
            }
        }

        // Phase 3: Label fade in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.5)) {
                labelOpacity = 1
            }
        }

        // Phase 4: Bottom tagline fade in
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeOut(duration: 0.4)) {
                textOpacity = 1
            }
        }

        // Phase 5: Complete and transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isAnimationComplete = true
            }
            onComplete()
        }
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    SplashView(onComplete: {})
}
