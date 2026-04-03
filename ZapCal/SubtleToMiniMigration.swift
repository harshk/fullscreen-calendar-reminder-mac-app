//
//  SubtleToMiniMigration.swift
//  ZapCal
//
//  One-time migration that converts all "subtle" references to "mini"
//  in UserDefaults and on-disk JSON files. Runs once for users
//  upgrading to version 1.0.8+.
//

import Foundation

struct SubtleToMiniMigration {
    private static let migrationKey = "hasCompletedSubtleToMiniMigration"

    /// Run the migration if it hasn't been completed yet.
    static func runIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        migrateUserDefaults()
        migrateAlertConfigs()
        migrateJSONFiles()
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    // MARK: - UserDefaults Keys

    private static func migrateUserDefaults() {
        let defaults = UserDefaults.standard

        // Rename "subtle" keys to "mini" equivalents
        let keyMappings: [(old: String, new: String)] = [
            ("subtleAlertLeadTime", "miniAlertLeadTime"),
            ("subtleAlertDuration", "miniAlertDuration"),
        ]

        for mapping in keyMappings {
            if let value = defaults.object(forKey: mapping.old) {
                defaults.set(value, forKey: mapping.new)
                defaults.removeObject(forKey: mapping.old)
            }
        }

        // Migrate eventAlarmAlertStyle: "subtle" → "mini"
        if let style = defaults.string(forKey: "eventAlarmAlertStyle"), style == "subtle" {
            defaults.set("mini", forKey: "eventAlarmAlertStyle")
        }

        // Migrate firstAlertStyle: "subtle" → "mini"
        if let style = defaults.string(forKey: "firstAlertStyle"), style == "subtle" {
            defaults.set("mini", forKey: "firstAlertStyle")
        }

        // Migrate secondAlertStyle: "subtle" → "mini"
        if let style = defaults.string(forKey: "secondAlertStyle"), style == "subtle" {
            defaults.set("mini", forKey: "secondAlertStyle")
        }
    }

    // MARK: - AlertConfigs (JSON in UserDefaults)

    private static func migrateAlertConfigs() {
        guard var data = UserDefaults.standard.data(forKey: "alertConfigs"),
              var json = String(data: data, encoding: .utf8) else { return }

        let original = json

        // Replace "subtle" style values and "subtleDuration" keys
        json = json.replacingOccurrences(of: "\"subtle\"", with: "\"mini\"")
        json = json.replacingOccurrences(of: "\"subtleDuration\"", with: "\"miniDuration\"")

        if json != original, let updated = json.data(using: .utf8) {
            UserDefaults.standard.set(updated, forKey: "alertConfigs")
        }
    }

    // MARK: - On-Disk JSON Files

    private static func migrateJSONFiles() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let zapCalDir = appSupport.appendingPathComponent("ZapCal", isDirectory: true)

        // Migrate preset assignment files
        let jsonFiles = [
            "preset_assignments.json",
            "pre_alert_preset_assignments.json",
        ]

        for filename in jsonFiles {
            let fileURL = zapCalDir.appendingPathComponent(filename)
            migrateJSONFile(at: fileURL)
        }

        // Migrate preset JSON files in Presets/ and PreAlertPresets/ directories
        let presetDirs = [
            zapCalDir.appendingPathComponent("Presets", isDirectory: true),
            zapCalDir.appendingPathComponent("PreAlertPresets", isDirectory: true),
        ]

        for dir in presetDirs {
            guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for file in files where file.pathExtension == "json" {
                migrateJSONFile(at: file)
            }
        }
    }

    private static func migrateJSONFile(at url: URL) {
        guard let data = try? Data(contentsOf: url),
              var json = String(data: data, encoding: .utf8) else { return }

        let original = json
        json = json.replacingOccurrences(of: "\"subtle\"", with: "\"mini\"")
        json = json.replacingOccurrences(of: "\"subtleDuration\"", with: "\"miniDuration\"")

        if json != original, let updated = json.data(using: .utf8) {
            try? updated.write(to: url)
        }
    }
}
