//
//  AppDelegate.swift
//  Full Screen Calendar Reminder
//
//  Created by Harsh Kalra on 3/5/26.
//

import Cocoa
import SwiftUI
import SwiftData
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var eventMonitor: Any?
    var modelContainer: ModelContainer!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("App launched")

        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Get model container from the app
        if let app = NSApp.delegate as? AppDelegate,
           let container = try? ModelContainer(for: Schema([CustomReminder.self])) {
            self.modelContainer = container
        }
        
        // Setup menu bar
        setupMenuBar()
        
        // Request calendar access
        Task { @MainActor in
            do {
                try await CalendarService.shared.requestAccess()
            } catch {
                print("Failed to request calendar access: \(error)")
            }
        }
        
        // Setup reminder service with model context
        if let container = modelContainer {
            Task { @MainActor in
                let context = container.mainContext
                ReminderService.shared.setModelContext(context)
            }
        }
    }
    
    // MARK: - Menu Bar Setup
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            updateMenuBarIcon()
            button.action = #selector(togglePanel)
            button.target = self
        }

        // Setup panel
        let contentSize = NSSize(width: 350, height: 500)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        let hostingView = NSHostingView(rootView:
            MenuBarView()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        )
        hostingView.frame = NSRect(origin: .zero, size: contentSize)
        panel.contentView = hostingView
        self.panel = panel
        
        // Observe dismiss popover requests
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDismissPopover),
            name: .dismissPopover,
            object: nil
        )

        // Observe pause state changes to update icon
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenuBarIcon),
            name: NSNotification.Name("PauseStateChanged"),
            object: nil
        )
        
        // Update icon when settings change
        AppSettings.shared.$isPaused
            .sink { [weak self] _ in
                self?.updateMenuBarIcon()
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    @objc private func updateMenuBarIcon() {
        if let button = statusItem?.button {
            let isPaused = AppSettings.shared.isPaused
            let iconName = isPaused ? "bell.slash.fill" : "bell.fill"
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Full Screen Calendar Reminder")
        }
    }
    
    @objc private func handleDismissPopover() {
        closePanel()
    }

    @objc private func togglePanel() {
        guard let panel = panel, let button = statusItem?.button else { return }

        if panel.isVisible {
            closePanel()
        } else {
            let buttonFrame = button.window!.convertToScreen(button.convert(button.bounds, to: nil))
            let panelSize = panel.frame.size
            let x = buttonFrame.midX - panelSize.width / 2
            let y = buttonFrame.minY - panelSize.height - 4
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            panel.orderFrontRegardless()
            startEventMonitor()
        }
    }

    private func closePanel() {
        panel?.orderOut(nil)
        stopEventMonitor()
    }

    private func startEventMonitor() {
        stopEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

