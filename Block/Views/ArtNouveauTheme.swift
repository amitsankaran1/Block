//
//  ArtNouveauTheme.swift
//  Block
//
//  Created by Amit Sankaran on 1/7/26.
//

import SwiftUI

struct ArtNouveauTheme {
    // Color Palette - Matching app icon's Art Nouveau style
    // Deep forest greens, olive greens, teal greens
    static let forestGreen = Color(red: 0.15, green: 0.35, blue: 0.25)
    static let oliveGreen = Color(red: 0.25, green: 0.4, blue: 0.3)
    static let tealGreen = Color(red: 0.2, green: 0.45, blue: 0.4)
    static let deepGreen = Color(red: 0.18, green: 0.38, blue: 0.28) // Primary green
    
    // Muted creams/ivory for lines
    static let cream = Color(red: 0.98, green: 0.96, blue: 0.92)
    static let warmIvory = Color(red: 0.97, green: 0.95, blue: 0.91)
    static let mutedCream = Color(red: 0.95, green: 0.93, blue: 0.89)
    
    // Soft blues for sky
    static let softBlue = Color(red: 0.65, green: 0.78, blue: 0.88)
    static let skyBlue = Color(red: 0.7, green: 0.8, blue: 0.9)
    
    // Earthy tones
    static let mutedBrown = Color(red: 0.45, green: 0.4, blue: 0.35)
    static let mutedPurple = Color(red: 0.4, green: 0.35, blue: 0.45)
    
    // Muted gold/yellow accents
    static let mutedGold = Color(red: 0.88, green: 0.78, blue: 0.58)
    static let softGold = Color(red: 0.92, green: 0.82, blue: 0.65)
    
    // Soft rose/pink accents
    static let softRose = Color(red: 0.75, green: 0.55, blue: 0.6)
    static let accentRose = Color(red: 0.72, green: 0.52, blue: 0.57)
    
