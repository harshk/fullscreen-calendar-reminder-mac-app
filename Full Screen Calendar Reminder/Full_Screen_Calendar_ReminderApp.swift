//
//  Full_Screen_Calendar_ReminderApp.swift
//  Full Screen Calendar Reminder
//
//  Created by Harsh Kalra on 3/5/26.
//

import SwiftUI
import SwiftData

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
        print(">>> APP INIT - Full Screen Calendar Reminder started")
    }

    var body: some Scene {
        // No window needed - we're a menu bar only app
        Settings {
            EmptyView()
        }
        .modelContainer(sharedModelContainer)
    }
}
