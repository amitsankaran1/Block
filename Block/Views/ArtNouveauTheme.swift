//
//  ArtNouveauTheme.swift
//  Block
//
//  Created by Amit Sankaran on 1/7/26.
//

import SwiftUI

// Modern, sophisticated design system inspired by Cursor, Linear, Notion
struct ArtNouveauTheme {
    // Modern Color Palette - Rich and vibrant
    static let primary = Color(red: 0.26, green: 0.40, blue: 0.98) // Vibrant blue
    static let primaryDark = Color(red: 0.20, green: 0.32, blue: 0.88)
    static let primaryLight = Color(red: 0.26, green: 0.40, blue: 0.98).opacity(0.15)
    static let secondary = Color(red: 0.40, green: 0.47, blue: 0.95)
    static let accent = Color(red: 0.55, green: 0.45, blue: 0.95) // Purple accent

    // Status colors - More vibrant and distinct
    static let success = Color(red: 0.20, green: 0.78, blue: 0.35) // Vibrant green
    static let successLight = Color(red: 0.20, green: 0.78, blue: 0.35).opacity(0.15)
    static let warning = Color(red: 1.0, green: 0.58, blue: 0.0) // Vibrant orange
    static let warningLight = Color(red: 1.0, green: 0.58, blue: 0.0).opacity(0.15)
    static let error = Color(red: 0.96, green: 0.26, blue: 0.21) // Vibrant red
    static let errorLight = Color(red: 0.96, green: 0.26, blue: 0.21).opacity(0.15)

    // Neutral colors with better contrast
    static let background = Color(UIColor.systemBackground)
    static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    static let tertiaryBackground = Color(UIColor.tertiarySystemBackground)
    static let label = Color(UIColor.label)
    static let secondaryLabel = Color(UIColor.secondaryLabel)
    static let tertiaryLabel = Color(UIColor.tertiaryLabel)
    static let border = Color(UIColor.separator).opacity(0.5)

    // Legacy color aliases for compatibility
    static let forestGreen = primary
    static let oliveGreen = secondary
    static let tealGreen = accent
    static let deepGreen = primary
    static let cream = tertiaryBackground
    static let warmIvory = tertiaryBackground
    static let mutedCream = secondaryBackground
    static let softBlue = primary.opacity(0.3)
    static let skyBlue = primary.opacity(0.2)
    static let mutedBrown = Color.brown
    static let mutedPurple = Color.purple
    static let mutedGold = warning
    static let softGold = warning.opacity(0.7)
    static let softRose = Color.pink
    static let accentRose = Color.pink.opacity(0.7)

    // Modern gradients - Rich and dynamic
    static let primaryGradient = LinearGradient(
        colors: [primary, primaryDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let successGradient = LinearGradient(
        colors: [success, Color(red: 0.15, green: 0.70, blue: 0.30)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let errorGradient = LinearGradient(
        colors: [error, Color(red: 0.85, green: 0.20, blue: 0.15)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let goldGradient = LinearGradient(
        colors: [warning, warning.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [accent, accent.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let skyGradient = LinearGradient(
        colors: [primary.opacity(0.15), primary.opacity(0.05)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // Glassmorphism background
    static let glassBackground = Color(UIColor.systemBackground).opacity(0.7)

    // Modern Typography - SF Pro with better weights
    static let titleFont = Font.system(.title, design: .default).weight(.bold)
    static let largeTitleFont = Font.system(.largeTitle, design: .default).weight(.bold)
    static let headlineFont = Font.system(.headline, design: .default).weight(.semibold)
    static let bodyFont = Font.system(.body, design: .default)
    
    // Shadow presets for depth
    static let shadowSmall = Shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    static let shadowMedium = Shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
    static let shadowLarge = Shadow(color: Color.black.opacity(0.16), radius: 24, x: 0, y: 8)
    
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

// Modern Button Style - Rich with depth and gradients
struct ArtNouveauButtonStyle: ButtonStyle {
    var isProminent: Bool = true
    var gradient: LinearGradient? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .default).weight(.semibold))
            .foregroundColor(isProminent ? .white : ArtNouveauTheme.primary)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                Group {
                    if isProminent {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(gradient ?? ArtNouveauTheme.primaryGradient)
                            .shadow(color: ArtNouveauTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.clear)
                    }
                }
            )
            .overlay(
                Group {
                    if !isProminent {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(ArtNouveauTheme.primary, lineWidth: 2)
                    }
                }
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// Minimal decorative elements - kept for compatibility
struct ArtNouveauBorder: View {
    var body: some View {
        Rectangle()
            .stroke(Color.clear, lineWidth: 0)
    }
}

struct ArtNouveauOrnament: View {
    var size: CGFloat = 100

    var body: some View {
        EmptyView()
    }
}

// Clean Background - No decorative patterns
struct ArtNouveauBackground: View {
    var body: some View {
        ArtNouveauTheme.background
            .ignoresSafeArea()
    }
}

// Modern Card Style - Rich with depth, shadows, and optional glassmorphism
struct ArtNouveauCard<Content: View>: View {
    let content: Content
    var useGlassmorphism: Bool = false
    var shadow: ArtNouveauTheme.Shadow = ArtNouveauTheme.shadowMedium

    init(useGlassmorphism: Bool = false, shadow: ArtNouveauTheme.Shadow = ArtNouveauTheme.shadowMedium, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.useGlassmorphism = useGlassmorphism
        self.shadow = shadow
    }

    var body: some View {
        content
            .padding(24)
            .background(
                Group {
                    if useGlassmorphism {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(ArtNouveauTheme.border, lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(ArtNouveauTheme.secondaryBackground)
                            .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
                    }
                }
            )
    }
}
