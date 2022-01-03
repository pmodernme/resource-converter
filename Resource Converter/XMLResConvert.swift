//
//  XMLResConvert.swift
//  ResourceConverter
//
//  Created by Zoe Van Brunt on 1/2/22.
//

import Foundation
import ConsoleKit

struct XMLStringsResConvert: Command {
    struct Signature: CommandSignature {
        
        @Argument(name: "sourcePath", help: "The path to the strings.xml file to convert")
        var sourcePath: String
        
        @Argument(name: "destinationPath", help: "The destination directory for the Localizable.strings and Localizable.stringdict generated.")
        var destinationPath: String
        
        @Flag(name: "overwrite", short: "o", help: "Overwrites the existing Localizable files")
        var overwrite: Bool
    }
    
    static var name = "strings"
    let help = "This command will convert a strings.xml file into Localizable.strings and Localizable.stringsdict files."
    
    func run(using context: CommandContext, signature: Signature) throws {
        let xml = loadXML(path: signature.sourcePath)
        
        let strings = try parseStrings(xml: xml)
        
        try saveStringsFile(strings: strings, filename: "Localizable.strings", destinationPath: signature.destinationPath, context: context, forceOverwrite: signature.overwrite)
        
        let plurals = try parsePlurals(xml: xml)
        
        try saveStringsFile(strings: plurals, filename: "Localizable.stringsdict", destinationPath: signature.destinationPath, context: context, forceOverwrite: signature.overwrite)
    }
    
    func loadXML(path: String) -> String {
        guard let data = FileManager.default.contents(atPath: path),
              let xml = String(data: data, encoding: .utf8) else {
                  fatalError("Could not load contents of xml file at path: \(path)")
              }
        return xml
    }
    
    func parseStrings(xml: String) throws -> String {
        let regex = try NSRegularExpression(pattern: stringPattern, options: [])
        let nsrange = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        
        let result = regex
            .matches(in: xml, options: [], range: nsrange).compactMap({ match -> String? in
                guard let name = getString(source: xml, match: match, key: "name"),
                      let value = getString(source: xml, match: match, key: "value")
                else {
                    print("Could not parse a match. Ignoring...")
                    return nil
                }
                return "\(name) = \"\(value)\";"
            })
            .joined(separator: "\n")
        
        return result
    }
    
    func saveStringsFile(
        strings: String,
        filename: String,
        destinationPath: String,
        context: CommandContext,
        forceOverwrite: Bool
    ) throws {
        let path = URL(fileURLWithPath: destinationPath, isDirectory: true)
            .appendingPathComponent(filename, isDirectory: false)
        if !forceOverwrite,
           FileManager.default.fileExists(atPath: path.path) {
            let shouldOverwrite = context.console.choose("Strings file already exists at destination location.", from: ["Y", "N"]) { option in
                switch option {
                    case "Y": return "Overwrite existing \(filename)"
                    case "N": return "Skip this step"
                    default: return "Unknown option"
                }
            }
            if shouldOverwrite == "N" {
                print("Skipping Localizable.strings...")
                return
            }
        }
        try strings.write(toFile: path.path, atomically: false, encoding: .utf8)
    }
    
    func parsePlurals(xml: String) throws -> String {
        let pluralsRegex = try NSRegularExpression(pattern: pluralGroupPattern, options: [])
        let itemsRegex = try NSRegularExpression(pattern: pluralItemGroupPattern, options: [])
        
        let pluralsNSRange = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        
        let body = pluralsRegex
            .matches(in: xml, options: [], range: pluralsNSRange)
            .compactMap({ match -> String? in
                guard let name = getString(source: xml, match: match, key: "name")
                else {
                    print("Could not parse a match. Ignoring...")
                    return nil
                }
                
                let itemResults = itemsRegex
                    .matches(in: xml, options: [], range: match.range(withName: "items"))
                    .compactMap({ match -> String? in
                        guard let quantity = getString(source: xml, match: match, key: "quantity"),
                              let value = getString(source: xml, match: match, key: "value")
                        else {
                            return nil
                        }
                        
                        var result = ""
                        if let comment = getString(source: xml, match: match, key: "comment") {
                            let lines = comment
                                .split(separator: "\n")
                                .compactMap({
                                    let line = $0.trimmingCharacters(in: .whitespaces)
                                    if line.isEmpty { return nil }
                                    return line
                                })
                                .joined(separator: "\n")
                            result += """
                                <!-- \(lines) -->
                """
                        }
                        
                        result += """
                                <key>\(quantity)</key>
                                <string>\(value)</string>
                """
                        return result
                    })
                    .joined(separator: "\n")
                
                return """
                        <key>\(name)</key>
                        <dict>
                            <key>NSStringLocalizedFormatKey</key>
                            <string>%#@COUNT@</string>
                            <key>COUNT</key>
                            <dict>
                                <key>NSStringFormatSpecTypeKey</key>
                                <string>NSStringPluralRuleType</string>
                                <key>NSStringFormatValueTypeKey</key>
                                <string>d</string>
                \(itemResults)
                            </dict>
                        </dict>
                """
            })
            .joined(separator: "\n")
        
        let result =
                """
                <?xml version="1.0" encoding="UTF-8"?>
                <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
                <plist version="1.0">
                    <dict>
                \(body)
                    </dict>
                </plist>
                """
        
        return result
    }
    
    func getString(source: String, match: NSTextCheckingResult, key: String) -> Substring? {
        let nsRange = match.range(withName: key)
        guard nsRange.location != NSNotFound,
              let range = Range(nsRange, in: source) else {
                  return nil
              }
        return source[range]
    }
}

let pluralGroupPattern = #"""
(?xi)
(?-x:<plurals\s+name=)
(?<name>".*")
(?-x:>)
(?<items>[\s\S]*?)
(?-x:<\/plurals>)
"""#

let pluralItemGroupPattern = #"""
(?xi)
(?:
    (?<item>
        (?:<!--
            (?<comment>[\s\S]*?)
        -->\s*)?
    <item\hquantity="
        (?<quantity>[\s\S]*?)
    ">
        (?<value>[\s\S]*?)
    <\/item>)
)
"""#

let stringPattern = #"""
(?xi)
(?-x:<string\s+name=)
    (?<name>".*")
(?-x:\s*>\s*)
    (?<value>.*)
(?-x:\s*<\/string>)
"""#

