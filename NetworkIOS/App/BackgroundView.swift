import SwiftUI

/// App-wide screen background behind the contact cards and status screens.
struct BackgroundView: View {
    var body: some View {
        // Plain, opaque system surface (white in light mode, black in dark).
        // It must stay opaque: the page curl turns the whole hosted view, and
        // translucent card panels would otherwise expose neighbouring cards.
        Color(.systemBackground)
    }
}

struct NetworkTheme {
    let colorScheme: ColorScheme
    var panel: Color { colorScheme == .dark ? .white.opacity(0.09) : .white.opacity(0.9) }
    var panelStrong: Color { colorScheme == .dark ? .white.opacity(0.14) : .white.opacity(0.97) }
    var border: Color { colorScheme == .dark ? .white.opacity(0.16) : .blue.opacity(0.14) }
    var primaryText: Color { colorScheme == .dark ? .white : Color(red: 0.04, green: 0.10, blue: 0.20) }
    var secondaryText: Color { colorScheme == .dark ? .white.opacity(0.68) : Color(red: 0.22, green: 0.29, blue: 0.40) }
}
