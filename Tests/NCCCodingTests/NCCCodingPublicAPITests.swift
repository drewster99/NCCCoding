import XCTest
// A plain (non-@testable) import, so these tests only compile against the public API.
import NCCCoding

final class NCCCodingPublicAPITests: XCTestCase {

    private struct Sample: Codable, Equatable, NCCCodingCodable {
        var name: String
        var number: Int
    }

    // XCTest creates a fresh instance per test method, so every test gets its own file.
    private let temporaryFileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("NCCCodingPublicAPITests_\(UUID().uuidString).json")

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: temporaryFileURL.path) {
            try FileManager.default.removeItem(at: temporaryFileURL)
        }
    }

    /// The error's message must survive being passed around as `any Error`, which is how every API returns it.
    func testErrorDescriptionIsAvailableThroughErrorExistential() {
        let error: Error = NCCCoding.NCCCodingError.unableToFindSearchPathDirectory(directoryType: .documentDirectory)
        XCTAssertTrue(error.localizedDescription.hasPrefix("Unable to find search path directory of type"),
                      "Unexpected localizedDescription: \(error.localizedDescription)")
    }

    func testErrorDescriptionMatchesConcreteLocalizedDescription() {
        let error = NCCCoding.NCCCodingError.unableToFindSearchPathDirectory(directoryType: .cachesDirectory)
        XCTAssertEqual(error.errorDescription, error.localizedDescription)
        XCTAssertEqual((error as Error).localizedDescription, error.localizedDescription)
    }

    /// The NCCCodingCodable protocols must be usable by clients without `@testable import`.
    func testCodableProtocolsRoundTripThroughURL() throws {
        let original = Sample(name: "Zoë 🚀 \u{0301}", number: Int.max)
        let encodeError = original.encode(to: temporaryFileURL)
        XCTAssertNil(encodeError)
        let decoded = Sample(from: temporaryFileURL)
        XCTAssertEqual(decoded, original)
    }

    func testCodableProtocolDecodeFromMissingFileReturnsNil() {
        XCTAssertNil(Sample(from: temporaryFileURL))
    }

    func testDecodeFromMissingFileReturnsFailure() {
        let result: Result<Sample, Error> = NCCCoding.decode(temporaryFileURL)
        guard case .failure = result else {
            return XCTFail("Expected failure decoding a missing file, got \(result)")
        }
    }

    func testDecodeOfMalformedJSONReturnsFailure() throws {
        try Data("{ not json".utf8).write(to: temporaryFileURL)
        let result: Result<Sample, Error> = NCCCoding.decode(temporaryFileURL)
        guard case .failure(let error) = result else {
            return XCTFail("Expected failure decoding malformed JSON, got \(result)")
        }
        XCTAssertTrue(error is DecodingError, "Expected DecodingError, got \(type(of: error)): \(error)")
    }

    func testNonConformingFloatsRoundTrip() throws {
        struct Floats: Codable { var values: [Double] }
        let encodeError = NCCCoding.encode(Floats(values: [.infinity, -.infinity, .nan, 1.5]), to: temporaryFileURL)
        XCTAssertNil(encodeError)
        let result: Result<Floats, Error> = NCCCoding.decode(temporaryFileURL)
        let decoded = try result.get()
        XCTAssertEqual(decoded.values.count, 4)
        XCTAssertEqual(decoded.values[0], .infinity)
        XCTAssertEqual(decoded.values[1], -.infinity)
        XCTAssertTrue(decoded.values[2].isNaN)
        XCTAssertEqual(decoded.values[3], 1.5)
    }
}
