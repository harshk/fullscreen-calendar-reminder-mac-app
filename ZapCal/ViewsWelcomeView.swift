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
        case allSet
        case menuBarInfo
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            switch step {
            case .allSet:
                allSetContent
            case .menuBarInfo:
                menuBarInfoContent
            default:
                permissionsContent
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
                step = .allSet
            }
        }
        .onAppear {
            if calendarService.hasAccess {
                step = .reminders
            }
        }
    }

    // MARK: - Permissions Content

    private var permissionsContent: some View {
        VStack(spacing: 0) {
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
            case .allSet, .menuBarInfo:
                EmptyView()
            }
        }
    }

    // MARK: - All Set Content

    private var allSetContent: some View {
        VStack(spacing: 0) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
                .padding(.bottom, 24)

            Text("You're All Set!")
                .font(.system(size: 32, weight: .bold))
                .padding(.bottom, 8)

            Text("ZapCal runs in your menu bar.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .padding(.bottom, 24)

            // Menu bar illustration
            menuBarIllustration
                .padding(.horizontal, 40)
                .padding(.bottom, 32)

            Button(action: {
                NotificationCenter.default.post(name: .welcomeSetupComplete, object: nil)
                NSApp.keyWindow?.close()
            }) {
                Text("Got It!")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Menu Bar Info Content (no permissions granted yet)

    private var menuBarInfoContent: some View {
        VStack(spacing: 0) {
            Text("ZapCal runs in your menu bar")
                .font(.system(size: 24, weight: .bold))
                .padding(.bottom, 8)

            Text("You can grant permissions later from the menu bar.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)

            // Menu bar illustration
            menuBarIllustration
                .padding(.horizontal, 40)
                .padding(.bottom, 32)

            Button(action: {
                NotificationCenter.default.post(name: .welcomeSetupComplete, object: nil)
                NSApp.keyWindow?.close()
            }) {
                Text("Got It!")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Menu Bar Illustration

    private var menuBarIllustration: some View {
        VStack(spacing: 0) {
            // Simulated desktop with menu bar
            ZStack(alignment: .top) {
                // Desktop background
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 100)

                // Menu bar
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        // Left side — Apple menu + app menus
                        HStack(spacing: 8) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 10))
                            Text("Finder")
                                .font(.system(size: 9, weight: .semibold))
                            Text("File")
                                .font(.system(size: 9))
                            Text("Edit")
                                .font(.system(size: 9))
                        }
                        .foregroundColor(.primary.opacity(0.7))
                        .padding(.leading, 10)

                        Spacer()

                        // Right side — system icons + ZapCal icon
                        HStack(spacing: 6) {
                            Image(systemName: "wifi")
                                .font(.system(size: 8))
                                .foregroundColor(.primary.opacity(0.4))
                            Image(systemName: "battery.75percent")
                                .font(.system(size: 8))
                                .foregroundColor(.primary.opacity(0.4))

                            // ZapCal icon (highlighted)
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.accentColor.opacity(0.2))
                                    .frame(width: 22, height: 16)

                                if let icon = NSImage(named: "StatusBarIcon") {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 12, height: 12)
                                } else {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 8))
                                }
                            }
                            .foregroundColor(.accentColor)
                            .overlay(alignment: .top) {
                                VStack(spacing: 1) {
                                    handDrawnArrow
                                        .frame(width: 20, height: 24)
                                    Text("ZapCal lives here")
                                        .font(.custom("Marker Felt", size: 12))
                                        .foregroundColor(.red)
                                        .fixedSize()
                                }
                                .offset(y: 22)
                            }

                            Text("9:41")
                                .font(.system(size: 9))
                                .foregroundColor(.primary.opacity(0.4))
                        }
                        .padding(.trailing, 10)
                    }
                    .frame(height: 20)
                    .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )

            // Space for the overlay arrow + text
            Spacer().frame(height: 36)
        }
    }

    // MARK: - Hand-drawn Arrow

    private var handDrawnArrow: some View {
        Canvas { context, size in
            var path = Path()
            let midX = size.width / 2

            // Slightly wobbly line going up
            path.move(to: CGPoint(x: midX + 1, y: size.height))
            path.addCurve(
                to: CGPoint(x: midX - 1, y: 6),
                control1: CGPoint(x: midX + 3, y: size.height * 0.6),
                control2: CGPoint(x: midX - 3, y: size.height * 0.3)
            )

            // Left arrowhead stroke
            path.move(to: CGPoint(x: midX - 1, y: 6))
            path.addCurve(
                to: CGPoint(x: midX - 7, y: 14),
                control1: CGPoint(x: midX - 2, y: 8),
                control2: CGPoint(x: midX - 5, y: 11)
            )

            // Right arrowhead stroke
            path.move(to: CGPoint(x: midX - 1, y: 6))
            path.addCurve(
                to: CGPoint(x: midX + 7, y: 12),
                control1: CGPoint(x: midX + 1, y: 8),
                control2: CGPoint(x: midX + 5, y: 10)
            )

            context.stroke(path, with: .color(.red), lineWidth: 2.5)
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

                HStack(spacing: 12) {
                    Button(action: { openPrivacySettings(for: "Calendars") }) {
                        Text("Open System Settings")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 160)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(action: { step = .menuBarInfo }) {
                        Text("Skip")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 80)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        } else {
            VStack(spacing: 12) {
                Button(action: { Task { try? await calendarService.requestAccess() } }) {
                    Text("Grant Calendar Access")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: { step = .menuBarInfo }) {
                    Text("Skip for now")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
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

                    Button(action: { step = .menuBarInfo }) {
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

                Button(action: { step = .allSet }) {
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
