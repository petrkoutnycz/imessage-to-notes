import Foundation
import SQLite3

enum SQLiteValue: Equatable {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)

    var integer: Int64? {
        if case .integer(let value) = self { value } else { nil }
    }

    var real: Double? {
        switch self {
        case .real(let value): value
        case .integer(let value): Double(value)
        default: nil
        }
    }

    var text: String? {
        if case .text(let value) = self { value } else { nil }
    }
}

public struct SQLiteError: Error, CustomStringConvertible {
    public var description: String
}

/// A thin wrapper over the SQLite C API.
final class SQLiteDatabase {
    enum Mode {
        case readOnly
        case readWriteCreate
    }

    private let handle: OpaquePointer

    init(path: String, mode: Mode) throws {
        let flags = switch mode {
        case .readOnly: SQLITE_OPEN_READONLY
        case .readWriteCreate: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        }
        var handle: OpaquePointer?
        let result = sqlite3_open_v2(path, &handle, flags, nil)
        guard result == SQLITE_OK, let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "code \(result)"
            sqlite3_close_v2(handle)
            throw SQLiteError(description: "Cannot open \(path): \(message)")
        }
        self.handle = handle
        sqlite3_busy_timeout(handle, 5_000)
    }

    deinit {
        sqlite3_close_v2(handle)
    }

    func execute(_ sql: String) throws {
        guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else {
            throw error()
        }
    }

    @discardableResult
    func query(_ sql: String, _ bindings: [SQLiteValue] = []) throws -> [[SQLiteValue]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw error()
        }
        defer { sqlite3_finalize(statement) }

        for (index, value) in bindings.enumerated() {
            let position = Int32(index + 1)
            switch value {
            case .null: sqlite3_bind_null(statement, position)
            case .integer(let value): sqlite3_bind_int64(statement, position, value)
            case .real(let value): sqlite3_bind_double(statement, position, value)
            case .text(let value): sqlite3_bind_text(statement, position, value, -1, transient)
            }
        }

        var rows: [[SQLiteValue]] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                rows.append((0..<sqlite3_column_count(statement)).map { column(statement, $0) })
            case SQLITE_DONE:
                return rows
            default:
                throw error()
            }
        }
    }

    /// `?, ?, ?` for an `IN (...)` list of `count` values.
    static func placeholders(count: Int) -> String {
        Array(repeating: "?", count: count).joined(separator: ", ")
    }

    private func column(_ statement: OpaquePointer?, _ index: Int32) -> SQLiteValue {
        switch sqlite3_column_type(statement, index) {
        case SQLITE_INTEGER: .integer(sqlite3_column_int64(statement, index))
        case SQLITE_FLOAT: .real(sqlite3_column_double(statement, index))
        case SQLITE_TEXT: .text(String(cString: sqlite3_column_text(statement, index)))
        default: .null
        }
    }

    private func error() -> SQLiteError {
        SQLiteError(description: String(cString: sqlite3_errmsg(handle)))
    }
}

/// SQLite copies a bound value when the destructor is SQLITE_TRANSIENT.
private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
