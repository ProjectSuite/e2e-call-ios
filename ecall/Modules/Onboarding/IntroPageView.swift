import SwiftUI

struct IntroPageView: View {
    @State private var currentPage = 0
    @AppStorage("isIntroCompleted") private var isIntroCompleted: Bool = false

    // Primary gradient for navigation buttons
    private var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "06B6D4"), Color(hex: "3B82F6")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Onboarding data
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            image: "lock.shield.fill",
            title: "End-to-end\nsecure calls",
            subtitle: "Audio & video calls are encrypted\nwith AES-256 + RSA."
        ),
        OnboardingPage(
            image: "eye.slash.circle.fill",
            title: "Privacy-first\narchitecture",
            subtitle: "No call records on our servers.\nKeys stay local on device."
        ),
        OnboardingPage(
            image: "person.crop.circle.badge.plus",
            title: "Smart, secure\ncontacts",
            subtitle: "Invite friends with QR codes\nand encrypted address book sync."
        ),
        OnboardingPage(
            image: "ipad.and.iphone",
            title: "Multi-device\ncontrol",
            subtitle: "Review sessions in seconds\nand end unknown devices."
        ),
        OnboardingPage(
            image: "key.fill",
            title: "Own your\nkeys",
            subtitle: "Manage AES, RSA, and recovery\nkeys from one secure place."
        )
    ]

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button(action: {
                        completeIntro()
                    }) {
                        Text("Skip")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .padding(.trailing, 36)
                    .padding(.top, 20)
                }

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(
                            page: pages[index],
                            currentPage: currentPage,
                            totalPages: pages.count,
                            index: index
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                // Navigation buttons
                HStack(spacing: 0) {
                    // Back button
                    Button(action: {
                        if currentPage > 0 {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                    }
                    .opacity(currentPage > 0 ? 1 : 0.4)
                    .disabled(currentPage == 0)

                    Divider()
                        .frame(width: 2, height: 24)
                        .background(Color.white.opacity(0.3))
                        .padding(.horizontal, 20)

                    // Next/Finish button
                    Button(action: {
                        if currentPage < pages.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            completeIntro()
                        }
                    }) {
                        Image(systemName: currentPage == pages.count - 1 ? "checkmark" : "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(primaryGradient)
                )
                .padding(.bottom, 40)
            }
        }
    }

    private func completeIntro() {
        isIntroCompleted = true
    }
}

// MARK: - Onboarding Page Model
struct OnboardingPage {
    let image: String
    let title: String
    let subtitle: String
}

// MARK: - Individual Page View
struct OnboardingPageView: View {
    let page: OnboardingPage
    let currentPage: Int
    let totalPages: Int
    let index: Int

    // Primary gradient matching navigation buttons
    private var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "06B6D4"), Color(hex: "3B82F6")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private let accentColor = Color(hex: "3B82F6")

    var body: some View {
        VStack(spacing: 0) {
            // Icon with shadow effect
            ZStack {
                // Shadow layer mimicking blurred background
                Image(systemName: page.image)
                    .font(.system(size: 100, weight: .regular))
                    .foregroundColor(accentColor)
                    .frame(width: 200, height: 200)
                    .background(
                        accentColor.opacity(0.2),
                        in: RoundedRectangle(cornerRadius: 40)
                    )
                    .blur(radius: 80)
                    .opacity(currentPage == index ? 0.4 : 0)
                    .scaleEffect(currentPage == index ? 1.0 : 0.9)
                    .animation(.easeInOut(duration: 0.5), value: currentPage)
                    .zIndex(0)

                // Main icon layer
                Image(systemName: page.image)
                    .font(.system(size: 100, weight: .regular))
                    .foregroundColor(.white)
                    .frame(width: 200, height: 200)
                    .background(
                        primaryGradient,
                        in: RoundedRectangle(cornerRadius: 40)
                    )
                    .scaleEffect(currentPage == index ? 1.0 : 0.9)
                    .opacity(currentPage == index ? 1 : 0.8)
                    .animation(.easeInOut(duration: 0.5), value: currentPage)
                    .zIndex(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)

            // Custom page indicators
            HStack(spacing: 12) {
                ForEach(0..<totalPages, id: \.self) { pageIndex in
                    Circle()
                        .fill(currentPage == pageIndex ? accentColor : Color.gray.opacity(0.3))
                        .frame(
                            width: currentPage == pageIndex ? 12 : 8,
                            height: currentPage == pageIndex ? 12 : 8
                        )
                        .overlay(
                            Circle()
                                .stroke(accentColor, lineWidth: currentPage == pageIndex ? 0.5 : 0)
                                .padding(-4)
                        )
                }
            }
            .padding(.vertical, 24)

            // Title and subtitle
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)

                Text(page.subtitle)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor("#8E9295".hexColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding()
    }
}

#Preview("Intro Flow") {
    IntroPageView()
}
