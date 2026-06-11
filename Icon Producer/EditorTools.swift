//
//  EditorTools.swift
//  Icon Producer
//
//  Created by Michael Fluharty on 6/11/26.
//
//  The toolbox lineup. These are the SELECTABLE tools that populate the tool
//  strip. The set is locked in IconProducer_DeveloperNotes.swift ("TOOL
//  VOCABULARY"); the BEHAVIOUR of each tool is built later, one at a time. For
//  now a tool just selects (highlights) and shows its placeholder inspector.
//
//  NOTE on names: "Pen" = the PIXEL painter; "Path" = the VECTOR Bezier tool
//  (Photoshop/Illustrator's "pen") — kept distinct so the two never blur.
//

import SwiftUI

/// A tool in the toolbox. Order here = left-to-right order in the strip (which
/// scrolls horizontally when there are more tools than fit — see DeveloperNotes).
enum Tool: String, CaseIterable, Identifiable {
    case move
    case fill          // paint bucket
    case pen           // pixel painter
    case eraser
    case eyedropper
    case shape         // line / rectangle / oval / polygon
    case path          // vector Bezier
    case text          // type characters
    case glyph         // browse a font's full repertoire (Wingdings etc.)
    case symbol        // SF Symbols
    case image         // import: File / Photo / paste / AI
    case zoom          // navigation only (not history)

    var id: String { rawValue }

    /// Label shown in the tool's (placeholder) inspector.
    var title: String {
        switch self {
        case .move:       "Move / Transform"
        case .fill:       "Paint Bucket"
        case .pen:        "Pen (Pixels)"
        case .eraser:     "Eraser"
        case .eyedropper: "Eyedropper"
        case .shape:      "Shape"
        case .path:       "Path (Vector)"
        case .text:       "Text"
        case .glyph:      "Glyph"
        case .symbol:     "Symbol (SF Symbols)"
        case .image:      "Image"
        case .zoom:       "Zoom"
        }
    }

    /// SF Symbol used for the tool's button in the strip.
    var systemImage: String {
        switch self {
        case .move:       "arrow.up.and.down.and.arrow.left.and.right"
        case .fill:       "drop.fill"
        case .pen:        "pencil.tip"
        case .eraser:     "eraser.fill"
        case .eyedropper: "eyedropper"
        case .shape:      "square.on.circle"
        case .path:       "scribble.variable"
        case .text:       "textformat"
        case .glyph:      "character.book.closed"
        case .symbol:     "star.fill"
        case .image:      "photo"
        case .zoom:       "magnifyingglass"
        }
    }
}
