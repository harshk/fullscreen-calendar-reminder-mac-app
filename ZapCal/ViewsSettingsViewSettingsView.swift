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
    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case alerts = "Alerts"
        case calendars = "Calendars"
        case reminders = "Reminders"
        case menuBarPreset = "Menu Bar Presets"
        case presets = "Full Screen Alert Presets"
        case preAlertPresets = "Subtle Alert Presets"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: return "gear"
            case .alerts: return "bell.badge"
            case .calendars: return "calendar"
            case .reminders: return "checklist"
            case .menuBarPreset: return "menubar.rectangle"
            case .presets: return "paintbrush"
            case .preAlertPresets: return "bell.and.waves.left.and.right"
            }
        }
    }

    @State private var selectedTab: SettingsTab = .general

    private var contentWidth: CGFloat {
        switch selectedTab {
        case .presets, .preAlertPresets: return 1100
        case .menuBarPreset: return 700
        default: return 600
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(200)
        } detail: {
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .alerts:
                    AlertsSettingsView()
                case .calendars:
                    CalendarsSettingsView()
                case .reminders:
                    RemindersSettingsView()
                case .menuBarPreset:
                    MenuBarPresetSettingsView()
                case .presets:
                    PresetsSettingsView()
                case .preAlertPresets:
                    PreAlertPresetsSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: contentWidth + 200, height: 600)
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
    }
}

#Preview {
    SettingsView()
}
