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
    @ObservedObject private var appleRemindersService = AppleRemindersService.shared
    @State private var step: WelcomeStep = .calendar

    private enum WelcomeStep {
        case calendar
        case reminders
    }

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

            // Permission explanations
            VStack(spacing: 12) {
                permissionRow(
                    icon: "calendar",
                    iconColor: .accentColor,
                    title: "Calendar Access Required",
                    description: "ZapCal needs access to your calendars to show upcoming events and trigger full-screen alerts.",
                    granted: calendarService.hasAccess
                )

                permissionRow(
                    icon: "checklist",
                    iconColor: .green,
                    title: "Reminders Access (Optional)",
                    description: "Enable full-screen alerts for your Apple Reminders when they're due.",
                    granted: appleRemindersService.hasAccess
                )
            }
            .padding(.bottom, 32)

            // Action buttons based on current step
            switch step {
            case .calendar:
                calendarStepButtons
            case .reminders:
                remindersStepButtons
            }

            Spacer()
        }
        .frame(width: 500, height: 520)
        .onChange(of: calendarService.hasAccess) { _, hasAccess in
            if hasAccess {
                step = .reminders
            }
        }
        .onChange(of: appleRemindersService.hasAccess) { _, hasAccess in
            if hasAccess {
                NSApp.keyWindow?.close()
            }
        }
        .onAppear {
            if calendarService.hasAccess {
                step = .reminders
            }
        }
    }

    // MARK: - Permission Row

    private func permissionRow(icon: String, iconColor: Color, title: String, description: String, granted: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : icon)
                .font(.system(size: 24))
                .foregroundColor(granted ? .green : iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: 380, alignment: .leading)
    }

    // MARK: - Calendar Step

    @ViewBuilder
    private var calendarStepButtons: some View {
        if calendarService.permissionDenied {
            VStack(spacing: 12) {
                Text("Calendar access was denied. Please grant access in System Settings.")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)

                Button(action: { openPrivacySettings(for: "Calendars") }) {
                    Text("Open System Settings")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        } else {
            Button(action: { Task { try? await calendarService.requestAccess() } }) {
                Text("Grant Calendar Access")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Reminders Step

    @ViewBuilder
    private var remindersStepButtons: some View {
        if appleRemindersService.permissionDenied {
            VStack(spacing: 12) {
                Text("Reminders access was denied. You can enable it later in Settings.")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button(action: { openPrivacySettings(for: "Reminders") }) {
                        Text("Open System Settings")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 160)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(action: { NSApp.keyWindow?.close() }) {
                        Text("Skip")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 80)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        } else {
            HStack(spacing: 12) {
                Button(action: {
                    AppSettings.shared.appleRemindersEnabled = true
                    Task { try? await appleRemindersService.requestAccess() }
                }) {
                    Text("Grant Reminders Access")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: { NSApp.keyWindow?.close() }) {
                    Text("Skip")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 80)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    // MARK: - Helpers

    private func openPrivacySettings(for category: String) {
        if #available(macOS 13.0, *) {
            if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_\(category)") {
                NSWorkspace.shared.open(url)
                return
            }
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_\(category)") {
            NSWorkspace.shared.open(url)
        }
    }
}
