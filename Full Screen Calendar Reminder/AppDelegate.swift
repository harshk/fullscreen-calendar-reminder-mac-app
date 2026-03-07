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
    private var popover: NSPopover?
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
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Setup popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 350, height: 500)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MenuBarView())
        
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
    
    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        
        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
}

