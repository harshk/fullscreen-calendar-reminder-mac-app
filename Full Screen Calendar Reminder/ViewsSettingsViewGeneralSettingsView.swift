//
//  GeneralSettingsView.swift
//  Full Screen Calendar Reminder
//
//  Created by Harsh Kalra on 3/5/26.
//

import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    
    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                
                Stepper(
                    "Events in Menu Bar: \(settings.numberOfEventsInMenuBar)",
                    value: $settings.numberOfEventsInMenuBar,
                    in: 1...50
                )
            } header: {
                Text("General")
                    .font(.headline)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pause Behavior")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("When full-screen reminders are paused, alerts are silently skipped rather than queued. Events that would have fired during the pause period will not trigger alerts when you unpause.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    GeneralSettingsView()
        .frame(width: 800, height: 600)
}
