//
//  PreAlertPresetManager.swift
//  Full Screen Calendar Reminder
//

import Foundation
import Combine
import AppKit

class PreAlertPresetManager: ObservableObject {
    static let shared = PreAlertPresetManager()

    @Published private(set) var presets: [PreAlertPresetTheme] = []

    private var builtInNames: Set<String> = []

    private init() {
        try? FileManager.default.createDirectory(at: localPresetsDir, withIntermediateDirectories: true)
        reload()
    }

    // MARK: - Public API

    func preset(named name: String) -> PreAlertPresetTheme? {
        presets.first { $0.name == name }
    }

    func theme(named name: String) -> PreAlertTheme {
        preset(named: name)?.theme ?? PreAlertTheme.defaultTheme()
    }

    func isBuiltIn(_ name: String) -> Bool {
        builtInNames.contains(name)
    }

    func isEditable(_ name: String) -> Bool {
        #if DEBUG
        return true
        #else
        return !isBuiltIn(name)
        #endif
    }

    func savePreset(name: String, theme: PreAlertTheme) {
        var themeToSave = theme
        themeToSave.id = "default"
        themeToSave.name = name

        let preset = PreAlertPresetTheme(name: name, theme: themeToSave)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(preset) else { return }

        let fileURL = localPresetsDir.appendingPathComponent("\(sanitizedFilename(name)).json")
        try? data.write(to: fileURL, options: .atomic)
        reload()
    }

    func duplicatePreset(from sourceName: String, newName: String) {
        guard let source = preset(named: sourceName) else { return }
        savePreset(name: newName, theme: source.theme)
    }

    func deletePreset(named name: String) {
        guard !isBuiltIn(name) else { return }
        let fileURL = localPresetsDir.appendingPathComponent("\(sanitizedFilename(name)).json")
        try? FileManager.default.removeItem(at: fileURL)
        reload()
    }

    func renamePreset(from oldName: String, to newName: String) {
        guard !isBuiltIn(oldName), let source = preset(named: oldName) else { return }
        deletePreset(named: oldName)
        savePreset(name: newName, theme: source.theme)
    }

    func uniqueName(base: String) -> String {
        let existingNames = Set(presets.map(\.name))
        if !existingNames.contains(base) { return base }
        var i = 2
        while existingNames.contains("\(base) \(i)") { i += 1 }
        return "\(base) \(i)"
    }

    // MARK: - Private

    private var localPresetsDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("Full Screen Calendar Reminder", isDirectory: true)
            .appendingPathComponent("PreAlertPresets", isDirectory: true)
    }

    private func reload() {
        var result: [PreAlertPresetTheme] = []
        var seen = Set<String>()
        builtInNames = []

        // 1. Bundled JSON presets
        let bundleLocations: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent("PreAlertPresets"),
            Bundle.main.resourceURL,
        ]
        for location in bundleLocations.compactMap({ $0 }) {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: location, includingPropertiesForKeys: nil
            )) ?? []
            for file in files where file.pathExtension == "json" {
                if let preset = decodePreset(from: file), !seen.contains(preset.name) {
                    builtInNames.insert(preset.name)
                    result.append(preset)
                    seen.insert(preset.name)
                }
            }
        }

        // 2. Custom presets from App Support
        let localFiles = (try? FileManager.default.contentsOfDirectory(
            at: localPresetsDir, includingPropertiesForKeys: nil
        )) ?? []
        for file in localFiles where file.pathExtension == "json" {
            if let preset = decodePreset(from: file) {
                if seen.contains(preset.name) {
                    if let idx = result.firstIndex(where: { $0.name == preset.name }) {
                        result[idx] = preset
                    }
                } else {
                    result.append(preset)
                    seen.insert(preset.name)
                }
            }
        }

        // Sort: "Coral Paper" first, then alphabetical
        presets = result.sorted {
            if $0.name == "Coral Paper" { return true }
            if $1.name == "Coral Paper" { return false }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func decodePreset(from url: URL) -> PreAlertPresetTheme? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PreAlertPresetTheme.self, from: data)
    }

    private func sanitizedFilename(_ name: String) -> String {
        name.replacingOccurrences(of: "[^a-zA-Z0-9_ -]", with: "", options: .regularExpression)
            .replacingOccurrences(of: " ", with: "_")
    }
}
