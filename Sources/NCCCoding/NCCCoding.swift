//
//  NCCCoding.swift
//  NCCCoding
//
//  Created by Andrew Benson on 4/21/20.
//  Copyright (c) 2020-2026 Andrew Benson. Licensed under the MIT License; see LICENSE.
//

import Foundation
#if canImport(os)
import os
#endif

/// Happy wrappers to remove boilerplate from encoding/decoding with Codable.
public struct NCCCoding {

    /// Errors originating in NCCCoding itself. Encoding, decoding and file I/O failures are passed through
    /// unchanged as the underlying `EncodingError`, `DecodingError` or Cocoa error.
    public enum NCCCodingError: LocalizedError {
        /// The directory of the given type could not be located (or created) in the user domain.
        case unableToFindSearchPathDirectory(directoryType: FileManager.SearchPathDirectory)

        /// A human-readable description of the error.
        ///
        /// Prefer `errorDescription` or `(error as Error).localizedDescription`; this property exists for
        /// source compatibility and returns the same text.
        public var localizedDescription: String {
            switch self {
            case .unableToFindSearchPathDirectory(let dir):
                return "Unable to find search path directory of type \(dir)"
            }
        }

        /// The same text as `localizedDescription`, exposed through `LocalizedError` so it survives when the error is
        /// handled as `any Error`.
        public var errorDescription: String? {
            localizedDescription
        }
    }

    /// Fetches the URL of the first directory matching the given search path directory in `.userDomainMask`.
    ///
    /// The directory is created if it does not already exist.
    ///
    /// - Parameter dirType: The search path directory to locate, such as `.documentDirectory`.
    /// - Returns: The directory URL on `.success`, or `NCCCodingError.unableToFindSearchPathDirectory` on `.failure`.
    public static func url(for dirType: FileManager.SearchPathDirectory) -> Result<URL, Error> {
        do {
            let url = try FileManager.default.url(for: dirType, in: .userDomainMask, appropriateFor: nil, create: true)
            return .success(url)
        } catch {
            return .failure(NCCCodingError.unableToFindSearchPathDirectory(directoryType: dirType))
        }
    }

    /// Creates a URL with the specified filename in the given search path directory.
    ///
    /// The directory is created if it does not already exist. The filename is appended as-is.
    ///
    /// - Parameters:
    ///   - filename: The filename to append to the directory URL.
    ///   - dirType: The search path directory to locate, such as `.documentDirectory`.
    /// - Returns: The file URL on `.success`, or `NCCCodingError.unableToFindSearchPathDirectory` on `.failure`.
    public static func url(for filename: String, in dirType: FileManager.SearchPathDirectory) -> Result<URL, Error> {
        let result: Result<URL, Error> = url(for: dirType)
        switch result {
        case .success(let url):
            return .success(url.appendingPathComponent(filename))
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Decodes a value from the file described by filename and directoryType.
    ///
    /// Use the `Result`-returning overload when the caller needs to distinguish a missing file from corrupt data.
    ///
    /// - Parameters:
    ///   - filename: The source filename, relative to the first directory found matching directoryType.
    ///   - directoryType: The type of directory containing the encoded file.
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
    ///   - directoryType: The type of directory containing the encoded file.
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
    /// Use the `Result`-returning overload when the caller needs to distinguish a missing file from corrupt data.
    ///
    /// - Parameter url: The URL specifying the file from which to decode.
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
    /// Dates are decoded as ISO 8601 strings; non-conforming floats as `"+Infinity"`, `"-Infinity"` and `"NaN"`.
    ///
    /// - Parameter url: The URL specifying the file from which to decode.
    /// - Returns: Result with the decoded value on .success, or the error on .failure, as appropriate.
    public static func decode<T: Decodable>(_ url: URL) -> Result<T, Error> {
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.nonConformingFloatDecodingStrategy = .convertFromString(
                positiveInfinity: NonConformingFloatRepresentation.positiveInfinity,
                negativeInfinity: NonConformingFloatRepresentation.negativeInfinity,
                nan: NonConformingFloatRepresentation.nan)
            return .success(try decoder.decode(T.self, from: data))
        } catch {
            logFailure("Decoding \(T.self) from \(url.path) failed: \(error)")
            return .failure(error)
        }
    }


    /// Encodes a value conforming to Encodable and stores it in a file specified by filename in the first directory
    /// specified by directoryType.
    ///
    /// - Parameters:
    ///   - value: A value conforming to Encodable.
    ///   - filename: The destination filename. The filename is used as-is, without adding ".json", etc.
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
    /// The file is written atomically. Dates are encoded as ISO 8601 strings with whole-second precision;
    /// non-conforming floats as `"+Infinity"`, `"-Infinity"` and `"NaN"`.
    ///
    /// - Parameters:
    ///   - value: A value conforming to Encodable.
    ///   - url: The destination file URL.
    /// - Returns: Nil on success, or Error if failure.
    public static func encode<T: Encodable>(_ value: T, to url: URL) -> Error? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: NonConformingFloatRepresentation.positiveInfinity,
            negativeInfinity: NonConformingFloatRepresentation.negativeInfinity,
            nan: NonConformingFloatRepresentation.nan)
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
            return nil
        } catch {
            logFailure("Encoding \(type(of: value)) to \(url.path) failed: \(error)")
            return error
        }
    }

    /// The JSON strings used for non-conforming floating-point values; encoder and decoder must agree.
    private enum NonConformingFloatRepresentation {
        static let positiveInfinity = "+Infinity"
        static let negativeInfinity = "-Infinity"
        static let nan = "NaN"
    }

    #if canImport(os)
    private static let log = OSLog(subsystem: "NCCCoding", category: "NCCCoding")
    #endif

    /// Logs failures for diagnostics; the error is always returned to the caller as well.
    private static func logFailure(_ message: String) {
        #if canImport(os)
        // File paths can identify the user, so the message is private outside a debugger.
        os_log("%{private}@", log: log, type: .error, message)
        #endif
    }
}

