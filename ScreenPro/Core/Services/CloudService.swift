import Foundation

// MARK: - Cloud Errors (007-cloud-polish)

/// Errors thrown by CloudService operations.
enum CloudError: LocalizedError, Equatable {
    case notConfigured
    case invalidServerURL
    case encodingFailed
    case uploadFailed(statusCode: Int)
    case deleteFailed(statusCode: Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Cloud uploads are not configured. Enable them in Settings → Cloud."
        case .invalidServerURL:
            return "The cloud server URL is invalid. Check it in Settings → Cloud."
        case .encodingFailed:
            return "Failed to prepare the capture for upload."
        case .uploadFailed(let statusCode):
            return "Upload failed (server returned \(statusCode))."
        case .deleteFailed(let statusCode):
            return "Delete failed (server returned \(statusCode))."
        case .invalidResponse:
            return "The cloud server returned an unexpected response."
        }
    }
}

// MARK: - Link Expiry

/// Expiration presets for shareable links.
enum LinkExpiry: String, Codable, CaseIterable, Sendable {
    case never
    case oneHour
    case oneDay
    case oneWeek
    case oneMonth

    var displayName: String {
        switch self {
        case .never: return "Never"
        case .oneHour: return "1 Hour"
        case .oneDay: return "24 Hours"
        case .oneWeek: return "7 Days"
        case .oneMonth: return "30 Days"
        }
    }

    /// Seconds until expiration, or nil for links that never expire.
    var timeInterval: TimeInterval? {
        switch self {
        case .never: return nil
        case .oneHour: return 3600
        case .oneDay: return 86400
        case .oneWeek: return 604800
        case .oneMonth: return 2_592_000
        }
    }
}

// MARK: - CloudService (007-cloud-polish)

/// Uploads captures to a configurable hosting server and returns shareable links.
/// The server API is a simple multipart upload endpoint compatible with the
/// contract described in docs/milestones/07-cloud-polish.md.
actor CloudService {
    // MARK: - Types

    /// Per-upload options for shareable links.
    struct UploadConfig: Equatable, Sendable {
        /// Seconds until the link self-destructs. nil = never expires.
        var expiresIn: TimeInterval?
        /// Optional password required to view the upload.
        var password: String?
        /// Optional maximum number of downloads before the link self-destructs.
        var maxDownloads: Int?

        init(expiresIn: TimeInterval? = nil, password: String? = nil, maxDownloads: Int? = nil) {
            self.expiresIn = expiresIn
            self.password = password
            self.maxDownloads = maxDownloads
        }
    }

    /// Result of a successful upload.
    struct UploadResult: Equatable, Sendable {
        /// Server-assigned identifier for the upload.
        let id: String
        /// The shareable link.
        let url: URL
        /// Token required to delete the upload later.
        let deleteToken: String
        /// When the link expires, if ever.
        let expiresAt: Date?
        /// When the upload completed locally.
        let createdAt: Date
    }

    /// Wire format of the server's upload response.
    /// Internal (not private) so unit tests can exercise response parsing.
    struct UploadResponse: Codable, Equatable {
        let id: String
        let url: String
        let deleteToken: String
        let expiresAt: String?

        enum CodingKeys: String, CodingKey {
            case id
            case url
            case deleteToken = "delete_token"
            case expiresAt = "expires_at"
        }
    }

    // MARK: - Configuration

    private let baseURL: URL
    private let apiKey: String?
    private let session: URLSession

    init(baseURL: URL, apiKey: String? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - Upload

    /// Uploads file data and returns a shareable link.
    func upload(
        data: Data,
        filename: String,
        mimeType: String,
        config: UploadConfig = UploadConfig()
    ) async throws -> UploadResult {
        var request = URLRequest(url: baseURL.appendingPathComponent("upload"))
        request.httpMethod = "POST"

        let boundary = "ScreenPro-\(UUID().uuidString)"
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = Self.makeMultipartBody(
            boundary: boundary,
            data: data,
            filename: filename,
            mimeType: mimeType,
            config: config
        )

        let (responseData, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw CloudError.uploadFailed(statusCode: httpResponse.statusCode)
        }

        let parsed = try Self.parseUploadResponse(responseData)

        guard let url = URL(string: parsed.url) else {
            throw CloudError.invalidResponse
        }

        return UploadResult(
            id: parsed.id,
            url: url,
            deleteToken: parsed.deleteToken,
            expiresAt: parsed.expiresAt.flatMap { ISO8601DateFormatter().date(from: $0) },
            createdAt: Date()
        )
    }

    // MARK: - Delete

    /// Deletes a previously uploaded file using its delete token.
    func delete(id: String, token: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("delete/\(id)"))
        request.httpMethod = "DELETE"
        request.setValue(token, forHTTPHeaderField: "X-Delete-Token")

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw CloudError.deleteFailed(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Request Building (testable)

    /// Builds the multipart/form-data body for an upload request.
    static func makeMultipartBody(
        boundary: String,
        data: Data,
        filename: String,
        mimeType: String,
        config: UploadConfig
    ) -> Data {
        var body = Data()

        // File part
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.appendString("\r\n")

        // Optional config fields
        if let expiresIn = config.expiresIn {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"expires_in\"\r\n\r\n")
            body.appendString("\(Int(expiresIn))\r\n")
        }

        if let password = config.password, !password.isEmpty {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"password\"\r\n\r\n")
            body.appendString("\(password)\r\n")
        }

        if let maxDownloads = config.maxDownloads {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"max_downloads\"\r\n\r\n")
            body.appendString("\(maxDownloads)\r\n")
        }

        body.appendString("--\(boundary)--\r\n")
        return body
    }

    /// Parses the server's JSON upload response.
    static func parseUploadResponse(_ data: Data) throws -> UploadResponse {
        do {
            return try JSONDecoder().decode(UploadResponse.self, from: data)
        } catch {
            throw CloudError.invalidResponse
        }
    }

    /// Returns the MIME type for a capture file extension.
    static func mimeType(forFileExtension ext: String) -> String {
        switch ext.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "tiff": return "image/tiff"
        case "heic": return "image/heic"
        case "gif": return "image/gif"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - Data Helper

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
