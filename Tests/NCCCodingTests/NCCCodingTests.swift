import XCTest
@testable import NCCCoding

final class NCCCodingTests: XCTestCase {

    // Crappy test is extremely basic -- fix this some day
    func testEncodeDecode() {

        print("Creating a url to use")
        let filename = "nccCodingTests_\(UUID().uuidString)"
        let result = NCCCoding.url(for: filename, in: .documentDirectory)
        var urlToUse: URL?
        switch result {
        case .failure(let error):
            XCTFail("Received error from NCCCoding.url: \(error.localizedDescription)")
            return
        case .success(let url):
            XCTAssertEqual(url.lastPathComponent, filename)
            urlToUse = url
        }

        XCTAssertNotNil(urlToUse, "nil URL")
        guard let url = urlToUse else {
            return
        }
        print("Got url \(url.absoluteString)")

        struct TestStruct: Codable, Equatable {
            let name: String
            let number: Int
        }

        let testStruct = TestStruct(name: "Andrew Benson", number: 42)

        // test encoding
        print("Encoding and storing a simple struct.")
        let error = NCCCoding.encode(testStruct, to: url)
        XCTAssertNil(error, "NCCCoding.encode: Error: \(error!.localizedDescription)")

        // Now that we created a file, make sure we clean it up later
        defer {
            print("Removing temp file at \(url.absoluteString)")
            do { try FileManager.default.removeItem(at: url) }
            catch {
                print("Couldn't remove temp file: \(error.localizedDescription)")
            }
        }

        // test decoding
        print("Retrieving a simple struct and comparing to original")
        var decoded: TestStruct?
        decoded = NCCCoding.decode(filename: filename)
        XCTAssertNotNil(decoded, "NCCCoding.decode returned nil")
        if let decoded = decoded {
            XCTAssertEqual(testStruct,
                           decoded,
                           "Decoded struct does not match original encoded one.")
        }
    }

    static var allTests = [
        ("encode/decode", testEncodeDecode),
    ]
}
