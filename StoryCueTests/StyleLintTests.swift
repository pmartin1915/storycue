import Foundation
import XCTest

final class StyleLintTests: XCTestCase {
    private struct AssetCatalog: Decodable {
        let colors: [AssetColor]
    }

    private struct AssetColor: Decodable {
        struct ColorValue: Decodable {
            let components: [String: String]
        }

        struct Appearance: Decodable {
            let appearance: String
            let value: String
        }

        let appearances: [Appearance]?
        let color: ColorValue
    }

    private struct RGB {
        let red: Double
        let green: Double
        let blue: Double
    }

    private enum Luminosity: String, CaseIterable, Hashable {
        case universal
        case dark
    }

    private var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // StoryCueTests/
            .deletingLastPathComponent()   // project root
    }

    func testNoFixedFontSizes() throws {
        try assertNoSourceMatch(literal: ".system(size:")
    }

    func testNoLiteralCornerRadius() throws {
        try assertNoSourceMatch(
            regex: #"cornerRadius:\s*[0-9]"#,
            excluding: ["DesignTokens.swift"]
        )
    }

    func testNoLiteralColorsOutsideTokens() throws {
        try assertNoSourceMatch(literal: "Color(red:", excluding: ["DesignTokens.swift"])
    }

    func testNoAnimationLiteralsOutsideTokens() throws {
        try assertNoSourceMatch(
            regex: #"\.(spring|easeIn|easeOut|easeInOut|linear)\("#,
            excluding: ["DesignTokens.swift"]
        )
    }

    func testAccentContrast() throws {
        let accent = try assetColors(named: "AccentColor")
        let onAccent = try assetColors(named: "OnAccent")

        for luminosity in Luminosity.allCases {
            let foreground = try XCTUnwrap(onAccent[luminosity])
            let background = try XCTUnwrap(accent[luminosity])
            XCTAssertGreaterThanOrEqual(
                contrast(foreground, background),
                4.5,
                "\(luminosity.rawValue) accent contrast must be at least 4.5:1"
            )
        }
    }

    private func assertNoSourceMatch(
        literal: String,
        excluding excludedNames: Set<String> = []
    ) throws {
        for url in swiftSourceURLs() where !excludedNames.contains(url.lastPathComponent) {
            let source = try String(contentsOf: url, encoding: .utf8)
            XCTAssertFalse(source.contains(literal), "\(url.path) contains \(literal)")
        }
    }

    private func assertNoSourceMatch(
        regex: String,
        excluding excludedNames: Set<String> = []
    ) throws {
        for url in swiftSourceURLs() where !excludedNames.contains(url.lastPathComponent) {
            let source = try String(contentsOf: url, encoding: .utf8)
            XCTAssertNil(
                source.range(of: regex, options: .regularExpression),
                "\(url.path) matches \(regex)"
            )
        }
    }

    private func swiftSourceURLs() -> [URL] {
        let sourceRoot = projectRoot.appendingPathComponent("StoryCue", isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            XCTFail("could not enumerate Swift sources at \(sourceRoot.path)")
            return []
        }
        return enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "swift" else { return nil }
            return url
        }
    }

    private func assetColors(named name: String) throws -> [Luminosity: RGB] {
        let url = projectRoot
            .appendingPathComponent("StoryCue/Assets.xcassets")
            .appendingPathComponent("\(name).colorset/Contents.json")
        let catalog = try JSONDecoder().decode(AssetCatalog.self, from: Data(contentsOf: url))
        var result: [Luminosity: RGB] = [:]
        for entry in catalog.colors {
            let luminosity: Luminosity = entry.appearances?.contains {
                $0.appearance == "luminosity" && $0.value == "dark"
            } == true ? .dark : .universal
            result[luminosity] = try rgb(from: entry.color.components)
        }
        return result
    }

    private func rgb(from components: [String: String]) throws -> RGB {
        RGB(
            red: try component("red", in: components),
            green: try component("green", in: components),
            blue: try component("blue", in: components)
        )
    }

    private func component(_ name: String, in components: [String: String]) throws -> Double {
        let string = try XCTUnwrap(components[name])
        let digits = string.hasPrefix("0x") ? String(string.dropFirst(2)) : string
        let value = try XCTUnwrap(UInt8(digits, radix: 16))
        return Double(value) / 255
    }

    private func contrast(_ first: RGB, _ second: RGB) -> Double {
        let firstLuminance = relativeLuminance(first)
        let secondLuminance = relativeLuminance(second)
        let lighter = max(firstLuminance, secondLuminance)
        let darker = min(firstLuminance, secondLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ color: RGB) -> Double {
        0.2126 * linearized(color.red)
            + 0.7152 * linearized(color.green)
            + 0.0722 * linearized(color.blue)
    }

    private func linearized(_ component: Double) -> Double {
        component <= 0.04045
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }
}
