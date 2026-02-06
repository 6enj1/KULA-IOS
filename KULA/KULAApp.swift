//
//  KULAApp.swift
//  KULA - Save More. Waste Less.
//  A premium food waste reduction app
//

import SwiftUI
import Speech
import AVFoundation
import Combine
import GoogleSignIn

@main
struct KULAApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    // Handle Google Sign In callback
                    if GIDSignIn.sharedInstance.handle(url) {
                        return
                    }
                    // Handle other deep links
                    handleDeepLink(url)
                }
        }
    }

    // MARK: - Deep Link Handling
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "savr" else { return }

        let path = url.host ?? ""
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let params = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })

        switch path {
        case "payment":
            handlePaymentCallback(url: url, params: params)
        default:
            #if DEBUG
            print("[DeepLink] Unknown path: \(path)")
            #endif
        }
    }

    private func handlePaymentCallback(url: URL, params: [String: String]) {
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard let status = pathComponents.first else { return }

        switch status {
        case "success":
            // Payment successful - refresh orders
            Task {
                await appState.refreshOrders()
            }
            NotificationCenter.default.post(
                name: .paymentCompleted,
                object: nil,
                userInfo: ["status": "success", "orderId": params["orderId"] ?? ""]
            )

        case "cancelled", "cancel":
            // User cancelled payment
            NotificationCenter.default.post(
                name: .paymentCompleted,
                object: nil,
                userInfo: ["status": "cancelled"]
            )

        case "failed", "failure":
            // Payment failed
            NotificationCenter.default.post(
                name: .paymentCompleted,
                object: nil,
                userInfo: ["status": "failed", "error": params["error"] ?? "Payment failed"]
            )

        case "pending":
            // Payment still pending - refresh to check status
            #if DEBUG
            print("[Payment] Pending, refreshing orders...")
            #endif
            Task {
                await appState.refreshOrders()
            }

        default:
            #if DEBUG
            print("[Payment] Unknown status: \(status)")
            #endif
            // Still refresh orders to be safe
            Task {
                await appState.refreshOrders()
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let paymentCompleted = Notification.Name("paymentCompleted")
}

// MARK: - Root View (Handles Auth State)
struct RootView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSplash = true

    var body: some View {
        ZStack {
            // Main content (always rendered behind splash)
            Group {
                if appState.isAuthenticated {
                    MainTabView()
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    OnboardingView()
                        .transition(.opacity)
                }
            }
            .animation(.smooth(duration: 0.5), value: appState.isAuthenticated)

            // Splash screen overlay
            if showSplash {
                SplashView {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        // Re-check location authorization when app returns to foreground (e.g., from Settings)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                #if DEBUG
                print("[RootView] App became active, refreshing location authorization")
                #endif
                LocationManager.shared.refreshAuthorizationStatus()
            }
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @State private var selectedTab: Tab = .home
    @EnvironmentObject var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    enum Tab: String, CaseIterable {
        case home = "Home"
        case orders = "Orders"
        case profile = "Profile"

        var icon: String {
            switch self {
            case .home: return "leaf.fill"
            case .orders: return "bag.fill"
            case .profile: return "person.fill"
            }
        }
    }

    @Namespace private var searchAnimation
    @State private var showSearch: Bool = false

    var body: some View {
        ZStack {
            // Main Tab Content
            ZStack(alignment: .bottom) {
                Group {
                    switch selectedTab {
                    case .home:
                        NavigationStack {
                            HomeView()
                        }
                    case .orders:
                        NavigationStack {
                            OrdersView()
                        }
                    case .profile:
                        NavigationStack {
                            ProfileView()
                        }
                    }
                }

                // Custom Glass Tab Bar
                if !showSearch && !appState.showAddressPicker && !appState.showDirectionsSheet {
                    GlassNavBar(
                        selectedTab: $selectedTab,
                        showSearch: $showSearch,
                        searchNamespace: searchAnimation
                    )
                    .padding(.bottom, DesignSystem.Layout.tabBarBottomPadding(isRegular: isRegularWidth))
                    .transition(.opacity)
                }
            }
            .ignoresSafeArea(edges: .bottom)

            // Search View Overlay
            if showSearch {
                SearchView(
                    showSearch: $showSearch,
                    searchNamespace: searchAnimation
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: showSearch)
    }
}

// MARK: - Speech Recognizer
@MainActor
class SpeechRecognizer: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @Published var isRecording = false
    @Published var transcript = ""

    func requestPermission(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            let speechAuthorized = (status == .authorized)

            let completeOnMain: (Bool) -> Void = { micGranted in
                DispatchQueue.main.async {
                    completion(speechAuthorized && micGranted)
                }
            }

            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { micGranted in
                    completeOnMain(micGranted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { micGranted in
                    completeOnMain(micGranted)
                }
            }
        }
    }

    func startRecording(onUpdate: @escaping (String) -> Void) {
        // Reset any previous task
        recognitionTask?.cancel()
        recognitionTask = nil
        transcript = ""

        // Ensure we only install one tap and one engine start
        if audioEngine.isRunning {
            #if DEBUG
            print("[SpeechRecognizer] Audio engine already running; stopping before restart.")
            #endif
            stopRecording()
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetoothHFP, .allowBluetoothA2DP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            #if DEBUG
            print("[SpeechRecognizer] Failed to configure audio session:", error.localizedDescription)
            #endif
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest = request

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            #if DEBUG
            print("[SpeechRecognizer] SFSpeechRecognizer is unavailable.")
            #endif
            return
        }

        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        // Remove any existing taps defensively
        inputNode.removeTap(onBus: 0)

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                self.transcript = result.bestTranscription.formattedString
                onUpdate(self.transcript)
            }
            if let error = error {
                #if DEBUG
                print("[SpeechRecognizer] recognitionTask error:", error.localizedDescription)
                #endif
                self.stopRecording()
            } else if result?.isFinal == true {
                self.stopRecording()
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            #if DEBUG
            print("[SpeechRecognizer] Audio engine started.")
            #endif
        } catch {
            #if DEBUG
            print("[SpeechRecognizer] Failed to start audio engine:", error.localizedDescription)
            #endif
            stopRecording()
        }
    }

    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            #if DEBUG
            print("[SpeechRecognizer] Failed to deactivate audio session:", error.localizedDescription)
            #endif
        }
    }
}

// MARK: - Glass Nav Bar with Search
struct GlassNavBar: View {
    @Binding var selectedTab: MainTabView.Tab
    @Binding var showSearch: Bool
    var searchNamespace: Namespace.ID
    @EnvironmentObject var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Namespace private var morphAnimation

    private var isRegular: Bool { horizontalSizeClass == .regular }

    // Scaled dimensions for iPad
    private var iconSize: CGFloat { DesignSystem.Layout.tabBarIconSize(isRegular: isRegular) }
    private var itemPadding: CGFloat { DesignSystem.Layout.tabBarItemPadding(isRegular: isRegular) }
    private var searchButtonSize: CGFloat { isRegular ? 56 : 48 }
    private var pillPadding: CGFloat { isRegular ? 8 : 6 }
    private var itemSpacing: CGFloat { isRegular ? 8 : 6 }

    var body: some View {
        HStack(spacing: isRegular ? 14 : 10) {
            // Tab Bar Pill
            tabBarPill

            // Search Button
            searchButton
        }
        .padding(.horizontal, isRegular ? 32 : 20)
    }

    // MARK: - Tab Bar Pill
    private var tabBarPill: some View {
        HStack(spacing: itemSpacing) {
            ForEach(MainTabView.Tab.allCases, id: \.self) { tab in
                TabBarItem(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    namespace: morphAnimation,
                    isRegular: isRegular
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
            }
        }
        .padding(pillPadding)
        .background {
            liquidGlassBackground
        }
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
    }

    // MARK: - Search Button
    private var searchButton: some View {
        Button {
            showSearch = true
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: searchButtonSize, height: searchButtonSize)
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
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
    }

    // MARK: - Liquid Glass Background
    private var liquidGlassBackground: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .overlay {
                Capsule()
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
                Capsule()
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

// MARK: - Tab Bar Item
struct TabBarItem: View {
    let tab: MainTabView.Tab
    let isSelected: Bool
    let namespace: Namespace.ID
    var isRegular: Bool = false
    let action: () -> Void

    // Scaled dimensions for iPad
    private var iconSize: CGFloat { isRegular ? 22 : 17 }
    private var labelSize: CGFloat { isRegular ? 16 : 14 }
    private var itemSpacing: CGFloat { isRegular ? 8 : 6 }
    private var horizontalPadding: CGFloat { isSelected ? (isRegular ? 22 : 18) : (isRegular ? 20 : 16) }
    private var verticalPadding: CGFloat { isRegular ? 14 : 12 }

    var body: some View {
        Button(action: action) {
            HStack(spacing: itemSpacing) {
                Image(systemName: tab.icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)

                if isSelected {
                    Text(tab.rawValue)
                        .font(.system(size: labelSize, weight: .semibold))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background {
                if isSelected {
                    // Liquid glass bubble
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .overlay {
                            // Accent color tint
                            Capsule()
                                .fill(DesignSystem.Colors.accent.opacity(0.6))
                        }
                        .overlay {
                            // Inner highlight
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.25),
                                            .white.opacity(0.05),
                                            .clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        }
                        .overlay {
                            // Subtle border
                            Capsule()
                                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                        }
                        .shadow(color: DesignSystem.Colors.accent.opacity(0.4), radius: 8, y: 2)
                        .matchedGeometryEffect(id: "activeBubble", in: namespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tab.rawValue) tab")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
}

