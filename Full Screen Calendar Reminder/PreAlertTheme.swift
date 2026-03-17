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
    var backgroundColor: CodableColor
    var backgroundOpacity: Double

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
}

// MARK: - Pre-Alert Preset Theme

struct PreAlertPresetTheme: Codable, Identifiable {
    var name: String
    var theme: PreAlertTheme

    var id: String { name }
}
