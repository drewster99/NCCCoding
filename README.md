# NCCCoding

Small helpers that remove the boilerplate of reading and writing `Codable` values as JSON files.

- Encode any `Encodable` value to a file URL, or to a filename in a standard directory (Documents by default).
- Decode any `Decodable` value from a file URL or filename, as a `Result` or an optional.
- Writes are atomic.
- Optional `NCCCodingCodable` conformance adds `encode(to:)` / `init?(from:)` helpers directly on your types.

## Requirements

- iOS 12+ / macOS 10.15+
- Swift 5.2+

## Installation

Add the package with Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/drewster99/NCCCoding.git", from: "1.1.0")
]
```

Then add `"NCCCoding"` to your target's dependencies.

## Usage

```swift
import Foundation
import NCCCoding

struct Settings: Codable {
    var username: String
    var volume: Double
}

let settings = Settings(username: "andrew", volume: 0.8)

// Write to Documents/settings.json
if let error = NCCCoding.encode(settings, filename: "settings.json") {
    print("Save failed: \(error.localizedDescription)")
}

// Read it back, keeping the error
let result: Result<Settings, Error> = NCCCoding.decode(filename: "settings.json")
switch result {
case .success(let loaded):
    print(loaded.username)
case .failure(let error):
    print("Load failed: \(error.localizedDescription)")
}

// Or read it back as an optional (nil on any failure)
let maybeSettings: Settings? = NCCCoding.decode(filename: "settings.json", in: .cachesDirectory)

// Explicit file URLs work too
let url = FileManager.default.temporaryDirectory.appendingPathComponent("settings.json")
let encodeError = NCCCoding.encode(settings, to: url)
let fromURL: Result<Settings, Error> = NCCCoding.decode(url)
```

### Type-level helpers

```swift
struct Profile: Codable, NCCCodingCodable {
    var name: String
}

let profile = Profile(name: "Andrew")
let saveError = profile.encode(filename: "profile.json")   // Error? (nil on success)
let loaded = Profile(from: "profile.json")                 // Profile? (nil on any failure)
```

## Behavior

- **Directories:** filename-based APIs resolve the first matching directory in the user domain and create it if it does not exist. Filenames are appended as-is; no extension is added.
- **Errors:** `Result` and `Error?` APIs return the underlying `EncodingError`, `DecodingError` or Cocoa file error unchanged, except when the directory cannot be resolved, which returns `NCCCoding.NCCCodingError.unableToFindSearchPathDirectory`. The optional-returning APIs return `nil` for every failure, so use the `Result` APIs when you need to tell a missing file from corrupt data. Failures are also logged with `os_log` (error level, private).
- **Dates:** encoded and decoded as ISO 8601 strings. Encoding keeps whole seconds only, so fractional seconds are lost on a round trip.
- **Non-finite floats:** `Double.infinity`, `-Double.infinity` and `Double.nan` are stored as the strings `"+Infinity"`, `"-Infinity"` and `"NaN"`.

## License

MIT. See [LICENSE](LICENSE).
