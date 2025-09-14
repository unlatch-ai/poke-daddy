import SwiftUI

// Lightweight design system for a minimalist “digital glass” aesthetic.
// Purely visual: no business logic changes.

enum Design {
    // Brand colors
    static let brandStart = Color("BrandStart")
    static let brandEnd = Color("BrandEnd")
    static let brandAccent = Color("BrandAccent")

    // Background gradient used app-wide
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [brandStart.opacity(0.85), brandEnd.opacity(0.85)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Frosted glass surface with subtle inner/outer strokes.
    struct Glass: ViewModifier {
        var cornerRadius: CGFloat = 20
        var opacity: Double = 0.45
        func body(content: Content) -> some View {
            content
                .padding(14)
                .background(.ultraThinMaterial.opacity(opacity))
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.linearGradient(
                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                )
                .overlay(
                    // Soft highlight stroke
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.55), Color.white.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ), lineWidth: 1
                        )
                        .blendMode(.plusLighter)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    // Gradient stroke used to emphasize selection or primary actions.
    struct GradientStroke: ViewModifier {
        var cornerRadius: CGFloat = 20
        var lineWidth: CGFloat = 2
        func body(content: Content) -> some View {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [brandStart, brandEnd], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: lineWidth
                        )
                )
        }
    }

    // Large primary button with glass look
    struct GlassButtonStyle: ButtonStyle {
        var cornerRadius: CGFloat = 28
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial.opacity(configuration.isPressed ? 0.35 : 0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [brandStart, brandEnd], startPoint: .leading, endPoint: .trailing),
                            lineWidth: configuration.isPressed ? 1 : 2
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .shadow(color: brandEnd.opacity(0.25), radius: configuration.isPressed ? 6 : 12, x: 0, y: 6)
                .scaleEffect(configuration.isPressed ? 0.99 : 1)
        }
    }

    // Decorative background with soft blurs and gradients.
    struct Background: View {
        var body: some View {
            ZStack {
                Design.backgroundGradient.ignoresSafeArea()
                // Glow blobs
                Circle()
                    .fill(brandEnd.opacity(0.35))
                    .blur(radius: 80)
                    .frame(width: 260, height: 260)
                    .offset(x: -140, y: -220)
                Circle()
                    .fill(brandStart.opacity(0.35))
                    .blur(radius: 90)
                    .frame(width: 260, height: 260)
                    .offset(x: 160, y: 240)
            }
        }
    }
}

extension View {
    func glass(cornerRadius: CGFloat = 20, opacity: Double = 0.45) -> some View {
        modifier(Design.Glass(cornerRadius: cornerRadius, opacity: opacity))
    }
    func gradientStroke(cornerRadius: CGFloat = 20, lineWidth: CGFloat = 2) -> some View {
        modifier(Design.GradientStroke(cornerRadius: cornerRadius, lineWidth: lineWidth))
    }
}

