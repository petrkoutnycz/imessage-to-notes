/// A failure in one of the real adapters, with a message for the run output.
struct AdapterError: Error, CustomStringConvertible {
    var description: String
    init(_ description: String) { self.description = description }
}
