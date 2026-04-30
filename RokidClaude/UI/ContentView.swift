import SwiftUI

struct ContentView: View {
    @StateObject private var vm = ClaudeViewModel()

    var body: some View {
        TabView {
            ChatView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }
            GlassesPreviewView()
                .tabItem { Label("Glasses", systemImage: "eyeglasses") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .environmentObject(vm)
        .environmentObject(SettingsStore.shared)
    }
}
