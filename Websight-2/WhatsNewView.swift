//
//  WhatsNewView.swift
//  websight
//
//  Created by Evan Nemetz on 3/7/26.
//

import SwiftUI

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let features: [WhatsNewFeature] = [
        WhatsNewFeature(
            icon: "safari",
            iconColor: .blue,
            title: "Browse In-App",
            description: "Open websites directly in the app with a beautiful Safari view",
            imageName: "safari.feature"
        ),
        WhatsNewFeature(
            icon: "map.fill",
            iconColor: .green,
            title: "Maps Integration",
            description: "View addresses on an interactive map without leaving the app",
            imageName: "maps.feature"
        ),
        WhatsNewFeature(
            icon: "envelope.fill",
            iconColor: .blue,
            title: "Compose Mail",
            description: "Write emails directly in the app with full Mail composer",
            imageName: "mail.feature"
        ),
        WhatsNewFeature(
            icon: "clock.fill",
            iconColor: .purple,
            title: "Smart History",
            description: "Your detected items are now saved with quick actions to reuse them",
            imageName: "history.feature"
        ),
        WhatsNewFeature(
            icon: "gearshape.fill",
            iconColor: .gray,
            title: "Customizable Settings",
            description: "New settings page lets you choose whether actions open in-app or externally",
            imageName: "settings.feature"
        )
    ]
    
    var body: some View {
        ZStack {
            // Background gradient - Matches app icon (teal to peach/coral)
            LinearGradient(
                colors: [
                    Color(red: 0.5, green: 0.85, blue: 0.75),  // Teal/mint (top left)
                    Color(red: 0.7, green: 0.75, blue: 0.7),   // Soft gray-green (center)
                    Color(red: 0.95, green: 0.75, blue: 0.7),  // Peachy pink (right)
                    Color(red: 0.9, green: 0.7, blue: 0.6)     // Coral/tan (bottom)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.6), .white.opacity(0.15))
                            .symbolRenderingMode(.hierarchical)
                    }
                    .padding(.top, 20)
                    .padding(.trailing, 24)
                }
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Header Section
                        VStack(spacing: 12) {
                            Text("What's New")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            
                            Text("Version 2.2")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.top, 8)
                        
                        // Features List
                        VStack(spacing: 20) {
                            ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                                FeatureRow(feature: feature)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    }
                    .padding(.bottom, 100)
                }
                
                Spacer()
            }
            
            // Floating Get Started Button
            VStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Text("Get Started")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.45, green: 0.8, blue: 0.7),   // Teal
                                            Color(red: 0.55, green: 0.75, blue: 0.65)  // Mint green
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                        .shadow(color: Color(red: 0.5, green: 0.8, blue: 0.7).opacity(0.4), radius: 20, y: 10)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .background {
                    LinearGradient(
                        colors: [
                            Color(red: 0.9, green: 0.7, blue: 0.6).opacity(0),
                            Color(red: 0.9, green: 0.7, blue: 0.6).opacity(0.95)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
            }
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let feature: WhatsNewFeature
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(feature.iconColor.opacity(0.2))
                    .frame(width: 56, height: 56)
                
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                feature.iconColor.opacity(0.3),
                                feature.iconColor.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                Image(systemName: feature.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: feature.iconColor.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            
            // Text Content
            VStack(alignment: .leading, spacing: 6) {
                Text(feature.title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text(feature.description)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                }
        }
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 2)
    }
}

// MARK: - Feature Model
struct WhatsNewFeature {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let imageName: String
}

// MARK: - Version Tracking
class AppVersionManager {
    static let shared = AppVersionManager()
    
    private let lastVersionKey = "lastVersionPromptShown"
    
    // Automatically read version from Info.plist
    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    // Set to false for bug fix releases where you don't want to show "What's New"
    private let shouldShowForThisVersion = true
    
    func shouldShowWhatsNew() -> Bool {
        guard shouldShowForThisVersion else { return false }
        let lastVersion = UserDefaults.standard.string(forKey: lastVersionKey)
        return lastVersion != currentVersion
    }
    
    func markWhatsNewAsShown() {
        UserDefaults.standard.set(currentVersion, forKey: lastVersionKey)
    }
    
    // MARK: - Testing/Debug Methods
    
    /// Call this to reset and show "What's New" again (for testing)
    func resetWhatsNewPrompt() {
        UserDefaults.standard.removeObject(forKey: lastVersionKey)
    }
    
    /// Check what version was last shown
    func getLastShownVersion() -> String? {
        return UserDefaults.standard.string(forKey: lastVersionKey)
    }
}

#Preview {
    WhatsNewView()
}
