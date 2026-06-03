//
//  ContentView.swift
//  Block
//
//  Root tab bar: Home (status) · Lists (app groups) · Blocks (rules).
//

import SwiftUI

struct ContentView: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Home", systemImage: "lock.shield") }
                .tag(0)

            AppGroupListView()
                .tabItem { Label("Lists", systemImage: "square.grid.2x2") }
                .tag(1)

            BlockListView()
                .tabItem { Label("Blocks", systemImage: "bolt.horizontal.circle") }
                .tag(2)
        }
        .tint(ArtNouveauTheme.primary)
        #if DEBUG
        .onAppear {
            if let raw = ProcessInfo.processInfo.environment["BLOCK_TAB"], let t = Int(raw) {
                selection = t
            }
        }
        #endif
    }
}

/// Button style that scales down on press to feel more tactile.
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    ContentView()
}
