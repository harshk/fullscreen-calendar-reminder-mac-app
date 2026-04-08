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
    @State private var step: WelcomeStep = .permissions

    private enum WelcomeStep {
        case permissions
        case allSet
        case alertPresetPicker
        case menuBarInfo
    }

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .allSet:
                allSetContent
            case .alertPresetPicker:
                alertPresetPickerContent
            case .menuBarInfo:
                menuBarInfoContent
            default:
                permissionsContent
            }
        }
        .padding(.vertical, 20)
        .frame(width: 500, height: step == .alertPresetPicker ? 620 : 520)
        .animation(.easeInOut(duration: 0.2), value: step)
        .onChange(of: calendarService.hasAccess) { _, _ in
            checkIfAllSet()
        }
        .onChange(of: appleRemindersService.hasAccess) { _, _ in
            checkIfAllSet()
        }
    }

    // MARK: - Permissions Content

    private var permissionsContent: some View {
        VStack(spacing: 0) {
            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
                .padding(.bottom, 20)

            // Title
            Text("Welcome to ZapCal")
                .font(.custom("SF Pro Rounded", size: 36).weight(.bold))
                .padding(.bottom, 8)

            // Subtitle
            Text("Full-screen reminders for your calendar events,\nso you never miss a meeting.")
                .font(.custom("SF Pro Rounded", size: 17))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.bottom, 32)

            // Permission rows with inline buttons
            VStack(spacing: 16) {
                permissionActionRow(
                    icon: "calendar",
                    iconColor: .accentColor,
                    title: "Calendar Access",
                    description: "Required to show upcoming events and trigger alerts.",
                    granted: calendarService.hasAccess,
                    denied: calendarService.permissionDenied,
                    onGrant: { Task { try? await calendarService.requestAccess() } },
                    onOpenSettings: { openPrivacySettings(for: "Calendars") }
                )

                permissionActionRow(
                    icon: "checklist",
                    iconColor: .green,
                    title: "Reminders Access",
                    description: "Optional — alerts for Apple Reminders when they're due.",
                    granted: appleRemindersService.hasAccess,
                    denied: appleRemindersService.permissionDenied,
                    onGrant: {
                        AppSettings.shared.appleRemindersEnabled = true
                        Task { try? await appleRemindersService.requestAccess() }
                    },
                    onOpenSettings: { openPrivacySettings(for: "Reminders") }
                )
            }

            Spacer()

            Button(action: { step = .menuBarInfo }) {
                Text("Skip for now")
                    .font(.custom("SF Pro Rounded", size: 16).weight(.medium))
            }
            .controlSize(.large)
        }
    }

    private func checkIfAllSet() {
        if calendarService.hasAccess && appleRemindersService.hasAccess {
            step = .allSet
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
                .font(.custom("SF Pro Rounded", size: 36).weight(.bold))
                .padding(.bottom, 8)

            Text("ZapCal runs in your menu bar.")
                .font(.custom("SF Pro Rounded", size: 17))
                .foregroundColor(.secondary)
                .padding(.bottom, 24)

            // Menu bar illustration
            menuBarIllustration
                .padding(.horizontal, 40)

            Spacer()

            Button(action: {
                step = .alertPresetPicker
            }) {
                Text("Next")
                    .font(.custom("SF Pro Rounded", size: 16).weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Menu Bar Info Content (no permissions granted yet)

    private var menuBarInfoContent: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
                .padding(.bottom, 20)

            Text("ZapCal runs in your menu bar")
                .font(.custom("SF Pro Rounded", size: 28).weight(.bold))
                .padding(.bottom, 8)

            Text("You can grant permissions later from the menu bar.")
                .font(.custom("SF Pro Rounded", size: 18))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)

            // Menu bar illustration
            menuBarIllustration
                .padding(.horizontal, 40)

            Spacer()

            Button(action: {
                step = .alertPresetPicker
            }) {
                Text("Next")
                    .font(.custom("SF Pro Rounded", size: 16).weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Alert Preset Picker

    private enum AlertPreset: String, CaseIterable {
        case singleFullScreen
        case singleMini
        case twoAlerts
    }

    @State private var selectedPreset: AlertPreset = .singleFullScreen

    private var alertPresetPickerContent: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
                .padding(.bottom, 20)

            Text("Set Up Your Alerts")
                .font(.custom("SF Pro Rounded", size: 30).weight(.bold))
                .padding(.bottom, 6)

            Text("Choose how ZapCal notifies you about upcoming events.\nYou can change this later in Settings.")
                .font(.custom("SF Pro Rounded", size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 28)

            VStack(spacing: 20) {
                // Single alert group
                VStack(alignment: .leading, spacing: 8) {
                    Text("Single Alert")
                        .font(.custom("SF Pro Rounded", size: 14).weight(.medium))
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)

                    VStack(spacing: 10) {
                        alertPresetCard(
                            preset: .singleFullScreen,
                            title: "Zap! Alert - The Full Screen Alert",
                            description: "A full-screen Zap! alert hits when your event starts. Impossible to ignore.",
                            icons: [.fullScreen]
                        )

                        alertPresetCard(
                            preset: .singleMini,
                            title: "Mini Alert - Just a Gentle Nudge",
                            description: "A quiet alert at the top of your screen when the event starts - no drama, just a nudge.",
                            icons: [.mini]
                        )
                    }
                }

                // Multiple alerts group
                VStack(alignment: .leading, spacing: 8) {
                    Text("Multiple Alerts")
                        .font(.custom("SF Pro Rounded", size: 14).weight(.medium))
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)

                    alertPresetCard(
                        preset: .twoAlerts,
                        title: "Two Alerts — Nudge, Then Zap!",
                        description: "",
                        icons: [.mini, .fullScreen],
                        customDescription: AnyView(
                            VStack(alignment: .leading, spacing: 4) {
                                numberedRow(number: "1", text: "Starts with a mini alert nudge 1 minute before the event.")
                                numberedRow(number: "2", text: "Then we hit you with the full-screen Zap! when the event starts.")
                            }
                        )
                    )
                }
            }
            .padding(.horizontal, 40)

            Spacer()

            HStack(spacing: 16) {
                Button(action: {
                    applyAlertPreset(.singleFullScreen)
                    NotificationCenter.default.post(name: .welcomeSetupComplete, object: nil)
                    NSApp.keyWindow?.close()
                }) {
                    Text("Skip")
                        .font(.custom("SF Pro Rounded", size: 16).weight(.medium))
                }
                .controlSize(.large)

                Button(action: {
                    applyAlertPreset(selectedPreset)
                    NotificationCenter.default.post(name: .welcomeSetupComplete, object: nil)
                    NSApp.keyWindow?.close()
                }) {
                    Text("Done")
                        .font(.custom("SF Pro Rounded", size: 16).weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private func alertPresetCard(
        preset: AlertPreset,
        title: String,
        description: String,
        icons: [AlertStyle],
        customDescription: AnyView? = nil
    ) -> some View {
        let isSelected = selectedPreset == preset

        return Button(action: { selectedPreset = preset }) {
            HStack(alignment: .top, spacing: 14) {
                // Alert type icons
                VStack(spacing: 4) {
                    ForEach(icons, id: \.self) { style in
                        alertMiniIcon(style: style)
                    }
                }
                .frame(width: 48)
                .offset(y: 3)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.custom("SF Pro Rounded", size: 17).weight(.semibold))
                        .foregroundColor(.primary)
                    if let customDescription {
                        customDescription
                    } else if !description.isEmpty {
                        Text(description)
                            .font(.custom("SF Pro Rounded", size: 14))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.15), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func numberedRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.custom("SF Pro Rounded", size: 12).weight(.bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.secondary.opacity(0.5)))
                .offset(y: 2)
            Text(text)
                .font(.custom("SF Pro Rounded", size: 14))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func alertMiniIcon(style: AlertStyle) -> some View {
        Group {
            if style == .mini {
                // Mini alert banner
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 1.5) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.primary.opacity(0.4))
                            .frame(width: 24, height: 3)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 16, height: 2)
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .shadow(color: .black.opacity(0.1), radius: 1, y: 0.5)
                )
            } else {
                // Mini full screen
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color.indigo.opacity(0.6), Color.purple.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.7))
                            .frame(width: 18, height: 3)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.4))
                            .frame(width: 12, height: 2)
                    }
                }
                .frame(width: 32, height: 24)
            }
        }
    }

    private func applyAlertPreset(_ preset: AlertPreset) {
        let settings = AppSettings.shared
        switch preset {
        case .singleFullScreen:
            settings.alertConfigs = [
                AlertConfig(style: .fullScreen, leadTime: 0)
            ]
        case .singleMini:
            settings.alertConfigs = [
                AlertConfig(style: .mini, leadTime: 0, miniDuration: 300)
            ]
        case .twoAlerts:
            settings.alertConfigs = [
                AlertConfig(style: .mini, leadTime: 60, miniDuration: 15),
                AlertConfig(style: .fullScreen, leadTime: 0)
            ]
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

    // MARK: - Permission Action Row

    private func permissionActionRow(
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        granted: Bool,
        denied: Bool,
        onGrant: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : icon)
                .font(.system(size: 24))
                .foregroundColor(granted ? .green : iconColor)
                .frame(width: 32)
                .offset(y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("SF Pro Rounded", size: 18).weight(.semibold))
                Text(description)
                    .font(.custom("SF Pro Rounded", size: 15))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if granted {
                Text("Granted")
                    .font(.custom("SF Pro Rounded", size: 15).weight(.medium))
                    .foregroundColor(.green)
            } else if denied {
                Button(action: { onOpenSettings() }) {
                    Text("Open Settings")
                        .font(.custom("SF Pro Rounded", size: 16).weight(.medium))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
            } else {
                Button(action: { onGrant() }) {
                    Text("Grant")
                        .font(.custom("SF Pro Rounded", size: 16).weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: 420, alignment: .leading)
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
