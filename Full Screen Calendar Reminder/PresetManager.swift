//
//  PresetManager.swift
//  Full Screen Calendar Reminder
//
//  Created by Harsh Kalra on 3/13/26.
//

import Foundation

struct PresetTheme: Codable {
    var name: String
    var theme: AlertTheme
}

class PresetManager {
    static let shared = PresetManager()

    private init() {
        // Ensure the local presets directory exists
        try? FileManager.default.createDirectory(at: localPresetsDir, withIntermediateDirectories: true)
    }

    /// App Support directory for user-saved presets (sandbox-safe).
    private var localPresetsDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("Full Screen Calendar Reminder", isDirectory: true)
            .appendingPathComponent("Presets", isDirectory: true)
    }

    /// Load all presets from both bundled resources and local App Support.
    func loadPresets() -> [PresetTheme] {
        var presets: [PresetTheme] = []
        var seen = Set<String>()

        // 1. Load from bundled Presets subdirectory
        if let files = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Presets") {
            for file in files {
                if let preset = decodePreset(from: file), !seen.contains(preset.name) {
                    presets.append(preset)
                    seen.insert(preset.name)
                }
            }
        }

        // 2. Load from top-level bundle (synchronized root groups may flatten)
        if let resourcePath = Bundle.main.resourceURL {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: resourcePath, includingPropertiesForKeys: nil
            )) ?? []
            for file in files where file.pathExtension == "json" {
                if let preset = decodePreset(from: file), !seen.contains(preset.name) {
                    presets.append(preset)
                    seen.insert(preset.name)
                }
            }
        }

        // 3. Load from local App Support (user-saved presets)
        let localFiles = (try? FileManager.default.contentsOfDirectory(
            at: localPresetsDir, includingPropertiesForKeys: nil
        )) ?? []
        for file in localFiles where file.pathExtension == "json" {
            if let preset = decodePreset(from: file), !seen.contains(preset.name) {
                presets.append(preset)
                seen.insert(preset.name)
            }
        }

        return presets.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func decodePreset(from url: URL) -> PresetTheme? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PresetTheme.self, from: data)
    }

    #if DEBUG
    /// Save a preset to the local App Support directory.
    func savePreset(name: String, theme: AlertTheme) {
        var themeToSave = theme
        themeToSave.id = "default"
        themeToSave.name = name

        let preset = PresetTheme(name: name, theme: themeToSave)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(preset) else { return }

        let filename = name
            .replacingOccurrences(of: "[^a-zA-Z0-9_ -]", with: "", options: .regularExpression)
            .replacingOccurrences(of: " ", with: "_")

        let fileURL = localPresetsDir.appendingPathComponent("\(filename).json")
        try? data.write(to: fileURL, options: .atomic)
        print(">>> Preset saved to: \(fileURL.path)")
    }

    /// Reveal the local presets directory in Finder so the developer can copy
    /// JSON files into the source Presets/ folder for bundling.
    func revealPresetsInFinder() {
        NSWorkspace.shared.open(localPresetsDir)
    }
    #endif
}

#if DEBUG
import AppKit
#endif
