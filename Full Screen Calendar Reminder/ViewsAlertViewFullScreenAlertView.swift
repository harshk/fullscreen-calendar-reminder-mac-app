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
    var onElementTap: ((AlertElementIdentifier?) -> Void)? = nil

    @State private var contentOpacity: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                backgroundView
                    .onTapGesture {
                        onElementTap?(nil) // nil = background selected
                    }

                if isPrimaryScreen {
                    // Full content on primary screen
                    primaryScreenContent(geometry: geometry)
                        .opacity(contentOpacity)
                        .animation(.easeIn(duration: 1.0), value: contentOpacity)
                } else {
                    // Simplified content on secondary screens
                    secondaryScreenContent(geometry: geometry)
                        .opacity(contentOpacity)
                        .animation(.easeIn(duration: 1.0), value: contentOpacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                contentOpacity = 1.0
            }
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
            if let imageFileName = theme.imageFileName,
               let nsImage = ImageStore.load(imageFileName) {
                GeometryReader { geo in
                    let blurRadius = (theme.imageBlurRadius ?? 0.3) * 50
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: blurRadius)
                        .frame(width: geo.size.width + blurRadius * 2, height: geo.size.height + blurRadius * 2)
                        .clipped()
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                .ignoresSafeArea()
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
            VStack(spacing: 0) {
                Spacer()

                // Title
                if let style = theme.elementStyles[.title] {
                    Text(alertItem.title)
                        .font(style.font)
                        .tracking(style.letterSpacing ?? 0)
                        .foregroundColor(style.fontColor.color)
                        .textCase(style.uppercased == true ? .uppercase : nil)
                        .scaleEffect(x: 1.0, y: style.verticalScale ?? 1.0)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                        .truncationMode(.tail)
                        .frame(maxWidth: geometry.size.width * 0.5, alignment: .center)
                        .contentShape(Rectangle())
                        .onTapGesture { onElementTap?(.title) }
                }

                // Start Time
                if let style = theme.elementStyles[.startTime] {
                    Text(formattedTime)
                        .font(style.font)
                        .tracking(style.letterSpacing ?? 0)
                        .foregroundColor(style.fontColor.color)
                        .textCase(style.uppercased == true ? .uppercase : nil)
                        .scaleEffect(x: 1.0, y: style.verticalScale ?? 1.0)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: geometry.size.width * 0.9, alignment: .center)
                        .contentShape(Rectangle())
                        .onTapGesture { onElementTap?(.startTime) }
                }
                
                // Calendar Name
                if let style = theme.elementStyles[.calendarName] {
                    Text(calendarNameText)
                        .font(style.font)
                        .tracking(style.letterSpacing ?? 0)
                        .foregroundColor(style.fontColor.color)
                        .textCase(style.uppercased == true ? .uppercase : nil)
                        .scaleEffect(x: 1.0, y: style.verticalScale ?? 1.0)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: geometry.size.width * 0.9, alignment: .center)
                        .contentShape(Rectangle())
                        .onTapGesture { onElementTap?(.calendarName) }
//                        .padding(.top, 18)
                }
                
                Spacer()
                        .frame(height: 72)

                // Location (clickable — opens in Apple Maps)
                if let location = locationText,
                   let style = theme.elementStyles[.location] {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: style.fontSize * 0.8))
                        Text(location)
                            .font(style.font)
                            .tracking(style.letterSpacing ?? 0)
                            .textCase(style.uppercased == true ? .uppercase : nil)
                    }
                    .foregroundColor(style.fontColor.color)
                    .scaleEffect(x: 1.0, y: style.verticalScale ?? 1.0)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: geometry.size.width * 0.9, alignment: .center)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let onElementTap = onElementTap {
                            onElementTap(.location)
                        } else if let encoded = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                           let url = URL(string: "maps://?q=\(encoded)") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .onHover { hovering in
                        if onElementTap == nil {
                            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                    }
                }

                // Join Meeting Button
                if let videoURL = videoConferenceURL,
                   let style = theme.elementStyles[.joinButton] {
                    Text(joinMeetingLabel(for: videoURL))
                        .font(style.font)
                        .tracking(style.letterSpacing ?? 0)
                        .textCase(style.uppercased == true ? .uppercase : nil)
                        .scaleEffect(x: 1.0, y: style.verticalScale ?? 1.0)
                    .foregroundColor(style.fontColor.color)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(style.buttonBackgroundColor?.color ?? Color(hex: "#FF1493"))
                    )
                    .contentShape(Capsule())
                    .onTapGesture {
                        if let onElementTap = onElementTap {
                            onElementTap(.joinButton)
                        } else {
                            DispatchQueue.main.async {
                                NSWorkspace.shared.open(videoURL)
                            }
                            onDismiss()
                        }
                    }
                    .padding(.top, 18)
                    .onHover { hovering in
                        if onElementTap == nil {
                            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                    }
                    .frame(maxWidth: geometry.size.width * 0.9, alignment: .center)
                }

                // Queue Counter
                if queueTotal > 1,
                   let style = theme.elementStyles[.queueCounter] {
                    Text("\(queuePosition) of \(queueTotal)")
                        .font(style.font)
                        .tracking(style.letterSpacing ?? 0)
                        .foregroundColor(style.fontColor.color)
                        .textCase(style.uppercased == true ? .uppercase : nil)
                        .scaleEffect(x: 1.0, y: style.verticalScale ?? 1.0)
                        .frame(maxWidth: geometry.size.width * 0.9, alignment: .center)
                        .contentShape(Rectangle())
                        .onTapGesture { onElementTap?(.queueCounter) }
                }

                // Snooze buttons
                snoozeButtons
