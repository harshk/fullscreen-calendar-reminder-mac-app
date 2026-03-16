//
//  SettingsView.swift
//  Full Screen Calendar Reminder
//
//  Created by Harsh Kalra on 3/5/26.
//

import SwiftUI

struct SettingsView: View {
    enum SettingsTab: Hashable {
        case general
        case calendars
        case presets
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

            PresetsSettingsView()
                .tabItem {
                    Label("Presets", systemImage: "paintbrush")
                }
                .tag(SettingsTab.presets)
        }
        .frame(width: selectedTab == .presets ? 1300 : 800, height: 600)
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
    }
}

#Preview {
    SettingsView()
}
