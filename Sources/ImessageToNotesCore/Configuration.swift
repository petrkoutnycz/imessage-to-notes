import Foundation

public struct TrackedContact: Codable, Equatable, Sendable {
    public var name: String
    public var handles: [String]

    public init(name: String, handles: [String]) {
        self.name = name
        self.handles = handles
    }

    /// True when `handle` is one of the Handles of this Tracked Contact, in any format.
    public func uses(_ handle: String) -> Bool {
        handles.map(Handle.normalized).contains(Handle.normalized(handle))
    }
}

/// How two Handles compare. A phone number counts by its digits only, so spaces and punctuation
/// do not matter, and both sides use international format with the country code.
/// An email address counts without regard to letter case.
public enum Handle {
    public static func normalized(_ handle: String) -> String {
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("@") {
            return trimmed.lowercased()
        }
        return String(trimmed.filter(\.isASCII).filter(\.isNumber))
    }
}

/// The JSON configuration file in the tool's Application Support folder.
public struct Configuration: Codable, Equatable, Sendable {
    public var trackedContacts: [TrackedContact]
    public var notesFolder: String
    public var claudeModel: String

    public init(trackedContacts: [TrackedContact], notesFolder: String, claudeModel: String) {
        self.trackedContacts = trackedContacts
        self.notesFolder = notesFolder
        self.claudeModel = claudeModel
    }
}

extension Configuration {
    /// Every Handle of every Tracked Contact.
    public var handles: [String] {
        trackedContacts.flatMap(\.handles)
    }

    public func trackedContact(for handle: String) -> TrackedContact? {
        trackedContacts.first { $0.uses(handle) }
    }

    public static func load(from url: URL) throws -> Configuration {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ConfigurationError(description: "Cannot read the configuration file at \(url.path): \(error.localizedDescription)")
        }
        do {
            return try JSONDecoder().decode(Configuration.self, from: data)
        } catch {
            throw ConfigurationError(description: "The configuration file at \(url.path) is not valid: \(error)")
        }
    }
}

public struct ConfigurationError: Error, CustomStringConvertible {
    public var description: String
}