//                    .padding(.top, 72)
                    .padding(.top, 18)

                Spacer()
            }
            .frame(maxWidth: .infinity)

            // Dismiss Button (stays in ZStack for absolute positioning)
            dismissButton(geometry: geometry)
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
            .multilineTextAlignment(.center)
            .frame(maxWidth: geometry.size.width * 0.9)
            .position(
                x: geometry.size.width * 0.5,
                y: geometry.size.height * 0.5
            )
            .allowsHitTesting(false)
    }
    
    // MARK: - Dismiss Button
    
    @ViewBuilder
    private func dismissButton(geometry: GeometryProxy) -> some View {
        let style = theme.elementStyles[.dismissButton]
        let size: CGFloat = style?.iconSize ?? 32
        let iconColor = style?.iconColor?.color ?? Color.white.opacity(0.7)
        let bgColor = style?.buttonBackgroundColor?.color ?? Color.white.opacity(0.2)
        Button(action: { if let onElementTap = onElementTap { onElementTap(.dismissButton) } else { onDismiss() } }) {
            Image(systemName: "xmark")
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(bgColor)
                )
                .clipShape(Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .position(
            x: geometry.size.width * 0.05,
            y: size * 2 + size / 2
        )
    }

    // MARK: - Snooze Buttons

    private var snoozeButtons: some View {
        let style = theme.elementStyles[.snoozeButton]
        let font = style?.font ?? .system(size: 14, weight: .medium)
        let tracking = style?.letterSpacing ?? 0
        let textColor = style?.fontColor.color ?? .white.opacity(0.9)
        let bgColor = style?.buttonBackgroundColor?.color ?? Color.white.opacity(0.15)
        let isUppercased = style?.uppercased == true

        return HStack(spacing: 12) {
            ForEach(AppSettings.shared.snoozeDurations, id: \.self) { duration in
                HStack(spacing: 6) {
                    Image(systemName: "bell.badge")
                        .imageScale(.small)
                    Text(snoozeLabel(for: duration))
                        .tracking(tracking)
                        .textCase(isUppercased ? .uppercase : nil)
                }
                    .font(font)
                    .foregroundColor(textColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(bgColor)
                    )
                    .contentShape(Capsule())
                    .onTapGesture {
                        if let onElementTap = onElementTap {
                            onElementTap(.snoozeButton)
                        } else {
                            onSnooze(duration)
                        }
                    }
                    .onHover { hovering in
                        if onElementTap == nil {
                            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
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
        let traits: NSFontTraitMask = italic == true ? .italicFontMask : []

        if fontFamily != "SF Pro" && fontFamily != "System" {
            // For custom fonts, find the specific variant matching the requested weight
            if let nsFont = NSFontManager.shared.font(
                withFamily: fontFamily,
                traits: traits,
                weight: fontWeight.nsFontWeight,
                size: fontSize
            ) {
                return Font(nsFont)
            }
            // Fallback: use .custom which only gives the regular weight
            return .custom(fontFamily, size: fontSize)
        }

        var f = Font.system(size: fontSize).weight(fontWeight)
        if italic == true { f = f.italic() }
        return f
    }

}

extension Font.Weight {
    /// Map SwiftUI Font.Weight to NSFontManager weight (0–15 scale).
    var nsFontWeight: Int {
        switch self {
        case .ultraLight: return 1
        case .thin:       return 2
        case .light:      return 3
        case .regular:    return 5
        case .medium:     return 6
        case .semibold:   return 8
        case .bold:       return 12
        case .heavy:      return 12
        case .black:      return 12
        default:          return 5
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