    // Gradients matching the icon's palette
    static let primaryGradient = LinearGradient(
        colors: [forestGreen, oliveGreen, tealGreen],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let goldGradient = LinearGradient(
        colors: [mutedGold.opacity(0.9), softGold.opacity(0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let accentGradient = LinearGradient(
        colors: [mutedPurple, softRose],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let skyGradient = LinearGradient(
        colors: [skyBlue, softBlue],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // Typography
    static let titleFont = Font.system(.title, design: .serif).weight(.medium)
    static let headlineFont = Font.system(.headline, design: .serif).weight(.medium)
    static let bodyFont = Font.system(.body, design: .serif)
}

// Custom Art Nouveau Button Style
struct ArtNouveauButtonStyle: ButtonStyle {
    var isProminent: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ArtNouveauTheme.headlineFont)
            .foregroundColor(isProminent ? .white : ArtNouveauTheme.forestGreen)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                Group {
                    if isProminent {
                        ArtNouveauTheme.primaryGradient
                    } else {
                        Color.clear
                    }
                }
            )
            .overlay(
                Group {
                    if !isProminent {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [ArtNouveauTheme.cream.opacity(0.6), ArtNouveauTheme.oliveGreen.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: ArtNouveauTheme.forestGreen.opacity(0.25), radius: configuration.isPressed ? 4 : 10, x: 0, y: configuration.isPressed ? 2 : 5)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// Decorative Border View
struct ArtNouveauBorder: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                
                // Create flowing, organic border
                path.move(to: CGPoint(x: 0, y: height * 0.1))
                
                // Curved top
                path.addCurve(
                    to: CGPoint(x: width * 0.3, y: 0),
                    control1: CGPoint(x: width * 0.1, y: 0),
                    control2: CGPoint(x: width * 0.2, y: 0)
                )
                
                path.addCurve(
                    to: CGPoint(x: width * 0.7, y: 0),
                    control1: CGPoint(x: width * 0.5, y: 0),
                    control2: CGPoint(x: width * 0.6, y: 0)
                )
                
                path.addCurve(
                    to: CGPoint(x: width, y: height * 0.1),
                    control1: CGPoint(x: width * 0.8, y: 0),
                    control2: CGPoint(x: width * 0.9, y: 0)
                )
                
                // Right side
                path.addLine(to: CGPoint(x: width, y: height * 0.9))
                
                // Curved bottom
                path.addCurve(
                    to: CGPoint(x: width * 0.7, y: height),
                    control1: CGPoint(x: width * 0.9, y: height),
                    control2: CGPoint(x: width * 0.8, y: height)
                )
                
                path.addCurve(
                    to: CGPoint(x: width * 0.3, y: height),
                    control1: CGPoint(x: width * 0.6, y: height),
                    control2: CGPoint(x: width * 0.5, y: height)
                )
                
                path.addCurve(
                    to: CGPoint(x: 0, y: height * 0.9),
                    control1: CGPoint(x: width * 0.2, y: height),
                    control2: CGPoint(x: width * 0.1, y: height)
                )
                
                path.closeSubpath()
            }
            .stroke(ArtNouveauTheme.mutedGold, lineWidth: 2)
        }
    }
}

// Decorative Ornament View - Floral motifs like the icon
struct ArtNouveauOrnament: View {
    var size: CGFloat = 100
    
    var body: some View {
        ZStack {
            // Stylized floral bud shape (like in the icon)
            Path { path in
                let center = size / 2
                let budWidth = size * 0.15
                
                // Elongated floral bud
                path.move(to: CGPoint(x: center, y: size * 0.1))
                path.addCurve(
                    to: CGPoint(x: center + budWidth, y: center),
                    control1: CGPoint(x: center + budWidth * 0.3, y: size * 0.3),
                    control2: CGPoint(x: center + budWidth * 0.7, y: size * 0.4)
                )
                path.addCurve(
                    to: CGPoint(x: center, y: size * 0.9),
                    control1: CGPoint(x: center + budWidth * 0.5, y: size * 0.6),
                    control2: CGPoint(x: center + budWidth * 0.3, y: size * 0.75)
                )
                path.addCurve(
                    to: CGPoint(x: center - budWidth, y: center),
                    control1: CGPoint(x: center - budWidth * 0.3, y: size * 0.75),
                    control2: CGPoint(x: center - budWidth * 0.5, y: size * 0.6)
                )
                path.addCurve(
                    to: CGPoint(x: center, y: size * 0.1),
                    control1: CGPoint(x: center - budWidth * 0.7, y: size * 0.4),
                    control2: CGPoint(x: center - budWidth * 0.3, y: size * 0.3)
                )
            }
            .stroke(ArtNouveauTheme.mutedGold.opacity(0.5), lineWidth: 1.5)
            
            // Flowing tendrils
            Path { path in
                let center = size / 2
                path.move(to: CGPoint(x: center * 0.7, y: center * 0.6))
                path.addCurve(
                    to: CGPoint(x: center * 1.3, y: center * 1.4),
                    control1: CGPoint(x: center * 0.9, y: center * 1.0),
                    control2: CGPoint(x: center * 1.1, y: center * 1.2)
                )
            }
            .stroke(ArtNouveauTheme.cream.opacity(0.4), lineWidth: 1)
        }
        .frame(width: size, height: size)
    }
}

// Decorative Background Pattern - Matching icon's subtle style
struct ArtNouveauBackground: View {
    var body: some View {
        ZStack {
            // Soft cream background like the icon
            ArtNouveauTheme.warmIvory
            
            // Subtle decorative pattern with organic elements
            GeometryReader { geometry in
                // Floral motifs positioned organically
                ForEach(0..<6, id: \.self) { i in
                    ArtNouveauOrnament(size: 60)
                        .opacity(0.06)
                        .position(
                            x: geometry.size.width * (0.15 + Double(i % 3) * 0.25),
                            y: geometry.size.height * (0.2 + Double(i / 3) * 0.35)
                        )
                }
                
                // Subtle arch-like curves at top
                Path { path in
                    let width = geometry.size.width
                    path.move(to: CGPoint(x: 0, y: geometry.size.height * 0.05))
                    path.addCurve(
                        to: CGPoint(x: width, y: geometry.size.height * 0.05),
                        control1: CGPoint(x: width * 0.3, y: 0),
                        control2: CGPoint(x: width * 0.7, y: 0)
                    )
                }
                .stroke(ArtNouveauTheme.cream.opacity(0.15), lineWidth: 1)
            }
        }
    }
}

// Custom Card Style - With organic arch-like borders
struct ArtNouveauCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(ArtNouveauTheme.cream)
                    .shadow(color: ArtNouveauTheme.forestGreen.opacity(0.15), radius: 16, x: 0, y: 6)
            )
            .overlay(
                // Organic border with cream lines like the icon
                RoundedRectangle(cornerRadius: 28)
                    .stroke(
                        LinearGradient(
                            colors: [
                                ArtNouveauTheme.cream.opacity(0.8),
                                ArtNouveauTheme.mutedGold.opacity(0.4),
                                ArtNouveauTheme.oliveGreen.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .overlay(
                // Subtle inner glow
                RoundedRectangle(cornerRadius: 28)
                    .stroke(ArtNouveauTheme.cream.opacity(0.3), lineWidth: 1)
                    .padding(1)
            )
    }
}