/// A type that can write itself to, and read itself from, a JSON file using `NCCCoding`.
public typealias NCCCodingCodable = NCCCodingEncodable & NCCCodingDecodable

/// An `Encodable` type that can write itself to a JSON file using `NCCCoding`.
///
/// Default implementations are provided; conforming types need no additional code.
public protocol NCCCodingEncodable where Self: Encodable {
    /// Encodes `self` as JSON into the file named `filename` in the first directory matching `directoryType`.
    ///
    /// - Returns: Nil on success, or the error on failure.
    func encode(filename: String,
                in directoryType: FileManager.SearchPathDirectory) -> Error?

    /// Encodes `self` as JSON into the file at `url`.
    ///
    /// - Returns: Nil on success, or the error on failure.
    func encode(to url: URL) -> Error?
}

extension NCCCodingEncodable {

    /// Encodes `self` as JSON into the file named `filename` in the first directory matching `directoryType`.
    ///
    /// - Parameters:
    ///   - filename: The destination filename, used as-is.
    ///   - directoryType: The type of directory in which to store the encoded file.
    /// - Returns: Nil on success, or the error on failure.
    public func encode(filename: String,
                       in directoryType: FileManager.SearchPathDirectory = .documentDirectory) -> Error? {
        NCCCoding.encode(self, filename: filename, in: directoryType)
    }

    /// Encodes `self` as JSON into the file at `url`.
    ///
    /// - Parameter url: The destination file URL.
    /// - Returns: Nil on success, or the error on failure.
    public func encode(to url: URL) -> Error? {
        NCCCoding.encode(self, to: url)
    }
}

/// A `Decodable` type that can create itself from a JSON file using `NCCCoding`.
///
/// Default implementations are provided; conforming types need no additional code.
public protocol NCCCodingDecodable where Self: Decodable {
    /// Decodes an instance from the JSON file at `url`, or returns nil on any failure.
    init?(from url: URL)

    /// Decodes an instance from the JSON file named `filename` in the first directory matching `directoryType`,
    /// or returns nil on any failure.
    init?(from filename: String, in directoryType: FileManager.SearchPathDirectory)
}

extension NCCCodingDecodable {

    /// Decodes an instance from the JSON file at `url`.
    ///
    /// Failure reasons are not reported; use `NCCCoding.decode(_:)` returning `Result` when they matter.
    ///
    /// - Parameter url: The URL of the file from which to decode.
    public init?(from url: URL) {
        guard let result: Self = NCCCoding.decode(url) else { return nil }
        self = result
    }

    /// Decodes an instance from the JSON file named `filename` in the first directory matching `directoryType`.
    ///
    /// Failure reasons are not reported; use `NCCCoding.decode(filename:in:)` returning `Result` when they matter.
    ///
    /// - Parameters:
    ///   - filename: The source filename, used as-is.
    ///   - directoryType: The type of directory containing the encoded file.
    public init?(from filename: String, in directoryType: FileManager.SearchPathDirectory = .documentDirectory) {
        guard let result: Self = NCCCoding.decode(filename: filename, in: directoryType) else {
            return nil
        }
        self = result
    }
}
