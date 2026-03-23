//
//  ThemeService.swift
//  ZapCal
//
//  Created by Harsh Kalra on 3/5/26.
//

import Foundation
import SwiftUI

class ThemeService: ObservableObject {
    static let shared = ThemeService()

    @Published private(set) var calendarPresetAssignments: [String: String] = [:]

    private init() {}

    func getTheme(for calendarIdentifier: String?) -> AlertTheme {
        let presetName = assignedPresetName(for: calendarIdentifier)
        return PresetManager.shared.theme(named: presetName)
    }

    func assignedPresetName(for calendarIdentifier: String?) -> String {
        guard let id = calendarIdentifier else { return "Pinka Blua" }
        return calendarPresetAssignments[id] ?? "Pinka Blua"
    }

    func setPreset(_ presetName: String, for calendarIdentifier: String) {
        calendarPresetAssignments[calendarIdentifier] = presetName
    }

    func resetAssignment(for calendarIdentifier: String) {
        calendarPresetAssignments.removeValue(forKey: calendarIdentifier)
    }

    func clearAssignments(for presetName: String) {
        let keysToRemove = calendarPresetAssignments.filter { $0.value == presetName }.map(\.key)
        for key in keysToRemove {
            calendarPresetAssignments.removeValue(forKey: key)
        }
    }
}
