//
//  FullScreenAlertView.swift
//  Full Screen Calendar Reminder
//
//  Created by Harsh Kalra on 3/5/26.
//

import SwiftUI
// import MapKit  // Removed: MapKit uses too much memory for a menu bar app

struct FullScreenAlertView: View {
    let alertItem: AlertItem
    let theme: AlertTheme
    let queuePosition: Int
    let queueTotal: Int
    let isPrimaryScreen: Bool
    let onDismiss: () -> Void
    let onSnooze: (TimeInterval) -> Void
    let onJoinMeeting: (URL) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                backgroundView

                if isPrimaryScreen {
                    // Full content on primary screen
                    primaryScreenContent(geometry: geometry)
                } else {
                    // Simplified content on secondary screens
                    secondaryScreenContent(geometry: geometry)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Background
    
    @ViewBuilder
    private var backgroundView: some View {
        switch theme.backgroundType {
        case .solidColor:
            theme.solidColor.color
                .opacity(theme.solidColorOpacity)
        case .image:
            if let imageData = theme.imageData,
               let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .clipped()
                    .overlay(
                        theme.overlayColor.color
                            .opacity(theme.overlayOpacity)
                    )
            } else {
                theme.solidColor.color
                    .opacity(theme.solidColorOpacity)
            }
        }
    }
    
    // MARK: - Primary Screen Content
    
    @ViewBuilder
    private func primaryScreenContent(geometry: GeometryProxy) -> some View {
        ZStack {
            // Main content in a VStack so elements never overlap
            VStack(spacing: 12) {
                Spacer()

                // Title
                if let style = theme.elementStyles[.title] {
                    Text(alertItem.title)
                        .font(style.font)
                        .foregroundColor(style.fontColor.color)
                        .textCase(style.uppercased == true ? .uppercase : nil)
                        .scaleEffect(x: 1.0, y: style.verticalScale ?? 1.0)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .truncationMode(.tail)
                        .frame(maxWidth: geometry.size.width * 0.9, alignment: style.frameAlignment)
                }

                // Start Time
                if let style = theme.elementStyles[.startTime] {
                    Text(formattedTime)
                        .font(style.font)
                        .foregroundColor(style.fontColor.color)
                        .textCase(style.uppercased == true ? .uppercase : nil)
                        .scaleEffect(x: 1.0, y: style.verticalScale ?? 1.0)
                        .multilineTextAlignment(style.textAlignment)
                        .frame(maxWidth: geometry.size.width * 0.9, alignment: style.frameAlignment)
                }

                // Location (clickable — opens in Apple Maps)
                if let location = locationText,
                   let style = theme.elementStyles[.location] {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: style.fontSize * 0.8))
                        Text(location)
                            .font(style.font)
                            .textCase(style.uppercased == true ? .uppercase : nil)
                    }
                    .foregroundColor(style.fontColor.color)
                    .scaleEffect(x: 1.0, y: style.verticalScale ?? 1.0)
                    .multilineTextAlignment(style.textAlignment)
                    .frame(maxWidth: geometry.size.width * 0.9, alignment: style.frameAlignment)
                    .onTapGesture {
                        if let encoded = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                           let url = URL(string: "maps://?q=\(encoded)") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }

                // Calendar Name
                if let style = theme.elementStyles[.calendarName] {
                    Text(calendarNameText)
                        .font(style.font)
                        .foregroundColor(style.fontColor.color)
                        .textCase(style.uppercased == true ? .uppercase : nil)
                        .scaleEffect(x: 1.0, y: style.verticalScale ?? 1.0)
                        .multilineTextAlignment(style.textAlignment)
                        .frame(maxWidth: geometry.size.width * 0.9, alignment: style.frameAlignment)
                }

                // Join Meeting Button
                if let videoURL = videoConferenceURL,
                   let style = theme.elementStyles[.joinButton] {
                    Text(joinMeetingLabel(for: videoURL))
                        .font(style.font)
                        .textCase(style.uppercased == true ? .uppercase : nil)
                        .scaleEffect(x: 1.0, y: style.verticalScale ?? 1.0)
                    .foregroundColor(style.fontColor.color)
                    .padding(.horizontal, style.buttonPaddingHorizontal ?? 24)
                    .padding(.vertical, style.buttonPaddingVertical ?? 12)
                    .background(
                        RoundedRectangle(cornerRadius: style.buttonCornerRadius ?? 12)
                            .fill(style.buttonBackgroundColor?.color ?? Color(hex: "#FF1493"))
                    )
                    .contentShape(RoundedRectangle(cornerRadius: style.buttonCornerRadius ?? 12))
                    .onTapGesture {
                        DispatchQueue.main.async {
                            NSWorkspace.shared.open(videoURL)
                        }
                        onDismiss()
                    }
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                    .frame(maxWidth: geometry.size.width * 0.9, alignment: style.frameAlignment)
                }

                // Queue Counter
                if queueTotal > 1,
                   let style = theme.elementStyles[.queueCounter] {
                    Text("\(queuePosition) of \(queueTotal)")
                        .font(style.font)
                        .foregroundColor(style.fontColor.color)
                        .textCase(style.uppercased == true ? .uppercase : nil)
                        .scaleEffect(x: 1.0, y: style.verticalScale ?? 1.0)
                        .frame(maxWidth: geometry.size.width * 0.9, alignment: style.frameAlignment)
                }

                // Snooze buttons
                snoozeButtons

                Spacer()
            }
            .frame(maxWidth: .infinity)

