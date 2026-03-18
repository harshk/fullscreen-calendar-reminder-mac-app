//
//  PresetManager.swift
//  Full Screen Calendar Reminder
//
//  Created by Harsh Kalra on 3/13/26.
//

import Foundation
import Combine
import AppKit

struct PresetTheme: Codable, Identifiable {
    var name: String
    var theme: AlertTheme

    var id: String { name }
}

class PresetManager: ObservableObject {
    static let shared = PresetManager()

    @Published private(set) var presets: [PresetTheme] = []

    /// Names of presets that ship with the app (built-in or hardcoded).
    private var builtInNames: Set<String> = []

    private init() {
        try? FileManager.default.createDirectory(at: localPresetsDir, withIntermediateDirectories: true)
        reload()
    }

    // MARK: - Public API

    func preset(named name: String) -> PresetTheme? {
        presets.first { $0.name == name }
    }

    func theme(named name: String) -> AlertTheme {
        var theme = preset(named: name)?.theme ?? AlertTheme.defaultTheme()
        // Backfill missing element styles
        let defaults = AlertTheme.defaultTheme()
        for element in AlertElementIdentifier.allCases {
            if theme.elementStyles[element] == nil {
                theme.elementStyles[element] = defaults.elementStyles[element]
            }
        }
        return theme
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

    func savePreset(name: String, theme: AlertTheme) {
        var themeToSave = theme
        themeToSave.id = "default"
        themeToSave.name = name

        let preset = PresetTheme(name: name, theme: themeToSave)
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

    #if DEBUG
    func revealPresetsInFinder() {
        NSWorkspace.shared.open(localPresetsDir)
    }
    #endif

    // MARK: - Private

    private var localPresetsDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("Full Screen Calendar Reminder", isDirectory: true)
            .appendingPathComponent("Presets", isDirectory: true)
    }

    private func reload() {
        var result: [PresetTheme] = []
        var seen = Set<String>()
        builtInNames = []

        // 1. Bundled JSON presets
        let bundleLocations: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent("Presets"),
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

        // 2. Custom presets from App Support (can override built-in in DEBUG)
        let localFiles = (try? FileManager.default.contentsOfDirectory(
            at: localPresetsDir, includingPropertiesForKeys: nil
        )) ?? []
        for file in localFiles where file.pathExtension == "json" {
            if let preset = decodePreset(from: file) {
                if seen.contains(preset.name) {
                    // Override the built-in version
                    if let idx = result.firstIndex(where: { $0.name == preset.name }) {
                        result[idx] = preset
                    }
                } else {
                    result.append(preset)
                    seen.insert(preset.name)
                }
            }
        }

        // Sort: "Coral Paper FS" first, then alphabetical
        presets = result.sorted {
            if $0.name == "Coral Paper FS" { return true }
            if $1.name == "Coral Paper FS" { return false }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func decodePreset(from url: URL) -> PresetTheme? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PresetTheme.self, from: data)
    }

    private func sanitizedFilename(_ name: String) -> String {
        name.replacingOccurrences(of: "[^a-zA-Z0-9_ -]", with: "", options: .regularExpression)
            .replacingOccurrences(of: " ", with: "_")
    }
}
