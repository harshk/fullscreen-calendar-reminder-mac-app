//
//  ThemeService.swift
//  Full Screen Calendar Reminder
//
//  Created by Harsh Kalra on 3/5/26.
//

import Foundation
import SwiftUI

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
        
        if let theme = themes[id] {
            return theme
        }
        
        // Return default theme if not found
        return themes["default"] ?? AlertTheme.defaultTheme()
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
    
    // MARK: - Persistence
    
    private func loadThemes() {
        guard let data = UserDefaults.standard.data(forKey: themesKey),
              let decoded = try? JSONDecoder().decode([String: AlertTheme].self, from: data) else {
            // Create default theme if none exists
            themes["default"] = AlertTheme.defaultTheme()
            saveThemes()
            return
        }
        
        themes = decoded
        
        // Ensure default theme exists
        if themes["default"] == nil {
            themes["default"] = AlertTheme.defaultTheme()
            saveThemes()
        }
    }
    
    func saveThemes() {
        if let encoded = try? JSONEncoder().encode(themes) {
            UserDefaults.standard.set(encoded, forKey: themesKey)
        }
    }
}
