//
//  SettingsView.swift
//  Full Screen Calendar Reminder
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

            // Use lazy wrappers so the heavy preset views (with cached images)
            // are only created when their tab is selected and destroyed when
            // switching away or when the settings window hides.
            LazySettingsTab { PresetsSettingsView() }
                .tabItem {
                    Label("Full Screen Alert Presets", systemImage: "paintbrush")
                }
                .tag(SettingsTab.presets)

            LazySettingsTab { PreAlertPresetsSettingsView() }
                .tabItem {
                    Label("Pre-Alert Presets", systemImage: "bell.badge")
                }
                .tag(SettingsTab.preAlertPresets)
        }
        .frame(width: (selectedTab == .presets || selectedTab == .preAlertPresets) ? 1300 : 800, height: 600)
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
    }
}

/// Wrapper that creates its content only when the tab is selected AND
/// the settings window is visible. Tears down the content (freeing cached
/// images and SwiftUI rendering state) when either condition becomes false.
struct LazySettingsTab<Content: View>: View {
    let content: () -> Content
    @State private var isTabVisible = false
    @ObservedObject private var windowState = SettingsWindowVisible.shared

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        Group {
            if isTabVisible && windowState.isVisible {
                content()
            } else {
                Color.clear
            }
        }
        .onAppear { isTabVisible = true }
        .onDisappear { isTabVisible = false }
    }
}

#Preview {
    SettingsView()
}
