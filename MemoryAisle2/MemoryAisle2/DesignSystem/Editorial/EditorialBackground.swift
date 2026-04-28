import SwiftUI

/// Full-bleed gradient (Day or Night) with the firefly layer overlaid in
/// Night mode. Owns the touch-point state for fireflies via a drag gesture
/// applied to a transparent overlay — placed above the gradient but behind
/// the content, with `allowsHitTesting(false)` on the canvas itself so taps
/// still reach buttons.
struct EditorialBackground: View {
    let mode: MAMode

    @State private var touchPoint: CGPoint? = nil

    var body: some View {
        ZStack {
            (mode == .day ? Theme.Editorial.dayGradient : Theme.Editorial.nightGradient)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: mode)

            if mode == .night {
                FirefliesLayer(touchPoint: $touchPoint)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    if mode == .night {
                        touchPoint = value.location
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.4)) {
                        touchPoint = nil
                    }
                }
        )
    }
}
