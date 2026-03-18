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

    /// Maps calendar identifier → preset name.
    @Published private(set) var calendarPresetAssignments: [String: String] = [:]

    /// Maps calendar identifier → pre-alert preset name.
    @Published private(set) var calendarPreAlertAssignments: [String: String] = [:]

    private static let defaultPresetName = "Pinka Blua"
    private static let defaultPreAlertPresetName = "Basic"

    private init() {
        loadAssignments()
        loadPreAlertAssignments()
        migrateOldThemesIfNeeded()
    }

    // MARK: - Public API

    func getTheme(for calendarIdentifier: String?) -> AlertTheme {
        let presetName = assignedPresetName(for: calendarIdentifier)
        return PresetManager.shared.theme(named: presetName)
    }

    func assignedPresetName(for calendarIdentifier: String?) -> String {
        guard let id = calendarIdentifier else { return Self.defaultPresetName }
        return calendarPresetAssignments[id] ?? Self.defaultPresetName
    }

    func setPreset(_ presetName: String, for calendarIdentifier: String) {
        calendarPresetAssignments[calendarIdentifier] = presetName
        saveAssignments()
    }

    func resetAssignment(for calendarIdentifier: String) {
        calendarPresetAssignments.removeValue(forKey: calendarIdentifier)
        saveAssignments()
    }

    // MARK: - Pre-Alert Preset API

    func getPreAlertTheme(for calendarIdentifier: String?) -> PreAlertTheme {
        let presetName = assignedPreAlertPresetName(for: calendarIdentifier)
        return PreAlertPresetManager.shared.theme(named: presetName)
    }

    func assignedPreAlertPresetName(for calendarIdentifier: String?) -> String {
        guard let id = calendarIdentifier else { return Self.defaultPreAlertPresetName }
        return calendarPreAlertAssignments[id] ?? Self.defaultPreAlertPresetName
    }

    func setPreAlertPreset(_ presetName: String, for calendarIdentifier: String) {
        calendarPreAlertAssignments[calendarIdentifier] = presetName
        savePreAlertAssignments()
    }

    func resetPreAlertAssignment(for calendarIdentifier: String) {
        calendarPreAlertAssignments.removeValue(forKey: calendarIdentifier)
        savePreAlertAssignments()
    }

    func clearPreAlertAssignments(for presetName: String) {
        let keysToRemove = calendarPreAlertAssignments.filter { $0.value == presetName }.map(\.key)
        for key in keysToRemove {
            calendarPreAlertAssignments.removeValue(forKey: key)
        }
        if !keysToRemove.isEmpty { savePreAlertAssignments() }
    }

    /// When a preset is deleted, remove all assignments pointing to it.
    func clearAssignments(for presetName: String) {
        let keysToRemove = calendarPresetAssignments.filter { $0.value == presetName }.map(\.key)
        for key in keysToRemove {
            calendarPresetAssignments.removeValue(forKey: key)
        }
        if !keysToRemove.isEmpty { saveAssignments() }
    }

    /// When a preset is renamed, update all assignments pointing to it.
    func updateAssignments(from oldName: String, to newName: String) {
        var changed = false
        for (key, value) in calendarPresetAssignments where value == oldName {
            calendarPresetAssignments[key] = newName
            changed = true
        }
        if changed { saveAssignments() }
    }

    // MARK: - Persistence

    private var assignmentsFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Full Screen Calendar Reminder", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("preset_assignments.json")
    }

    private func loadAssignments() {
        guard let data = try? Data(contentsOf: assignmentsFileURL),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }
        calendarPresetAssignments = decoded
    }

    private func saveAssignments() {
        if let data = try? JSONEncoder().encode(calendarPresetAssignments) {
            try? data.write(to: assignmentsFileURL, options: .atomic)
        }
    }

    private var preAlertAssignmentsFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Full Screen Calendar Reminder", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("pre_alert_preset_assignments.json")
    }

    private func loadPreAlertAssignments() {
        guard let data = try? Data(contentsOf: preAlertAssignmentsFileURL),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }
        calendarPreAlertAssignments = decoded
    }

    private func savePreAlertAssignments() {
        if let data = try? JSONEncoder().encode(calendarPreAlertAssignments) {
            try? data.write(to: preAlertAssignmentsFileURL, options: .atomic)
        }
    }

    // MARK: - Migration from old per-calendar themes

    private var oldThemesFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Full Screen Calendar Reminder", isDirectory: true)
        return appDir.appendingPathComponent("themes.json")
    }

    private func migrateOldThemesIfNeeded() {
        let fileURL = oldThemesFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let oldThemes = try? JSONDecoder().decode([String: AlertTheme].self, from: data) else {
            return
        }

        let presetManager = PresetManager.shared

        for (calendarID, theme) in oldThemes where calendarID != "default" {
            let presetName = presetManager.uniqueName(base: theme.name.isEmpty ? "Migrated" : theme.name)
            presetManager.savePreset(name: presetName, theme: theme)
            calendarPresetAssignments[calendarID] = presetName
        }

        saveAssignments()

        // Archive the old file
        let backupURL = fileURL.deletingPathExtension().appendingPathExtension("json.backup")
        try? FileManager.default.moveItem(at: fileURL, to: backupURL)
    }
}
