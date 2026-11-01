import SwiftUI

enum Theme {
    static let background = Color(red: 11 / 255, green: 13 / 255, blue: 16 / 255)
    static let surface = Color(red: 23 / 255, green: 26 / 255, blue: 31 / 255)
    static let track = Color(red: 35 / 255, green: 39 / 255, blue: 46 / 255)
    static let accent = Color(red: 198 / 255, green: 244 / 255, blue: 50 / 255)
    static let accentDeep = Color(red: 150 / 255, green: 200 / 255, blue: 28 / 255)
    static let textPrimary = Color(red: 243 / 255, green: 245 / 255, blue: 247 / 255)
    static let textSecondary = Color(red: 139 / 255, green: 144 / 255, blue: 152 / 255)
}

struct Reveal: ViewModifier {
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(delay)) {
                    shown = true
                }
            }
    }
}

extension View {
    func reveal(delay: Double) -> some View {
        modifier(Reveal(delay: delay))
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
