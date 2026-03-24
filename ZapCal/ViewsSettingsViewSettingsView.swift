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
        case calendars = "Calendars"
        case reminders = "Reminders"
        case presets = "Alert Presets"
        case preAlertPresets = "Pre-Alert Presets"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: return "gear"
            case .calendars: return "calendar"
            case .reminders: return "checklist"
            case .presets: return "paintbrush"
            case .preAlertPresets: return "bell.badge"
            }
        }
    }

    @State private var selectedTab: SettingsTab = .general

    private var contentWidth: CGFloat {
        (selectedTab == .presets || selectedTab == .preAlertPresets) ? 1100 : 600
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
                case .calendars:
                    CalendarsSettingsView()
                case .reminders:
                    RemindersSettingsView()
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
