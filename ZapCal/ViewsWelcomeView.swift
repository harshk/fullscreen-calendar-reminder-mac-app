//
//  WelcomeView.swift
//  ZapCal
//
//  Created by Harsh Kalra on 3/24/26.
//

import SwiftUI
import EventKit

struct WelcomeView: View {
    @ObservedObject private var calendarService = CalendarService.shared
    @State private var permissionDenied = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)
                .padding(.bottom, 24)

            // Title
            Text("Welcome to ZapCal")
                .font(.system(size: 32, weight: .bold))
                .padding(.bottom, 8)

            // Subtitle
            Text("Full-screen reminders for your calendar events,\nso you never miss a meeting.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.bottom, 32)

            // Permission explanation
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Calendar Access Required")
                            .font(.system(size: 14, weight: .semibold))
                        Text("ZapCal needs access to your calendars to show upcoming events and trigger full-screen alerts.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: 380, alignment: .leading)
            }
            .padding(.bottom, 32)

            if permissionDenied {
                VStack(spacing: 12) {
                    Text("Calendar access was denied. Please grant access in System Settings.")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)

                    Button(action: openCalendarPrivacySettings) {
                        Text("Open System Settings")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 200)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            } else {
                Button(action: requestPermission) {
                    Text("Grant Calendar Access")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Spacer()
        }
        .frame(width: 500, height: 460)
        .onChange(of: calendarService.hasAccess) { _, hasAccess in
            if hasAccess {
                NSApp.keyWindow?.close()
            }
        }
    }

    private func requestPermission() {
        Task {
            do {
                try await calendarService.requestAccess()
                if !calendarService.hasAccess {
                    permissionDenied = true
                }
            } catch {
                permissionDenied = true
            }
        }
    }

    private func openCalendarPrivacySettings() {
        if #available(macOS 13.0, *) {
            if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Calendars") {
                NSWorkspace.shared.open(url)
                return
            }
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}
