//
//  AlertTheme.swift
//  Full Screen Calendar Reminder
//
//  Created by Harsh Kalra on 3/5/26.
//

import Foundation
import SwiftUI

// MARK: - Alert Theme

struct AlertTheme: Codable, Identifiable {
    var id: String
    var name: String
    
    // Background
    var backgroundType: BackgroundType
    var solidColor: CodableColor
    var solidColorOpacity: Double
    var imageData: Data?
    var overlayColor: CodableColor
    var overlayOpacity: Double
    
    // Element Styles
    var elementStyles: [AlertElementIdentifier: AlertElementStyle]
    
    enum BackgroundType: String, Codable {
        case solidColor
        case image
    }
    
    // MARK: - Default Theme
    
    static func defaultTheme(id: String = "default", name: String = "Default Style") -> AlertTheme {
        AlertTheme(
            id: id,
            name: name,
            backgroundType: .solidColor,
            solidColor: CodableColor(Color(red: 0.1, green: 0.1, blue: 0.15)),
            solidColorOpacity: 0.98,
            imageData: nil,
            overlayColor: CodableColor(.black),
            overlayOpacity: 0.3,
            elementStyles: [
                .title: AlertElementStyle(
                    fontFamily: "SF Pro",
                    fontSize: 72,
                    fontWeight: .bold,
                    fontColor: CodableColor(.white),
                    textAlignment: .center,
                    positionX: 0.5,
                    positionY: 0.2,
                    maxWidthPercentage: 0.8
                ),
                .startTime: AlertElementStyle(
                    fontFamily: "SF Pro",
                    fontSize: 48,
                    fontWeight: .semibold,
                    fontColor: CodableColor(Color(red: 1.0, green: 0.27, blue: 0.58)),
                    textAlignment: .center,
                    positionX: 0.5,
                    positionY: 0.3,
                    maxWidthPercentage: 0.6
                ),
                .location: AlertElementStyle(
                    fontFamily: "SF Pro",
                    fontSize: 32,
                    fontWeight: .regular,
                    fontColor: CodableColor(Color.white.opacity(0.8)),
                    textAlignment: .center,
                    positionX: 0.5,
                    positionY: 0.42,
                    maxWidthPercentage: 0.7
                ),
                .calendarName: AlertElementStyle(
                    fontFamily: "SF Pro",
                    fontSize: 24,
                    fontWeight: .medium,
                    fontColor: CodableColor(Color.white.opacity(0.6)),
                    textAlignment: .center,
                    positionX: 0.5,
                    positionY: 0.72,
                    maxWidthPercentage: 0.5
                ),
                .joinButton: AlertElementStyle(
                    fontFamily: "SF Pro",
                    fontSize: 28,
                    fontWeight: .semibold,
                    fontColor: CodableColor(.white),
                    textAlignment: .center,
                    positionX: 0.5,
                    positionY: 0.82,
                    maxWidthPercentage: 0.4,
                    buttonBackgroundColor: CodableColor(Color(red: 1.0, green: 0.27, blue: 0.58)),
                    buttonTextColor: CodableColor(.white),
                    buttonCornerRadius: 16,
                    buttonPaddingHorizontal: 32,
                    buttonPaddingVertical: 16
                ),
                .dismissButton: AlertElementStyle(
                    fontFamily: "SF Pro",
                    fontSize: 24,
                    fontWeight: .regular,
                    fontColor: CodableColor(Color.white.opacity(0.7)),
                    textAlignment: .center,
                    positionX: 0.05,
                    positionY: 0.12,
                    maxWidthPercentage: 0.1,
                    iconSize: 32,
                    iconColor: CodableColor(Color.white.opacity(0.7))
                ),
                .queueCounter: AlertElementStyle(
                    fontFamily: "SF Pro",
                    fontSize: 20,
                    fontWeight: .medium,
                    fontColor: CodableColor(Color.white.opacity(0.5)),
                    textAlignment: .center,
                    positionX: 0.5,
                    positionY: 0.9,
                    maxWidthPercentage: 0.3
                )
            ]
        )
    }
}

