//
//  ImageStore.swift
//  Full Screen Calendar Reminder
//

import Foundation
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Stores preset background images as separate files and loads them on demand.
/// Images are never kept in memory — each call to `load` creates a fresh NSImage.
enum ImageStore {

    /// Single shared CIContext — reusing it avoids GPU resource accumulation
    /// that happens when creating a new context per call.
    private static let ciContext = CIContext(options: [
        .useSoftwareRenderer: false,
        .cacheIntermediates: false
    ])

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

    /// Load an NSImage downscaled so its longest edge fits within `maxPixels`.
    /// Callers should pass the target size in pixels (points × backingScaleFactor).
    /// This prevents SwiftUI blur from operating on multi-megapixel source images.
    static func loadThumbnail(_ filename: String, maxDimension maxPixels: CGFloat) -> NSImage? {
        guard let original = load(filename) else { return nil }
        let pixelSize = original.representations.first.map {
            CGSize(width: $0.pixelsWide, height: $0.pixelsHigh)
        } ?? original.size
        let scale = min(maxPixels / pixelSize.width, maxPixels / pixelSize.height, 1.0)
        if scale >= 1.0 { return original } // Already small enough
        let newW = pixelSize.width * scale
        let newH = pixelSize.height * scale
        let newImage = NSImage(size: NSSize(width: newW, height: newH))
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        original.draw(in: NSRect(x: 0, y: 0, width: newW, height: newH))
        newImage.unlockFocus()
        return newImage
    }

    /// Resolve a filename to its on-disk URL, checking app-support then bundle.
    private static func resolveURL(_ filename: String) -> URL? {
        let url = imagesDir.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: url.path) { return url }
        if let bundleURL = Bundle.main.resourceURL?.appendingPathComponent("Images/\(filename)"),
           FileManager.default.fileExists(atPath: bundleURL.path) { return bundleURL }
        return nil
    }

    /// Load an image, downscale it to `targetSize` (in pixels), apply a Gaussian blur,
    /// and return the result as a flat NSImage. Uses a single shared CIContext to avoid
    /// GPU resource accumulation across calls.
    static func loadBlurred(
        _ filename: String,
        targetSize: CGSize,
        blurRadius: CGFloat
    ) -> NSImage? {
        // Load directly from file URL into CIImage — avoids the
        // NSImage → tiffRepresentation round-trip that doubles memory.
        guard let fileURL = resolveURL(filename),
              let ciInput = CIImage(contentsOf: fileURL) else { return nil }

        // Downscale to target pixel size
        let srcW = ciInput.extent.width
        let srcH = ciInput.extent.height
        let scale = min(targetSize.width / srcW, targetSize.height / srcH, 1.0)
        let scaled = (scale < 1.0)
            ? ciInput.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            : ciInput

        // Apply blur (Core Image radius is in pixels)
        let blurred: CIImage
        if blurRadius > 0 {
            let clamp = scaled.clampedToExtent()
            let filter = CIFilter.gaussianBlur()
            filter.inputImage = clamp
            filter.radius = Float(blurRadius)
            blurred = filter.outputImage?.cropped(to: scaled.extent) ?? scaled
        } else {
            blurred = scaled
        }

        // Render using shared context
        guard let cgImage = ciContext.createCGImage(blurred, from: blurred.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
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
