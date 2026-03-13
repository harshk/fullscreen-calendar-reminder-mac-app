//
//  ThemeService.swift
//  Full Screen Calendar Reminder
//
//  Created by Harsh Kalra on 3/5/26.
//

import Foundation
import SwiftUI
import Combine

class ThemeService: ObservableObject {
    static let shared = ThemeService()
    
    @Published private(set) var themes: [String: AlertTheme] = [:]
    
    private let themesKey = "alertThemes"
    
    private init() {
        loadThemes()
    }
    
    // MARK: - Theme Management
    
    func getTheme(for calendarIdentifier: String?) -> AlertTheme {
        let id = calendarIdentifier ?? "default"

        var theme = themes[id] ?? themes["default"] ?? AlertTheme.defaultTheme()

        // Backfill any missing element styles from the default theme
        let defaults = AlertTheme.defaultTheme()
        for element in AlertElementIdentifier.allCases {
            if theme.elementStyles[element] == nil {
                theme.elementStyles[element] = defaults.elementStyles[element]
            }
        }

        return theme
    }
    
    func setTheme(_ theme: AlertTheme, for calendarIdentifier: String) {
        themes[calendarIdentifier] = theme
        saveThemes()
    }
    
    func resetTheme(for calendarIdentifier: String) {
        if calendarIdentifier == "default" {
            themes["default"] = AlertTheme.defaultTheme()
        } else {
            themes.removeValue(forKey: calendarIdentifier)
        }
        saveThemes()
    }
    
    func duplicateTheme(from sourceIdentifier: String, to targetIdentifier: String) {
        guard let sourceTheme = themes[sourceIdentifier] else { return }
        
        var newTheme = sourceTheme
        newTheme.id = targetIdentifier
        themes[targetIdentifier] = newTheme
        saveThemes()
    }
    
    func ensureDefaultTheme() {
        if themes["default"] == nil {
            themes["default"] = AlertTheme.defaultTheme()
            saveThemes()
        }
    }
    
    // MARK: - Persistence (file-based to avoid UserDefaults 4MB limit)

    private var themesFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Full Screen Calendar Reminder", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("themes.json")
    }

    private func loadThemes() {
        // Migrate from UserDefaults if file doesn't exist yet
        if !FileManager.default.fileExists(atPath: themesFileURL.path),
           let legacyData = UserDefaults.standard.data(forKey: themesKey),
           let decoded = try? JSONDecoder().decode([String: AlertTheme].self, from: legacyData) {
            themes = decoded
            saveThemes()
            UserDefaults.standard.removeObject(forKey: themesKey)
            return
        }

        guard let data = try? Data(contentsOf: themesFileURL),
              let decoded = try? JSONDecoder().decode([String: AlertTheme].self, from: data) else {
            themes["default"] = AlertTheme.defaultTheme()
            saveThemes()
            return
        }

        themes = decoded

        if themes["default"] == nil {
            themes["default"] = AlertTheme.defaultTheme()
        }

        // Backfill missing element styles into all saved themes
        let defaults = AlertTheme.defaultTheme()
        var didChange = false
        for key in themes.keys {
            for element in AlertElementIdentifier.allCases {
                if themes[key]?.elementStyles[element] == nil {
                    themes[key]?.elementStyles[element] = defaults.elementStyles[element]
                    didChange = true
                }
            }
        }
        if didChange {
            saveThemes()
        }
    }

    func saveThemes() {
        if let encoded = try? JSONEncoder().encode(themes) {
            try? encoded.write(to: themesFileURL, options: .atomic)
        }
    }
}
