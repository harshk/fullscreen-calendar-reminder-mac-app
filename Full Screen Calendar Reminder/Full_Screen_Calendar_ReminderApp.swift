//
//  Full_Screen_Calendar_ReminderApp.swift
//  Full Screen Calendar Reminder
//
//  Created by Harsh Kalra on 3/5/26.
//

import SwiftUI
import SwiftData
import CoreText

@main
struct Full_Screen_Calendar_ReminderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CustomReminder.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Disable automatic SF Symbol icons in menus (macOS Tahoe+)
        UserDefaults.standard.set(false, forKey: "NSMenuEnableActionImages")

        // Register bundled fonts
        Self.registerBundledFonts()

        print(">>> APP INIT - Full Screen Calendar Reminder started")
    }

    private static func registerBundledFonts() {
        // Register all .ttf and .otf files found in the bundle
        for ext in ["ttf", "otf"] {
            if let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
                for url in urls {
                    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
                }
            }
        }
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .modelContainer(sharedModelContainer)
    }
}
