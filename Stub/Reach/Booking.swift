import Foundation

/// The words of a booking, as a confirmation email hands them over when its text is selected and shared: one line per line,
/// blank lines and runs of spaces gone, and the long tail of terms and footers cut, so the parsers read the ticket and not
/// the small print (docs/decisions/002-surfaces.md). Foundation only.
enum Booking {
    /// No booking needs more than this many lines to say what the ticket is.
    static let longest = 80

    static func lines(_ text: String) -> [String] {
        let lines: [String] = text.split(whereSeparator: \.isNewline)
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Array(lines.prefix(longest))
    }
}
