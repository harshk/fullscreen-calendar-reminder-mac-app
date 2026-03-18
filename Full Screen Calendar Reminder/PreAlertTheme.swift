//
//  PreAlertTheme.swift
//  Full Screen Calendar Reminder
//

import Foundation
import SwiftUI

// MARK: - Pre-Alert Theme

struct PreAlertTheme: Codable, Identifiable {
    var id: String
    var name: String

    // Banner background
    var backgroundType: BackgroundType
    var backgroundColor: CodableColor
    var backgroundOpacity: Double
    var imageData: Data?
    var overlayColor: CodableColor
    var overlayOpacity: Double
    var imageBlurRadius: Double?

    // Title
    var titleColor: CodableColor

    // Countdown
    var countdownColor: CodableColor

    // Dismiss button
    var dismissButtonColor: CodableColor
    var dismissIconColor: CodableColor
    var progressRingColor: CodableColor

    // Disable alerts button
    var disableButtonTextColor: CodableColor
    var disableButtonBackgroundColor: CodableColor

    // Join button
    var joinButtonTextColor: CodableColor
    var joinButtonBackgroundColor: CodableColor

    enum BackgroundType: String, Codable {
        case solidColor
        case image
    }

    init(id: String, name: String, backgroundType: BackgroundType = .solidColor,
         backgroundColor: CodableColor, backgroundOpacity: Double,
         imageData: Data? = nil, overlayColor: CodableColor = CodableColor(.black),
         overlayOpacity: Double = 0.3, imageBlurRadius: Double? = 0.3,
         titleColor: CodableColor, countdownColor: CodableColor,
         dismissButtonColor: CodableColor, dismissIconColor: CodableColor,
         progressRingColor: CodableColor,
         disableButtonTextColor: CodableColor, disableButtonBackgroundColor: CodableColor,
         joinButtonTextColor: CodableColor, joinButtonBackgroundColor: CodableColor) {
        self.id = id
        self.name = name
        self.backgroundType = backgroundType
        self.backgroundColor = backgroundColor
        self.backgroundOpacity = backgroundOpacity
        self.imageData = imageData
        self.overlayColor = overlayColor
        self.overlayOpacity = overlayOpacity
        self.imageBlurRadius = imageBlurRadius
        self.titleColor = titleColor
        self.countdownColor = countdownColor
        self.dismissButtonColor = dismissButtonColor
        self.dismissIconColor = dismissIconColor
        self.progressRingColor = progressRingColor
        self.disableButtonTextColor = disableButtonTextColor
        self.disableButtonBackgroundColor = disableButtonBackgroundColor
        self.joinButtonTextColor = joinButtonTextColor
        self.joinButtonBackgroundColor = joinButtonBackgroundColor
    }

    // MARK: - Default Theme

    static func defaultTheme(id: String = "default", name: String = "Rose Cream") -> PreAlertTheme {
        let cream = CodableColor(Color(red: 1.0, green: 0.96, blue: 0.88))
        let pink = CodableColor(Color(red: 0.91, green: 0.28, blue: 0.42))

        return PreAlertTheme(
            id: id,
            name: name,
            backgroundColor: pink,
            backgroundOpacity: 0.95,
            titleColor: cream,
            countdownColor: CodableColor(Color(red: 1.0, green: 0.96, blue: 0.88).opacity(0.7)),
            dismissButtonColor: CodableColor(Color(red: 0.78, green: 0.22, blue: 0.35).opacity(0.6)),
            dismissIconColor: CodableColor(Color(red: 1.0, green: 0.96, blue: 0.88).opacity(0.8)),
            progressRingColor: CodableColor(Color(red: 1.0, green: 0.96, blue: 0.88).opacity(0.6)),
            disableButtonTextColor: pink,
            disableButtonBackgroundColor: CodableColor(Color(red: 1.0, green: 0.96, blue: 0.88).opacity(0.9)),
            joinButtonTextColor: pink,
            joinButtonBackgroundColor: CodableColor(Color(red: 1.0, green: 0.85, blue: 0.35))
        )
    }

    // MARK: - Codable (backwards compatibility)

    enum CodingKeys: String, CodingKey {
        case id, name, backgroundType, backgroundColor, backgroundOpacity
        case imageData, overlayColor, overlayOpacity, imageBlurRadius
        case titleColor, countdownColor
        case dismissButtonColor, dismissIconColor, progressRingColor
        case disableButtonTextColor, disableButtonBackgroundColor
        case joinButtonTextColor, joinButtonBackgroundColor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        backgroundType = try container.decodeIfPresent(BackgroundType.self, forKey: .backgroundType) ?? .solidColor
        backgroundColor = try container.decode(CodableColor.self, forKey: .backgroundColor)
        backgroundOpacity = try container.decode(Double.self, forKey: .backgroundOpacity)
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        overlayColor = try container.decodeIfPresent(CodableColor.self, forKey: .overlayColor) ?? CodableColor(.black)
        overlayOpacity = try container.decodeIfPresent(Double.self, forKey: .overlayOpacity) ?? 0.3
        imageBlurRadius = try container.decodeIfPresent(Double.self, forKey: .imageBlurRadius)
        titleColor = try container.decode(CodableColor.self, forKey: .titleColor)
        countdownColor = try container.decode(CodableColor.self, forKey: .countdownColor)
        dismissButtonColor = try container.decode(CodableColor.self, forKey: .dismissButtonColor)
        dismissIconColor = try container.decode(CodableColor.self, forKey: .dismissIconColor)
        progressRingColor = try container.decode(CodableColor.self, forKey: .progressRingColor)
        disableButtonTextColor = try container.decode(CodableColor.self, forKey: .disableButtonTextColor)
        disableButtonBackgroundColor = try container.decode(CodableColor.self, forKey: .disableButtonBackgroundColor)
        joinButtonTextColor = try container.decode(CodableColor.self, forKey: .joinButtonTextColor)
        joinButtonBackgroundColor = try container.decode(CodableColor.self, forKey: .joinButtonBackgroundColor)
    }
}

// MARK: - Pre-Alert Preset Theme

struct PreAlertPresetTheme: Codable, Identifiable {
    var name: String
    var theme: PreAlertTheme

    var id: String { name }
}
