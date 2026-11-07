//
//  MTAAlertText.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 11/7/26.
//

import Foundation
import MTAFeed

/// Plain-text versions of MTA alert text, which comes as HTML (`<p>`, `<strong>`, `<ul><li>`, `<a>`, `<br>`)
/// with entities such as `&#x200c;`.
extension MTAAlert {
    var plainHeaderText: String {
        AlertText.plain(headerText)
    }

    /// The description without its first line when that just repeats the header, as MTA bus alerts do.
    var plainDescriptionText: String? {
        guard let descriptionText else { return nil }
        var text = AlertText.plain(descriptionText)
        let header = plainHeaderText
        if !header.isEmpty, text.hasPrefix(header) {
            text = String(text.dropFirst(header.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text.isEmpty ? nil : text
    }
}

enum AlertText {
    static func plain(_ html: String) -> String {
        var text = html
        text = text.replacing(/(?i)<br\s*\/?>/, with: "\n")
        text = text.replacing(/(?i)<li[^>]*>/, with: "\n• ")
        text = text.replacing(/(?i)<\/(p|div|li|ul|ol|h[1-6])\s*>/, with: "\n")
        text = text.replacing(/<[^>]*>/, with: "")
        text = decodeEntities(text)
        // Filter scalars, not Characters: U+200C and U+200D are grapheme extenders that merge into the
        // preceding Character, so a Character-level regex never matches them on their own.
        text = String(String.UnicodeScalarView(text.unicodeScalars.compactMap { scalar -> Unicode.Scalar? in
            switch scalar.value {
            case 0x200B...0x200D, 0x2060, 0xFEFF: return nil
            case 0x00A0: return " "
            default: return scalar
            }
        }))

        var lines = [String]()
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.replacing(/[ \t]+/, with: " ").trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty && (lines.last?.isEmpty ?? true) {
                continue
            }
            lines.append(trimmed)
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let namedEntities: [String: String] = [
        "quot": "\"", "apos": "'", "lt": "<", "gt": ">", "nbsp": "\u{00A0}",
        "ndash": "–", "mdash": "—", "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”",
        "hellip": "…", "bull": "•", "amp": "&",
    ]

    private static func decodeEntities(_ text: String) -> String {
        text.replacing(/&(#[xX][0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);/) { match in
            let name = match.output.1
            if name.hasPrefix("#x") || name.hasPrefix("#X") {
                if let value = UInt32(name.dropFirst(2), radix: 16), let scalar = Unicode.Scalar(value) {
                    return String(Character(scalar))
                }
            } else if name.hasPrefix("#") {
                if let value = UInt32(name.dropFirst()), let scalar = Unicode.Scalar(value) {
                    return String(Character(scalar))
                }
            } else if let decoded = namedEntities[String(name)] {
                return decoded
            }
            return String(match.output.0)
        }
    }
}
