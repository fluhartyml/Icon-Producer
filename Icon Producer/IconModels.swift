//
//  IconModels.swift
//  Icon Producer
//
//  Created by Michael Fluharty on 6/10/26.
//
//  The icon-document domain model — the data shapes from the design.
//  See IconProducer_DeveloperNotes.swift for the full plan-of-record.
//
//  Two deliberate choices, both from the design:
//   • PERSISTENCE-AGNOSTIC + Codable-friendly. The "icon package" save format
//     is decided in a later increment; nothing here is tied to SwiftData or a
//     document type yet.
//   • NO whole-store UndoManager anywhere — that is what crashed Shelf-Ready on
//     deletes. Undo will be a byproduct of a custom tool-history structure added
//     in a later increment, not an app-wide UndoManager.
//
//  First increment: types only. Not wired to any UI or persistence yet.
//

import SwiftUI

// MARK: - Document

/// An icon project: a square canvas (the 1024 "master") holding an ordered,
/// nondestructive stack of layers. Index 0 = bottom (drawn first), last = top.
/// Reordering a layer = reindexing this array; layers are never flattened until
/// export.
@Observable
final class IconDocument {
    var name: String
    /// Square master resolution. 1024 = the design's "draw small, render master big".
    let canvasSize: Int
    /// Bottom-to-top draw order.
    var layers: [IconLayer]

    init(name: String = "Untitled Icon", canvasSize: Int = 1024, layers: [IconLayer] = []) {
        self.name = name
        self.canvasSize = canvasSize
        self.layers = layers
    }

    /// A brand-new icon's default stack: Light Background, Dark Background, Icon —
    /// ALL THREE START BLANK (no fill, no content). The user fills the backgrounds
    /// with the paint bucket and draws/places content on Icon. The user adds more
    /// layers as needed (infinite). Light vs dark is previewed by toggling a
    /// background's `isVisible` (the eyeball) — there are no light/dark mode buttons.
    static func newDefault() -> IconDocument {
        IconDocument(layers: [
            IconLayer(name: "Light Background", kind: .background(role: .light, fillHex: nil)),
            IconLayer(name: "Dark Background",  kind: .background(role: .dark,  fillHex: nil)),
            IconLayer(name: "Icon",             kind: .pixel(PixelContent())),
        ])
    }
}

// MARK: - Layer

/// One layer in the stack.
/// CONTENT layers (symbol/image/pixel/text) carry real alpha — clear where
/// unpainted — so you always see through to the layers below. BACKGROUND layers
/// are opaque solid fills: they are the floor that removes any clear background
/// from the final icon.
struct IconLayer: Identifiable, Codable {
    var id = UUID()
    /// User-editable; auto-named from its content ("content names the layer").
    var name: String
    /// The eyeball toggle. For the two background layers this also serves as the
    /// light/dark preview control (hide Dark Background to preview the light look).
    var isVisible = true
    /// 0...1.
    var opacity = 1.0
    var transform = LayerTransform()
    var kind: LayerKind

    init(name: String, kind: LayerKind) {
        self.name = name
        self.kind = kind
    }
}

/// Placement of a layer within the square canvas.
struct LayerTransform: Codable {
    /// Normalized center in canvas space (0...1, origin top-left).
    var center = CGPoint(x: 0.5, y: 0.5)
    /// Scale as a fraction of the canvas edge.
    var scale = 1.0
    var rotationDegrees = 0.0
}

// MARK: - Layer kinds

/// The layer kinds. Effects (layer styles, e.g. outer glow / plasma flame) apply
/// LAYER-WIDE and are added in a later increment.
enum LayerKind: Codable {
    /// Solid-fill background (the icon's floor). STARTS BLANK (`fillHex == nil`);
    /// the user fills it with the paint bucket. Once filled it is opaque — that
    /// is what removes any clear background from the final icon. Light = typically
    /// white, Dark = typically black, but the colour is user-chosen.
    case background(role: BackgroundRole, fillHex: String?)
    /// An SF Symbol — picked from Apple's library, not typed.
    case symbol(SymbolContent)
    /// Imported / pasted / drag / AI-generated raster artwork.
    case image(ImageContent)
    /// In-place pixel-grid painting on the master (pen size = stamp size).
    case pixel(PixelContent)
    /// A click-to-add text element (font glyphs; single-letter-as-icon is primary).
    case text(TextContent)
}

enum BackgroundRole: String, Codable {
    case light, dark
}

/// SF Symbol content. Weight/scale come in a later increment.
struct SymbolContent: Codable {
    var systemName = "star.fill"
    var tintHex = "#000000"
}

/// Raster artwork. A layer can eventually hold MULTIPLE composited elements
/// (raster sub-canvas); modeled fully later. PNG only — never JPG (lossless,
/// keeps alpha).
struct ImageContent: Codable {
    /// PNG bytes at the master resolution. Empty = not yet populated.
    var pngData = Data()
}

/// Pixel-art content. The grid densities (128/256/512/1024) are a VIEW concern
/// (the pen size picks one); the layer stores a single master raster underneath
/// so strokes of different block sizes mix freely.
struct PixelContent: Codable {
    /// PNG bytes of the pixel raster at the master resolution.
    var pngData = Data()
}

/// Text content. Sizeable up to filling the whole canvas. Formatting (font /
/// size / colour / alignment) lives in the text tool's inspector.
struct TextContent: Codable {
    var string = "A"
    var fontName = "SF Pro"
    /// Point size as a fraction of the master edge (can reach 1.0 = canvas-filling).
    var sizeFraction = 0.8
    var colorHex = "#000000"
}

// MARK: - Display helpers

extension LayerKind {
    /// SF Symbol name used to badge this layer kind in the layer list.
    var displaySymbolName: String {
        switch self {
        case .background(let role, _): role == .light ? "sun.max" : "moon"
        case .symbol:                  "star"
        case .image:                   "photo"
        case .pixel:                   "squareshape.split.3x3"
        case .text:                    "textformat"
        }
    }

    /// True while a layer is still blank (nothing placed/filled yet).
    var isBlank: Bool {
        switch self {
        case .background(_, let fillHex): fillHex == nil
        case .symbol(let c):              c.systemName.isEmpty
        case .image(let c):               c.pngData.isEmpty
        case .pixel(let c):               c.pngData.isEmpty
        case .text(let c):                c.string.isEmpty
        }
    }
}
