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
        case appearance
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

            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
                .tag(SettingsTab.appearance)
        }
        .frame(width: 800, height: 600)
    }
}

#Preview {
    SettingsView()
}
