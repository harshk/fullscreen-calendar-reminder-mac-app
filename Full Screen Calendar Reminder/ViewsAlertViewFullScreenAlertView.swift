//
//  FullScreenAlertView.swift
//  Full Screen Calendar Reminder
//
//  Created by Harsh Kalra on 3/5/26.
//

import SwiftUI

struct FullScreenAlertView: View {
    let alertItem: AlertItem
    let theme: AlertTheme
    let queuePosition: Int
    let queueTotal: Int
    let isPrimaryScreen: Bool
    let onDismiss: () -> Void
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
                    .aspectRatio(contentMode: .fit)
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
            // Title
            if let style = theme.elementStyles[.title] {
                styledText(
                    text: alertItem.title,
                    style: style,
                    geometry: geometry
                )
            }
            
            // Start Time
            if let style = theme.elementStyles[.startTime] {
                styledText(
                    text: formattedTime,
                    style: style,
                    geometry: geometry
                )
            }
            
            // Location
            if let location = locationText,
               let style = theme.elementStyles[.location] {
                styledText(
                    text: location,
                    style: style,
                    geometry: geometry
                )
            }
            
            // Calendar Name
            if let style = theme.elementStyles[.calendarName] {
                styledText(
                    text: calendarNameText,
                    style: style,
                    geometry: geometry
                )
            }
            
            // Join Meeting Button
            if let videoURL = videoConferenceURL,
               let style = theme.elementStyles[.joinButton] {
                joinMeetingButton(
                    url: videoURL,
                    style: style,
                    geometry: geometry
                )
            }
            
            // Queue Counter
            if queueTotal > 1,
               let style = theme.elementStyles[.queueCounter] {
                styledText(
                    text: "\(queuePosition) of \(queueTotal)",
                    style: style,
                    geometry: geometry
                )
            }
            
            // Dismiss Button
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
            .frame(maxWidth: geometry.size.width * style.maxWidthPercentage)
            .position(
                x: geometry.size.width * style.positionX,
                y: geometry.size.height * style.positionY
            )
            .allowsHitTesting(false)
    }
    
    // MARK: - Join Meeting Button
    
    @ViewBuilder
    private func joinMeetingButton(
        url: URL,
        style: AlertElementStyle,
        geometry: GeometryProxy
    ) -> some View {
        Button(action: { onJoinMeeting(url) }) {
            Text("Join Meeting")
                .font(style.font)
                .foregroundColor(style.buttonTextColor?.color ?? .white)
                .padding(.horizontal, style.buttonPaddingHorizontal ?? 24)
                .padding(.vertical, style.buttonPaddingVertical ?? 12)
                .background(
                    RoundedRectangle(cornerRadius: style.buttonCornerRadius ?? 12)
                        .fill(style.buttonBackgroundColor?.color ?? Color(hex: "#FF1493"))
                )
        }
        .buttonStyle(.plain)
        .position(
            x: geometry.size.width * style.positionX,
            y: geometry.size.height * style.positionY
        )
    }
    
    // MARK: - Dismiss Button
    
    @ViewBuilder
    private func dismissButton(style: AlertElementStyle, geometry: GeometryProxy) -> some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: style.iconSize ?? 32, weight: .regular))
                .foregroundColor(style.iconColor?.color ?? .white.opacity(0.7))
                .frame(width: 60, height: 60)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .position(
            x: geometry.size.width * style.positionX,
            y: geometry.size.height * style.positionY
        )
    }
    
    // MARK: - Computed Properties
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: alertItem.startDate)
    }
    
    private var locationText: String? {
        switch alertItem {
        case .calendarEvent(let event):
            return event.location
        case .customReminder:
            return nil
        }
    }
    
    private var calendarNameText: String {
        switch alertItem {
        case .calendarEvent(let event):
            return event.calendar.title
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
        onJoinMeeting: { _ in }
    )
}
