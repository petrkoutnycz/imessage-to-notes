import Foundation

public struct TrackedContact: Codable, Equatable, Sendable {
    public var name: String
    public var handles: [String]

    public init(name: String, handles: [String]) {
        self.name = name
        self.handles = handles
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
        trackedContacts.first { $0.handles.contains(handle) }
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
