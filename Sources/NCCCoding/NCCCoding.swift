//
//  NCCCoding.swift
//  NCCCoding
//
//  Created by Andrew Benson on 4/21/20.
//  Copyright © 2020 Nuclear Cyborg Corp. All rights reserved.
//

import Foundation

/// Happy wrappers to remove boilerplate from encoding/decoding with Codable.
public struct NCCCoding {

    /// Encoding or Decoding error specific to NCCCoding.
    public enum NCCCodingError: Error {
        case unableToFindSearchPathDirectory(directoryType: FileManager.SearchPathDirectory)

        public var localizedDescription: String {
            switch self {
            case .unableToFindSearchPathDirectory(let dir):
                return "Unable to find search path directory of type \(dir)"
            }
        }
    }

    /// Fetches the URL of the first directory matching the given search path directory in .userDomainMask.
    public static func url(for dirType: FileManager.SearchPathDirectory) -> Result<URL, Error> {
        do {
            let url = try FileManager.default.url(for: dirType, in: .userDomainMask, appropriateFor: nil, create: true)
            return .success(url)
        } catch {
            return .failure(NCCCodingError.unableToFindSearchPathDirectory(directoryType: dirType))
        }
    }

    /// Creates a URL with the specified filename in the given search path directory.
    public static func url(for filename: String, in dirType: FileManager.SearchPathDirectory) -> Result<URL, Error> {
        let result: Result<URL, Error> = url(for: dirType)
        switch result {
        case .success(let url):
            return .success(url.appendingPathComponent(filename))
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Decodes a value from the file described by filename and directoryType
    ///
    /// - Parameters:
    ///   - filename: The source filename, relative to the first directory found matching directoryType.
    ///   - directoryType: The type of directory in which to store the encoded file.
    /// - Returns: The decoded value on success, or nil on failure.
    public static func decode<T: Decodable>(filename: String,
                                            in directoryType: FileManager.SearchPathDirectory = .documentDirectory) -> T? {
        let decodeResult: Result<T, Error> = decode(filename: filename, in: directoryType)
        switch decodeResult {
        case .success(let value):
            return value
        case .failure(_):
            return nil
        }
    }

    /// Decodes a value from the file described by filename and directoryType.
    ///
    /// - Parameters:
    ///   - filename: The source filename, relative to the first directory found matching directoryType.
    ///   - directoryType: The type of directory in which to store the encoded file.
    /// - Returns: Result with the decoded value on .success, or the error on .failure, as appropriate.
    public static func decode<T: Decodable>(filename: String,
                                            in directoryType: FileManager.SearchPathDirectory = .documentDirectory) -> Result<T, Error> {
        let urlResult = url(for: filename, in: directoryType)
        switch urlResult {
        case .success(let url):
            return decode(url)
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Decodes a value from the file pointed to by URL.
    ///
    /// - Parameter url: The URL specifiying the file from which to decode.
    /// - Returns: The decoded value on success, or nil on failure.
    public static func decode<T: Decodable>(_ url: URL) -> T? {
        let result: Result<T, Error> = decode(url)
        switch result {
        case .success(let value):
            return value
        case .failure(_):
            return nil
        }
    }


    /// Decodes a value from the file pointed to by URL.
    ///
    /// - Parameter url: The URL specifiying the file from which to decode.
    /// - Returns: Result with the decoded value on .success, or the error on .failure, as appropriate.
    public static func decode<T: Decodable>(_ url: URL) -> Result<T, Error> {
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "+Infinity",
                                                                            negativeInfinity: "-Infinity",
                                                                            nan: "NaN")
            return .success(try decoder.decode(T.self, from: data))
        } catch {
            print("\(#function) of \(url.path) failed: \(error)")
            return .failure(error)
        }
    }


    /// Encodes a value conforming to Encodable and stores in a file specified by filename in the first directory
    /// specified by directoryType.
    ///
    /// - Parameters:
    ///   - value: A value conforming to Encodable.
    ///   - filename: The destination filename.  Note: The filename is used as-is, without adding ".json", etc..
    ///   - directoryType: The type of directory in which to store the encoded file.
    /// - Returns: Nil on success, or Error if failure.
    public static func encode<T: Encodable>(_ value: T, filename: String,
                                            in directoryType: FileManager.SearchPathDirectory = .documentDirectory) -> Error? {
        let urlResult = url(for: filename, in: directoryType)
        switch urlResult {
        case .success(let url):
            return encode(value, to: url)
        case .failure(let error):
            return error
        }
    }

    /// Encodes a value conforming to Encodable and stores the resulting JSON in the file given by the URL.
    ///
    /// - Parameters:
    ///   - value: A value conforming to Encodable.
    ///   - url: The destination file URL.
    /// - Returns: Nil on success, or Error if failure.
    public static func encode<T: Encodable>(_ value: T, to url: URL) -> Error? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "+Infinity",
                                                                      negativeInfinity: "-Infinity",
                                                                      nan: "NaN")
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
            return nil
        } catch {
            print("\(#function) to \(url.path) of \(type(of: value)) failed: \(error)")
            return error
        }
    }
}

typealias NCCCodingCodable = NCCCodingEncodable & NCCCodingDecodable

protocol NCCCodingEncodable where Self: Encodable {
    func encode(filename: String,
                in directoryType: FileManager.SearchPathDirectory) -> Error?
    func encode(to url: URL) -> Error?
}
extension NCCCodingEncodable {

    func encode(filename: String,
                in directoryType: FileManager.SearchPathDirectory = .documentDirectory) -> Error? {
        NCCCoding.encode(self, filename: filename, in: directoryType)
    }

    func encode(to url: URL) -> Error? {
        NCCCoding.encode(self, to: url)
    }
}

protocol NCCCodingDecodable where Self: Decodable {
    init?(from url: URL)
    init?(from filename: String, in directoryType: FileManager.SearchPathDirectory)

}
extension NCCCodingDecodable {
    init?(from url: URL) {
        guard let result: Self = NCCCoding.decode(url) else { return nil }
        self = result
    }

    init?(from filename: String, in directoryType: FileManager.SearchPathDirectory = .documentDirectory) {
        guard let result: Self = NCCCoding.decode(filename: filename, in: directoryType) else {
            return nil
        }
        self = result
    }
}
