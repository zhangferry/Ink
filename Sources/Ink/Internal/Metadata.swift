/**
*  Ink
*  Copyright (c) John Sundell 2019
*  MIT license, see LICENSE file for details
*/

internal struct Metadata: Readable {
    var values = [String : String]()

    static func read(using reader: inout Reader) throws -> Metadata {
        try require(reader.readCount(of: "-") == 3)
        try reader.read("\n")

        var metadata = Metadata()
        var lastKey: String?

        while !reader.didReachEnd {
            reader.discardWhitespacesAndNewlines()

            guard reader.currentCharacter != "-" else {
                try require(reader.readCount(of: "-") == 3)
                return metadata
            }

            let key = try trim(reader.read(until: ":", required: false))

            guard reader.previousCharacter == ":" else {
                if let lastKey = lastKey {
                    metadata.values[lastKey]?.append(" " + key)
                }

                continue
            }

            var value = trim(reader.readUntilEndOfLine())
            // tags 有两种编写方式：同一行数组或者yml格式，对yml格式额外处理下
            if value.isEmpty && key == "tags" {
                // 先后遍历空行
                var tags: [String] = []
                var shouldSkip = false
                
                while !shouldSkip {
                    reader.discardWhitespacesAndNewlines()
                    // 为了防止和metadata的结尾标识符混淆
                    if reader.currentCharacter == "-" && reader.nextCharacter == " " {
                        reader.advanceIndex()
                        let tag = trim(reader.readUntilEndOfLine())
                        tags.append(tag)
                    } else {
                        shouldSkip = true
                    }
                }
                value = tags.joined(separator: ",")
            }

            if !value.isEmpty {
                metadata.values[key] = value
                lastKey = key
            }
        }

        throw Reader.Error()
    }

    func applyingModifiers(_ modifiers: ModifierCollection) -> Self {
        var modified = self

        modifiers.applyModifiers(for: .metadataKeys) { modifier in
            for (key, value) in modified.values {
                let newKey = modifier.closure((key, Substring(key)))
                modified.values[key] = nil
                modified.values[newKey] = value
            }
        }

        modifiers.applyModifiers(for: .metadataValues) { modifier in
            modified.values = modified.values.mapValues { value in
                modifier.closure((value, Substring(value)))
            }
        }

        return modified
    }
}

private extension Metadata {
    static func trim(_ string: Substring) -> String {
        String(string
            .trimmingLeadingWhitespaces()
            .trimmingTrailingWhitespaces()
        )
    }
}
