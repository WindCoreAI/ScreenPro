import Foundation
import AppKit
import UniformTypeIdentifiers

// MARK: - Storage Error

enum StorageError: LocalizedError {
    case directoryCreationFailed(URL)
    case writeFailed(URL, Error)
    case deleteFailed(URL, Error)

    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let url):
            return "Failed to create directory at \(url.path)"
        case .writeFailed(let url, let error):
            return "Failed to write file to \(url.path): \(error.localizedDescription)"
        case .deleteFailed(let url, let error):
            return "Failed to delete file at \(url.path): \(error.localizedDescription)"
        }
    }
}

// MARK: - StorageService Protocol

protocol StorageServiceProtocol {
    func save(imageData: Data, filename: String, to directory: URL) throws -> URL
    func delete(at url: URL) throws
    func copyToClipboard(imageData: Data, type: UTType)
    func copyToClipboard(image: NSImage)
    func ensureDirectoryExists(at url: URL) throws
    func uniqueURL(for filename: String, in directory: URL) -> URL
}

// MARK: - StorageService Implementation (T054-T058 - placeholder for Phase 8)

final class StorageService: StorageServiceProtocol {
    // MARK: - File Operations (T054)

    /// Saves image data to disk
    func save(imageData: Data, filename: String, to directory: URL) throws -> URL {
        try ensureDirectoryExists(at: directory)

        let targetURL = uniqueURL(for: filename, in: directory)

        do {
            try imageData.write(to: targetURL)
            return targetURL
        } catch {
            throw StorageError.writeFailed(targetURL, error)
        }
    }

    /// Deletes a file at the specified URL
    func delete(at url: URL) throws {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw StorageError.deleteFailed(url, error)
        }
    }

    // MARK: - Clipboard Operations (T056)

    /// Copies image data to the system clipboard
    func copyToClipboard(imageData: Data, type: UTType) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(imageData, forType: NSPasteboard.PasteboardType(type.identifier))
    }

    /// Copies an NSImage to the system clipboard
    func copyToClipboard(image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    // MARK: - Directory Management (T058)

    /// Ensures a directory exists, creating it if necessary
    func ensureDirectoryExists(at url: URL) throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                throw StorageError.directoryCreationFailed(url)
            }
        }
    }

    // MARK: - Filename Conflict Resolution (T055)

    /// Returns a unique URL, appending a number if file already exists
    func uniqueURL(for filename: String, in directory: URL) -> URL {
        let fileManager = FileManager.default
        var url = directory.appendingPathComponent(filename)

        if !fileManager.fileExists(atPath: url.path) {
            return url
        }

        // File exists, find a unique name
        let nameWithoutExt = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension

        var counter = 1
        repeat {
            let newName = "\(nameWithoutExt) (\(counter)).\(ext)"
            url = directory.appendingPathComponent(newName)
            counter += 1
        } while fileManager.fileExists(atPath: url.path)

        return url
    }
}