// MARK: - Alert Element Identifier

enum AlertElementIdentifier: String, CaseIterable, Codable {
    case title
    case startTime
    case location
    case calendarName
    case joinButton
    case dismissButton
    case queueCounter
    
    var displayName: String {
        switch self {
        case .title: return "Event Title"
        case .startTime: return "Start Time"
        case .location: return "Location"
        case .calendarName: return "Calendar Name"
        case .joinButton: return "Join Meeting Button"
        case .dismissButton: return "Dismiss Button (X)"
        case .queueCounter: return "Queue Counter"
        }
    }
}

// MARK: - Alert Element Style

struct AlertElementStyle: Codable {
    var fontFamily: String
    var fontSize: CGFloat
    var fontWeight: Font.Weight
    var fontColor: CodableColor
    var textAlignment: TextAlignment
    var positionX: Double // 0.0 to 1.0 (percentage of screen width)
    var positionY: Double // 0.0 to 1.0 (percentage of screen height)
    var maxWidthPercentage: Double // 0.0 to 1.0
    
    // Button-specific properties
    var buttonBackgroundColor: CodableColor?
    var buttonTextColor: CodableColor?
    var buttonCornerRadius: CGFloat?
    var buttonPaddingHorizontal: CGFloat?
    var buttonPaddingVertical: CGFloat?
    
    // Icon-specific properties
    var iconSize: CGFloat?
    var iconColor: CodableColor?
}

// MARK: - Codable Color

struct CodableColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double
    
    init(_ color: Color) {
        // Extract RGBA components
        #if canImport(AppKit)
        let nsColor = NSColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.opacity = Double(a)
        #else
        // Fallback for other platforms
        self.red = 0.5
        self.green = 0.5
        self.blue = 0.5
        self.opacity = 1.0
        #endif
    }
    
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

// MARK: - Codable Extensions

extension Font.Weight: Codable {
    enum CodingKeys: String, CodingKey {
        case rawValue
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Double.self)
        
        switch rawValue {
        case -0.8: self = .ultraLight
        case -0.4: self = .thin
        case -0.2: self = .light
        case 0.0: self = .regular
        case 0.2: self = .medium
        case 0.4: self = .semibold
        case 0.6: self = .bold
        case 0.8: self = .heavy
        case 1.0: self = .black
        default: self = .regular
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        let rawValue: Double
        switch self {
        case .ultraLight: rawValue = -0.8
        case .thin: rawValue = -0.4
        case .light: rawValue = -0.2
        case .regular: rawValue = 0.0
        case .medium: rawValue = 0.2
        case .semibold: rawValue = 0.4
        case .bold: rawValue = 0.6
        case .heavy: rawValue = 0.8
        case .black: rawValue = 1.0
        default: rawValue = 0.0
        }
        
        try container.encode(rawValue)
    }
}

extension TextAlignment: Codable {
    enum CodingKeys: String, CodingKey {
        case rawValue
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        switch rawValue {
        case "leading": self = .leading
        case "center": self = .center
        case "trailing": self = .trailing
        default: self = .center
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        let rawValue: String
        switch self {
        case .leading: rawValue = "leading"
        case .center: rawValue = "center"
        case .trailing: rawValue = "trailing"
        }
        
        try container.encode(rawValue)
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String? {
        #if canImport(AppKit)
        let nsColor = NSColor(self)
        guard let components = nsColor.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        let a = components.count >= 4 ? Float(components[3]) : 1.0
        
        if a != 1.0 {
            return String(format: "#%02lX%02lX%02lX%02lX",
                         lroundf(a * 255),
                         lroundf(r * 255),
                         lroundf(g * 255),
                         lroundf(b * 255))
        } else {
            return String(format: "#%02lX%02lX%02lX",
                         lroundf(r * 255),
                         lroundf(g * 255),
                         lroundf(b * 255))
        }
        #else
        return nil
        #endif
    }
}
