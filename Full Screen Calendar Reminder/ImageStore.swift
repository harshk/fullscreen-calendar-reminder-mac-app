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

    /// Serial queue for all Core Image rendering — keeps GPU work off the main thread.
    private static let renderQueue = DispatchQueue(label: "com.app.ImageStore.render", qos: .userInitiated)

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
    /// The image has caching disabled to avoid AppKit's internal image cache
    /// retaining decoded bitmap data after the NSImage is released.
    static func load(_ filename: String) -> NSImage? {
        guard let url = resolveURL(filename) else { return nil }
        guard let image = NSImage(contentsOf: url) else { return nil }
        image.cacheMode = .never
        return image
    }

    /// Load an image downscaled so its longest edge fits within `maxPixels`,
    /// using Core Image to avoid loading the full-resolution image into an NSImage.
    static func loadThumbnail(_ filename: String, maxDimension maxPixels: CGFloat) -> NSImage? {
        guard let url = resolveURL(filename),
              let ciInput = CIImage(contentsOf: url) else { return nil }
        let srcW = ciInput.extent.width
        let srcH = ciInput.extent.height
        let scale = min(maxPixels / srcW, maxPixels / srcH, 1.0)
        let output = (scale < 1.0)
            ? ciInput.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            : ciInput
        guard let cgImage = ciContext.createCGImage(output, from: output.extent) else { return nil }

        let result = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        result.cacheMode = .never
        return result
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

        // Render using shared context, then flush GPU resources
        guard let cgImage = ciContext.createCGImage(blurred, from: blurred.extent) else { return nil }

        let result = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        result.cacheMode = .never
        return result
    }

    /// Async version of loadBlurred — runs Core Image work on a background queue
    /// so the main thread stays responsive.
    static func loadBlurredAsync(
        _ filename: String,
        targetSize: CGSize,
        blurRadius: CGFloat,
        completion: @escaping @MainActor (NSImage?) -> Void
    ) {
        renderQueue.async {
            let result = loadBlurred(filename, targetSize: targetSize, blurRadius: blurRadius)
            DispatchQueue.main.async { completion(result) }
        }
    }

    /// Async version of loadThumbnail.
    static func loadThumbnailAsync(
        _ filename: String,
        maxDimension maxPixels: CGFloat,
        completion: @escaping @MainActor (NSImage?) -> Void
    ) {
        renderQueue.async {
            let result = loadThumbnail(filename, maxDimension: maxPixels)
            DispatchQueue.main.async { completion(result) }
        }
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
