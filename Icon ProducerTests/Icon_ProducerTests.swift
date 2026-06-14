//
//  Icon_ProducerTests.swift
//  Icon ProducerTests
//
//  Created by Michael Fluharty on 6/9/26.
//

import Testing
import Foundation
import ImageIO
@testable import Icon_Producer

struct Icon_ProducerTests {

    /// Export keystone (roadmap 2.3): rendering produces a valid PNG at the exact
    /// requested pixel size.
    @MainActor
    @Test func exportRendersValidPNGAt1024() async throws {
        let doc = IconDocument.newDefault()
        doc.layers[0].setBackgroundFill("#FFFFFF")          // Light Background
        doc.layers[2].setSymbol("star.fill", tintHex: "#000000")  // Icon

        let data = try #require(ContentView.renderIconPNG(document: doc, px: 1024))
        #expect(data.count > 0)

        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 1024)
        #expect(image.height == 1024)
    }

    /// Every required app-icon size renders to a correctly-dimensioned PNG (2.3.2).
    @MainActor
    @Test func exportProducesEveryRequiredSize() async throws {
        let doc = IconDocument.newDefault()
        doc.layers[0].setBackgroundFill("#1E90FF")

        for px in ContentView.exportPixelSizes {
            let data = try #require(ContentView.renderIconPNG(document: doc, px: px),
                                    "no PNG produced for \(px)px")
            let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
            let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
            #expect(image.width == px, "width mismatch at \(px)px")
            #expect(image.height == px, "height mismatch at \(px)px")
        }
    }

    /// A saved package round-trips through the manifest (roadmap 2.4).
    @MainActor
    @Test func documentManifestRoundTrips() async throws {
        let doc = IconDocument.newDefault()
        doc.name = "Round Trip"
        doc.layers[0].setBackgroundFill("#ABCDEF")

        let manifest = try doc.snapshot(contentType: .iconProject)
        let encoded = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(IconProjectManifest.self, from: encoded)

        #expect(decoded.name == "Round Trip")
        #expect(decoded.layers.count == 3)
        #expect(decoded.layers[0].role.isBackgroundFilled)
    }
}

private extension LayerRole {
    var isBackgroundFilled: Bool {
        if case .background(_, let hex) = self { return hex != nil }
        return false
    }
}
