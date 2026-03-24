//
//  SettingsView.swift
//  ZapCal
//
//  Created by Harsh Kalra on 3/5/26.
//

import SwiftUI
import Combine

/// Tracks whether the settings window is currently visible.
/// LazySettingsTab observes this to tear down heavy views when the window hides.
class SettingsWindowVisible: ObservableObject {
    static let shared = SettingsWindowVisible()
    @Published var isVisible = false
}

struct SettingsView: View {
    enum SettingsTab: Hashable {
        case general
        case calendars
        case reminders
        case presets
        case preAlertPresets
    }

    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(SettingsTab.general)

            CalendarsSettingsView()
                .tabItem {
                    Label("Calendars", systemImage: "calendar")
                }
                .tag(SettingsTab.calendars)

            RemindersSettingsView()
                .tabItem {
                    Label("Reminders", systemImage: "checklist")
                }
                .tag(SettingsTab.reminders)

            PresetsSettingsView()
                .tabItem {
                    Label("Full Screen Alert Presets", systemImage: "paintbrush")
                }
                .tag(SettingsTab.presets)

            PreAlertPresetsSettingsView()
                .tabItem {
                    Label("Pre-Alert Presets", systemImage: "bell.badge")
                }
                .tag(SettingsTab.preAlertPresets)
        }
        .frame(width: (selectedTab == .presets || selectedTab == .preAlertPresets) ? 1300 : 800, height: 600)
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
    }
}

#Preview {
    SettingsView()
}