            // Dismiss Button (stays in ZStack for absolute positioning)
            if let style = theme.elementStyles[.dismissButton] {
                dismissButton(style: style, geometry: geometry)
            }
        }
    }
    
    // MARK: - Secondary Screen Content
    
    @ViewBuilder
    private func secondaryScreenContent(geometry: GeometryProxy) -> some View {
        ZStack {
            // Only show title on secondary screens
            if let style = theme.elementStyles[.title] {
                styledText(
                    text: alertItem.title,
                    style: style,
                    geometry: geometry
                )
            }
        }
    }
    
    // MARK: - Styled Text Element
    
    @ViewBuilder
    private func styledText(
        text: String,
        style: AlertElementStyle,
        geometry: GeometryProxy
    ) -> some View {
        Text(text)
            .font(style.font)
            .foregroundColor(style.fontColor.color)
            .multilineTextAlignment(style.textAlignment)
            .frame(maxWidth: geometry.size.width * 0.9)
            .position(
                x: geometry.size.width * style.positionX,
                y: geometry.size.height * style.positionY
            )
            .allowsHitTesting(false)
    }
    
    // MARK: - Dismiss Button
    
    @ViewBuilder
    private func dismissButton(style: AlertElementStyle, geometry: GeometryProxy) -> some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: (style.iconSize ?? 32) * 0.5, weight: .semibold))
                .foregroundColor(style.iconColor?.color ?? .white.opacity(0.9))
                .frame(width: style.iconSize ?? 32, height: style.iconSize ?? 32)
                .background(
                    Circle()
                        .fill(style.buttonBackgroundColor?.color ?? Color.white.opacity(0.2))
                )
                .clipShape(Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .position(
            x: geometry.size.width * style.positionX,
            y: (style.iconSize ?? 32) * 2 + (style.iconSize ?? 32) / 2
        )
    }

    // MARK: - Snooze Buttons

    private var snoozeButtons: some View {
        HStack(spacing: 12) {
            ForEach(AppSettings.shared.snoozeDurations, id: \.self) { duration in
                Text(snoozeLabel(for: duration))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.15))
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                    .onTapGesture {
                        onSnooze(duration)
                    }
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
            }
        }
    }

    private func snoozeLabel(for seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 60 {
            return "Snooze \(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "Snooze \(hours)h"
            }
            return "Snooze \(hours)h \(remainingMinutes)m"
        }
    }

    // MARK: - Computed Properties
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let start = formatter.string(from: alertItem.startDate)
        if let endDate = alertItem.endDate {
            let end = formatter.string(from: endDate)
            return "\(start) – \(end)"
        }
        return start
    }
    
    private var locationText: String? {
        switch alertItem {
        case .calendarEvent(let event):
            guard let location = event.location, !location.isEmpty else { return nil }
            // Don't show the location if it's just a video conference URL
            if let url = URL(string: location), CalendarEvent.isVideoConferenceURL(url) {
                return nil
            }
            // Also check if the location contains a video conference URL as part of the text
            if CalendarEvent.findVideoConferenceURL(in: location) != nil,
               location.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("http") {
                return nil
            }
            return location
        case .customReminder:
            return nil
        }
    }
    
    private var calendarNameText: String {
        switch alertItem {
        case .calendarEvent(let event):
            return "Calendar: \(event.calendar.title)"
        case .customReminder:
            return "Custom Reminder"
        }
    }
    
    private var videoConferenceURL: URL? {
        switch alertItem {
        case .calendarEvent(let event):
            return event.videoConferenceURL
        case .customReminder:
            return nil
        }
    }

    private func videoConferenceServiceName(for url: URL) -> String? {
        let resolvedURL = unwrapRedirectURL(url)
        let host = resolvedURL.host?.lowercased() ?? ""
        let scheme = resolvedURL.scheme?.lowercased() ?? ""
        if host.contains("zoom.us") || scheme == "zoommtg" || scheme == "zoomus" { return "Zoom" }
        if host.contains("meet.google.com") { return "Google Meet" }
        if host.contains("teams.microsoft.com") || host.contains("teams.live.com") { return "Microsoft Teams" }
        if host.contains("webex.com") { return "Webex" }
        if scheme == "facetime" { return "FaceTime" }
        return nil
    }

    /// Unwraps Google Calendar redirect URLs to get the actual destination URL.
    private func unwrapRedirectURL(_ url: URL) -> URL {
        guard let host = url.host?.lowercased(),
              host.contains("google.com"),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let destination = components.queryItems?.first(where: { $0.name == "q" })?.value,
              let innerURL = URL(string: destination) else {
            return url
        }
        return innerURL
    }

    private func joinMeetingLabel(for url: URL) -> String {
        if let serviceName = videoConferenceServiceName(for: url) {
            return "Join Meeting: \(serviceName)"
        }
        return "Join Meeting"
    }
}

// MARK: - AlertElementStyle Font Extension

extension AlertElementStyle {
    var font: Font {
        let baseFont: Font

        // Try to use custom font family
        if fontFamily != "SF Pro" && fontFamily != "System" {
            baseFont = .custom(fontFamily, size: fontSize)
        } else {
            baseFont = .system(size: fontSize)
        }

        // Apply weight
        return baseFont.weight(fontWeight)
    }

    var frameAlignment: Alignment {
        switch textAlignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}


// MARK: - Preview

#Preview {
    FullScreenAlertView(
        alertItem: .calendarEvent(CalendarEvent.mock()),
        theme: AlertTheme.defaultTheme(),
        queuePosition: 1,
        queueTotal: 1,
        isPrimaryScreen: true,
        onDismiss: {},
        onSnooze: { _ in },
        onJoinMeeting: { _ in }
    )
}
