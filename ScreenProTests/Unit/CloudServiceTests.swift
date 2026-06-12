import XCTest
@testable import ScreenPro

/// Unit tests for CloudService request building and response parsing (007-cloud-polish).
final class CloudServiceTests: XCTestCase {

    // MARK: - UploadConfig

    func testUploadConfig_defaultsToNoRestrictions() {
        let config = CloudService.UploadConfig()

        XCTAssertNil(config.expiresIn)
        XCTAssertNil(config.password)
        XCTAssertNil(config.maxDownloads)
    }

    // MARK: - Multipart Body

    func testMakeMultipartBody_containsFilePart() throws {
        let payload = Data("hello".utf8)
        let body = CloudService.makeMultipartBody(
            boundary: "BOUNDARY",
            data: payload,
            filename: "Screenshot.png",
            mimeType: "image/png",
            config: CloudService.UploadConfig()
        )

        let bodyString = try XCTUnwrap(String(data: body, encoding: .utf8))
        XCTAssertTrue(bodyString.contains("--BOUNDARY\r\n"))
        XCTAssertTrue(bodyString.contains("Content-Disposition: form-data; name=\"file\"; filename=\"Screenshot.png\""))
        XCTAssertTrue(bodyString.contains("Content-Type: image/png"))
        XCTAssertTrue(bodyString.contains("hello"))
        XCTAssertTrue(bodyString.hasSuffix("--BOUNDARY--\r\n"))
    }

    func testMakeMultipartBody_omitsConfigFieldsWhenUnset() throws {
        let body = CloudService.makeMultipartBody(
            boundary: "BOUNDARY",
            data: Data(),
            filename: "f.png",
            mimeType: "image/png",
            config: CloudService.UploadConfig()
        )

        let bodyString = try XCTUnwrap(String(data: body, encoding: .utf8))
        XCTAssertFalse(bodyString.contains("expires_in"))
        XCTAssertFalse(bodyString.contains("password"))
        XCTAssertFalse(bodyString.contains("max_downloads"))
    }

    func testMakeMultipartBody_includesExpiryPasswordAndMaxDownloads() throws {
        let config = CloudService.UploadConfig(
            expiresIn: 3600,
            password: "secret",
            maxDownloads: 5
        )
        let body = CloudService.makeMultipartBody(
            boundary: "BOUNDARY",
            data: Data(),
            filename: "f.png",
            mimeType: "image/png",
            config: config
        )

        let bodyString = try XCTUnwrap(String(data: body, encoding: .utf8))
        XCTAssertTrue(bodyString.contains("name=\"expires_in\"\r\n\r\n3600\r\n"))
        XCTAssertTrue(bodyString.contains("name=\"password\"\r\n\r\nsecret\r\n"))
        XCTAssertTrue(bodyString.contains("name=\"max_downloads\"\r\n\r\n5\r\n"))
    }

    // MARK: - Response Parsing

    func testParseUploadResponse_decodesValidResponse() throws {
        let json = """
        {
            "id": "abc123",
            "url": "https://share.example.com/abc123",
            "delete_token": "tok-456",
            "expires_at": "2026-07-01T12:00:00Z"
        }
        """

        let response = try CloudService.parseUploadResponse(Data(json.utf8))

        XCTAssertEqual(response.id, "abc123")
        XCTAssertEqual(response.url, "https://share.example.com/abc123")
        XCTAssertEqual(response.deleteToken, "tok-456")
        XCTAssertEqual(response.expiresAt, "2026-07-01T12:00:00Z")
    }

    func testParseUploadResponse_allowsMissingExpiry() throws {
        let json = """
        {"id": "a", "url": "https://x.example/a", "delete_token": "t"}
        """

        let response = try CloudService.parseUploadResponse(Data(json.utf8))

        XCTAssertNil(response.expiresAt)
    }

    func testParseUploadResponse_throwsInvalidResponseForGarbage() {
        XCTAssertThrowsError(try CloudService.parseUploadResponse(Data("not json".utf8))) { error in
            XCTAssertEqual(error as? CloudError, .invalidResponse)
        }
    }

    // MARK: - Link Expiry

    func testLinkExpiry_timeIntervals() {
        XCTAssertNil(LinkExpiry.never.timeInterval)
        XCTAssertEqual(LinkExpiry.oneHour.timeInterval, 3600)
        XCTAssertEqual(LinkExpiry.oneDay.timeInterval, 86400)
        XCTAssertEqual(LinkExpiry.oneWeek.timeInterval, 604800)
        XCTAssertEqual(LinkExpiry.oneMonth.timeInterval, 2_592_000)
    }

    // MARK: - MIME Types

    func testMimeType_mapsKnownExtensions() {
        XCTAssertEqual(CloudService.mimeType(forFileExtension: "png"), "image/png")
        XCTAssertEqual(CloudService.mimeType(forFileExtension: "JPG"), "image/jpeg")
        XCTAssertEqual(CloudService.mimeType(forFileExtension: "gif"), "image/gif")
        XCTAssertEqual(CloudService.mimeType(forFileExtension: "mp4"), "video/mp4")
        XCTAssertEqual(CloudService.mimeType(forFileExtension: "weird"), "application/octet-stream")
    }
}
