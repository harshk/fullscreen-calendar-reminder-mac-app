//
//  ImageStore.swift
//  Full Screen Calendar Reminder
//

import Foundation
import AppKit

/// Stores preset background images as separate files and loads them on demand.
/// Images are never kept in memory — each call to `load` creates a fresh NSImage.
enum ImageStore {

    private static var imagesDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport
            .appendingPathComponent("Full Screen Calendar Reminder", isDirectory: true)
            .appendingPathComponent("Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Save image data to disk and return the filename.
    static func save(_ data: Data) -> String {
        let filename = UUID().uuidString + ".jpg"
        let url = imagesDir.appendingPathComponent(filename)
        try? data.write(to: url, options: .atomic)
        return filename
    }

    /// Load an NSImage from a filename. Returns nil if not found.
    static func load(_ filename: String) -> NSImage? {
        // Check app-support Images dir first
        let url = imagesDir.appendingPathComponent(filename)
        if let image = NSImage(contentsOf: url) { return image }
        // Check bundle resources (for bundled preset images)
        if let bundleURL = Bundle.main.resourceURL?.appendingPathComponent("Images/\(filename)"),
           let image = NSImage(contentsOf: bundleURL) { return image }
        return nil
    }

    /// Load raw Data from a filename. Returns nil if not found.
    static func loadData(_ filename: String) -> Data? {
        let url = imagesDir.appendingPathComponent(filename)
        if let data = try? Data(contentsOf: url) { return data }
        if let bundleURL = Bundle.main.resourceURL?.appendingPathComponent("Images/\(filename)"),
           let data = try? Data(contentsOf: bundleURL) { return data }
        return nil
    }

    /// Delete an image file.
    static func delete(_ filename: String) {
        let url = imagesDir.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
}
