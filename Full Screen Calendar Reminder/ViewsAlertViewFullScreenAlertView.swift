//
//  FullScreenAlertView.swift
//  Full Screen Calendar Reminder
//
//  Created by Harsh Kalra on 3/5/26.
//

import SwiftUI
import MapKit

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
            // Main content in a VStack so elements never overlap
            VStack(spacing: 12) {
                Spacer()

                // Title
                if let style = theme.elementStyles[.title] {
                    Text(alertItem.title)
                        .font(style.font)
                        .foregroundColor(style.fontColor.color)
                        .multilineTextAlignment(style.textAlignment)
                        .frame(maxWidth: geometry.size.width * style.maxWidthPercentage)
                }

                // Start Time
                if let style = theme.elementStyles[.startTime] {
                    Text(formattedTime)
                        .font(style.font)
                        .foregroundColor(style.fontColor.color)
                        .multilineTextAlignment(style.textAlignment)
                }

                // Location with Map
                if let location = locationText,
                   let style = theme.elementStyles[.location] {
                    VStack(spacing: 8) {
                        Text(location)
                            .font(style.font)
                            .foregroundColor(style.fontColor.color)
                            .multilineTextAlignment(style.textAlignment)
                            .frame(maxWidth: geometry.size.width * style.maxWidthPercentage)

                        LocationMapView(address: location)
                            .frame(width: 266, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .allowsHitTesting(false)
                    }
                }

                // Calendar Name
                if let style = theme.elementStyles[.calendarName] {
                    Text(calendarNameText)
                        .font(style.font)
                        .foregroundColor(style.fontColor.color)
                        .multilineTextAlignment(style.textAlignment)
                }

                // Join Meeting Button
                if let videoURL = videoConferenceURL,
                   let style = theme.elementStyles[.joinButton] {
                    Button(action: { onJoinMeeting(videoURL) }) {
                        VStack(spacing: 4) {
                            Text("Join Meeting")
                                .font(style.font)
                            if let serviceName = videoConferenceServiceName(for: videoURL) {
                                Text(serviceName)
                                    .font(.system(size: style.fontSize * 0.5, weight: .medium))
                                    .opacity(0.8)
                            }
                        }
                        .foregroundColor(style.buttonTextColor?.color ?? .white)
                        .padding(.horizontal, style.buttonPaddingHorizontal ?? 24)
                        .padding(.vertical, style.buttonPaddingVertical ?? 12)
                        .background(
                            RoundedRectangle(cornerRadius: style.buttonCornerRadius ?? 12)
                                .fill(style.buttonBackgroundColor?.color ?? Color(hex: "#FF1493"))
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Queue Counter
                if queueTotal > 1,
                   let style = theme.elementStyles[.queueCounter] {
                    Text("\(queuePosition) of \(queueTotal)")
                        .font(style.font)
                        .foregroundColor(style.fontColor.color)
                }

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
            .frame(maxWidth: geometry.size.width * style.maxWidthPercentage)
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

    private func videoConferenceServiceName(for url: URL) -> String? {
        let host = url.host?.lowercased() ?? ""
        if host.contains("zoom.us") { return "Zoom" }
        if host.contains("meet.google.com") { return "Google Meet" }
        if host.contains("teams.microsoft.com") { return "Microsoft Teams" }
        if host.contains("webex.com") { return "Webex" }
        if url.scheme == "facetime" { return "FaceTime" }
        return nil
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

// MARK: - Location Map View

struct LocationMapView: View {
    let address: String
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var annotationItems: [MapAnnotationItem] = []
    @State private var didGeocode = false

    struct MapAnnotationItem: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
    }

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: annotationItems) { item in
            MapMarker(coordinate: item.coordinate, tint: .red)
        }
        .onAppear {
            guard !didGeocode else { return }
            didGeocode = true
            let geocoder = CLGeocoder()
            geocoder.geocodeAddressString(address) { placemarks, _ in
                if let coordinate = placemarks?.first?.location?.coordinate {
                    region = MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                    )
                    annotationItems = [MapAnnotationItem(coordinate: coordinate)]
                }
            }
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
        onJoinMeeting: { _ in }
    )
}
