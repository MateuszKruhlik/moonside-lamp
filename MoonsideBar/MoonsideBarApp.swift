import SwiftUI

@main
struct MoonsideBarApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState)
                .frame(width: 280)
        } label: {
            Image(systemName: menuBarIconName)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarIconName: String {
        switch appState.connectionStatus {
        case .connected:
            return appState.isLedOn ? "lightbulb.max.fill" : "lightbulb.fill"
        case .connecting:
            return "lightbulb"
        case .disconnected:
            return "lightbulb.slash"
        }
    }

    init() {
        // Trigger setup after SwiftUI creates the state
        DispatchQueue.main.async { [appState] in
            appState.setup()
        }
    }
}
