import AppKit
import SwiftUI

// MARK: - Custom Panel (supports Escape to close)
final class SidePanel: NSPanel {
    var onClose: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) {
        onClose?()
    }
}

// MARK: - Gradient Overlay (progressive blur R→L)
final class GradientOverlayView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        let gradient = CAGradientLayer()
        gradient.colors = [
            NSColor(white: 0.067, alpha: 0.0).cgColor,
            NSColor(white: 0.067, alpha: 0.55).cgColor,
            NSColor(white: 0.067, alpha: 0.85).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        layer?.addSublayer(gradient)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        layer?.sublayers?.first?.frame = bounds
    }
}

// MARK: - Film Grain Overlay
struct FilmGrain: View {
    var body: some View {
        Canvas { context, size in
            for _ in 0..<600 {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let opacity = Double.random(in: 0.008...0.025)
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                    with: .color(.white.opacity(opacity))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Side Panel Controller
final class SidePanelController {
    private var panel: SidePanel?
    private var eventMonitor: Any?
    private let panelWidth: CGFloat = 380

    var isVisible: Bool { panel != nil }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    func toggle(appState: AppState) {
        if isVisible { hide() } else { show(appState: appState) }
    }

    func show(appState: AppState) {
        guard panel == nil, let screen = NSScreen.main else { return }

        let visibleFrame = screen.visibleFrame
        let panelHeight = visibleFrame.height - 12
        let y = visibleFrame.minY + 6

        let p = SidePanel(
            contentRect: NSRect(x: screen.frame.maxX, y: y, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )

        // Frosted glass requires vibrantDark appearance
        p.appearance = NSAppearance(named: .vibrantDark)
        p.isFloatingPanel = true
        p.level = .floating
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isMovableByWindowBackground = false
        p.animationBehavior = .utilityWindow
        p.isReleasedWhenClosed = false
        p.onClose = { [weak self] in self?.hide() }
        p.alphaValue = 0  // ← startujemy od niewidocznego

        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 20
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderWidth = 0

        // Progressive blur overlay: transparent left → opaque #111 right
        let gradientOverlay = GradientOverlayView()
        gradientOverlay.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(gradientOverlay)
        NSLayoutConstraint.activate([
            gradientOverlay.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            gradientOverlay.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            gradientOverlay.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            gradientOverlay.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
        ])

        let content = SidePanelContentView(appState: appState) { [weak self] in
            self?.hide()
        }
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = CGColor.clear
        hostingView.layer?.isOpaque = false

        visualEffect.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
        ])

        p.contentView = visualEffect
        p.orderFront(nil)

        let endX = screen.frame.maxX - panelWidth - 6
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.4
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
            p.animator().setFrame(
                NSRect(x: endX, y: y, width: panelWidth, height: panelHeight),
                display: true
            )
            p.animator().alphaValue = 1
        }

        self.panel = p

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hide()
        }
    }

    func hide() {
        guard let p = panel, let screen = NSScreen.main else { return }

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }

        let offScreenX = screen.frame.maxX + 20
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            p.animator().setFrame(
                NSRect(x: offScreenX, y: p.frame.minY, width: p.frame.width, height: p.frame.height),
                display: true
            )
        }, completionHandler: { [weak self] in
            p.orderOut(nil)
            self?.panel = nil
        })
    }
}

// MARK: - Panel Content Wrapper
struct SidePanelContentView: View {
    @Bindable var appState: AppState
    let onClose: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            MenuBarView(appState: appState)
                .padding(.top, 8)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.clear)
        .overlay(FilmGrain())
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if value.translation.width > 60 && abs(value.translation.height) < 100 {
                        onClose()
                    }
                }
        )
    }
}
