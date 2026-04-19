import AppKit
import SwiftUI

@main
struct MoonsideBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible windows — everything is menu bar + side panel
        Settings { EmptyView() }
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let panelController = SidePanelController()
    let appState = AppState()
    private var iconTimer: Timer?
    private var contextMenu: NSMenu!
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupContextMenu()
        appState.setup()

        // Poll icon updates (lightweight, 0.5s)
        iconTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateStatusIcon()
        }
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateStatusIcon()

        // Monitor events on the status button to differentiate left/right click
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Show context menu
            statusItem.menu = contextMenu
            statusItem.button?.performClick(nil)
            // Reset menu so left-click works next time
            DispatchQueue.main.async { [weak self] in
                self?.statusItem.menu = nil
            }
        } else {
            // Left click — toggle panel
            panelController.toggle(appState: appState)
        }
    }

    // MARK: - Context Menu

    private func setupContextMenu() {
        contextMenu = NSMenu()

        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        contextMenu.addItem(settingsItem)

        let reconnectItem = NSMenuItem(title: "Reconnect", action: #selector(reconnectBLE), keyEquivalent: "")
        reconnectItem.target = self
        contextMenu.addItem(reconnectItem)

        let howItWorksItem = NSMenuItem(title: "How it works", action: #selector(openHowItWorks), keyEquivalent: "")
        howItWorksItem.target = self
        contextMenu.addItem(howItWorksItem)

        contextMenu.addItem(NSMenuItem.separator())

        let websiteItem = NSMenuItem(title: "Website", action: #selector(openWebsite), keyEquivalent: "")
        websiteItem.target = self
        contextMenu.addItem(websiteItem)

        contextMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        contextMenu.addItem(quitItem)
    }

    @objc private func openSettings() {
        panelController.toggle(appState: appState)
    }

    @objc private func reconnectBLE() {
        appState.manualReconnect()
    }

    @objc private func openHowItWorks() {
        HowItWorksWindowController.shared.showWindow()
    }

    @objc private func openWebsite() {
        if let url = URL(string: "https://github.com/MateuszKruhlik/moonside-lamp") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quitApp() {
        appState.bluetoothManager?.send("LEDOFF")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - Icon Updates

    private func updateStatusIcon() {
        if let image = NSImage(named: "icon_menubar") {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            statusItem.button?.image = image
            // Dim when disconnected or unauthorized
            statusItem.button?.appearsDisabled = appState.connectionStatus != .connected
        }
    }
}
