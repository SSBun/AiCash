import SwiftUI
import AppKit

class StatusBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var viewModel: ProviderViewModel
    
    init(viewModel: ProviderViewModel) {
        self.viewModel = viewModel
        setupStatusItem()
        updateStatusTitle()
        
        // Observe provider changes to update the title
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateStatusTitle),
            name: NSNotification.Name("ProvidersUpdated"),
            object: nil
        )
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "dollarsign.circle", accessibilityDescription: "AiCash")
            button.imagePosition = .imageLeading
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
    }
    
    @objc private func updateStatusTitle() {
        if let button = statusItem?.button,
           let firstProvider = viewModel.providers.first {
            button.title = " \(firstProvider.todayUsageString)"
            button.font = NSFont.menuBarFont(ofSize: 0) // Use system menu bar font size
        }
    }
    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            showMenu(sender)
        } else {
            togglePopover(sender)
        }
    }
    
    private func showMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Show Window", action: #selector(showMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit AiCash", action: #selector(quitApp), keyEquivalent: "q"))
        
        menu.items.forEach { $0.target = self }
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }
    
    private func togglePopover(_ sender: NSStatusBarButton) {
        if let popover = popover, popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover(sender)
        }
    }
    
    private func showPopover(_ sender: NSStatusBarButton) {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: StatusMenuView(viewModel: viewModel))
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        self.popover = popover
    }
    
    @objc private func showMainWindow() {
        // Show in dock when opening main window
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Check if main window already exists
        for window in NSApp.windows {
            if window.contentViewController is NSHostingController<ContentView> {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
        
        // Create a new main window by programmatically opening the WindowGroup
        let contentView = ContentView()
        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hostingController)
        window.setContentSize(NSSize(width: 1000, height: 700))
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
