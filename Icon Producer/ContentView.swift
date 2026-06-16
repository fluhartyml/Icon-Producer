//
//  ContentView.swift
//  Icon Producer
//
//  Created by Michael Fluharty on 6/9/26.
//
//  Editor SHELL + tools coming live ONE AT A TIME (toolbox order). A brand-new
//  icon opens with three BLANK layers (Light Background, Dark Background, Icon),
//  so the canvas shows the transparency checkerboard until the user fills/draws.
//
//  LAYOUT (Michael 2026-06-11): adapts by geometry, not size class.
//   • PORTRAIT (taller than wide — iPhone AND iPad portrait):
//        canvas (top half) · TOOL STRIP · ACTIVE-TOOL NAME · SWIPE PANEL
//        (Tool inspector / Layers / History).
//   • LANDSCAPE / WIDE (Mac, iPad/iPhone landscape): the original side-by-side.
//
//  TOOL #1 — MOVE / TRANSFORM (live 2026-06-11): tap a layer row -> ACTIVE layer
//  (highlighted). With Move active, a bounding box shows on the canvas; drag to
//  move; the inspector has scale / rotation / center / reset. Acts on the WHOLE
//  layer's transform. (Scale/rotate handles + flip + per-element = follow-ups;
//  layers are still blank so you manipulate the frame, content follows later.)
//

import SwiftUI
import Combine
import UniformTypeIdentifiers
import ImageIO
import CoreText
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ContentView: View {
    @ObservedObject var document: IconDocument
    @State private var activeTool: Tool = .move
    @State private var activeLayerID: IconLayer.ID?
    @State private var bottomPanel: BottomPanel = .layers
    /// Paint Bucket's current colour (roadmap 2.1) — the user's own light/dark choice.
    @State private var fillColor: Color = .white
    /// Export (roadmap 2.3): the rendered PNG folder + the exporter sheet flag.
    @State private var exportBundle: IconExportBundle?
    @State private var showExporter = false
    /// Share (roadmap 2.5): a flat 1024 PNG of the visible layers, snapshot at tap.
    @State private var shareURL: URL?
    @State private var showShare = false
    /// Shared pixel-pen state — the canvas draws into it; the Pen inspector configures it.
    @StateObject private var pen = PixelPen()

    var body: some View {
        GeometryReader { geo in
            if geo.size.height > geo.size.width {
                // Portrait: canvas top half, then tool strip + swipe panel.
                VStack(spacing: 0) {
                    canvasArea
                        .frame(height: geo.size.height / 2)
                    Divider()
                    ToolStrip(activeTool: $activeTool)
                    ActiveToolLabel(tool: activeTool)
                    Divider()
                    BottomPanel.PanelView(document: document,
                                          activeTool: activeTool,
                                          activeLayerID: $activeLayerID,
                                          selection: $bottomPanel,
                                          fillColor: $fillColor)
                }
            } else {
                // Landscape / wide: canvas | tool rail | inspector | layers — all
                // visible at once, using the gap the square canvas leaves to the
                // right (Michael 2026-06-11: iPad is landscape-locked in a Magic
                // Keyboard, so landscape needs full tooling, not the bare layout).
                HStack(spacing: 0) {
                    canvasArea
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Divider()
                    ToolRail(activeTool: $activeTool)
                    Divider()
                    ToolInspector(document: document,
                                  activeTool: activeTool,
                                  activeLayerID: activeLayerID,
                                  fillColor: $fillColor)
                        .frame(width: 240)
                    Divider()
                    LayerPanel(document: document, activeLayerID: $activeLayerID)
                        .frame(width: 240)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { prepareExport() } label: {
                    Label("Export", systemImage: "square.and.arrow.up.on.square")
                }
                .help("Export the icon as a folder of PNG sizes")
            }
            ToolbarItem(placement: .secondaryAction) {
                Button { prepareShare() } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .help("Share a flat PNG of the visible layers")
            }
        }
        .fileExporter(isPresented: $showExporter,
                      document: exportBundle,
                      contentType: .folder,
                      defaultFilename: exportFilename) { _ in }
        .sheet(isPresented: $showShare) {
            if let url = shareURL {
                #if canImport(UIKit)
                ActivityView(items: [url])
                #else
                VStack(spacing: 16) {
                    ShareLink(item: url) { Label("Share Icon", systemImage: "square.and.arrow.up") }
                    Button("Done") { showShare = false }
                }
                .padding(40)
                #endif
            }
        }
        .environmentObject(pen)
    }

    /// Render a flat 1024 PNG of the visible layers NOW and present the share sheet.
    private func prepareShare() {
        guard let data = ContentView.renderIconPNG(document: document, px: 1024) else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(exportFilename)
            .appendingPathExtension("png")
        do {
            try data.write(to: url)
            shareURL = url
            showShare = true
        } catch {
            // Fail-safe: surface nothing destructive; just don't present a broken share.
        }
    }

    private var exportFilename: String {
        let base = document.name.trimmingCharacters(in: .whitespaces)
        return (base.isEmpty ? "Untitled Icon" : base) + " AppIcon"
    }

    /// Render every required size to PNG and present the folder exporter (roadmap 2.3).
    private func prepareExport() {
        var files: [String: Data] = [:]
        for px in Self.exportPixelSizes {
            if let data = ContentView.renderIconPNG(document: document, px: px) {
                files["icon_\(px).png"] = data
            }
        }
        exportBundle = IconExportBundle(files: files)
        showExporter = true
    }

    /// iOS + macOS app-icon pixel sizes, unioned + de-duplicated (roadmap 2.3.2).
    /// No Contents.json (2.3.1): the user drags the size Xcode asks for into its well.
    static let exportPixelSizes: [Int] =
        [16, 20, 29, 32, 40, 58, 60, 64, 76, 80, 87, 120, 128, 152, 167, 180, 256, 512, 1024]

    /// Flatten the visible layers to a px×px PNG (1024 master; PNG per 2.5.1).
    @MainActor static func renderIconPNG(document: IconDocument, px: Int) -> Data? {
        let renderer = ImageRenderer(content: IconCompositeView(document: document, side: CGFloat(px)))
        renderer.scale = 1
        guard let cg = renderer.cgImage else { return nil }
        return pngData(from: cg)
    }

    private var canvasArea: some View {
        // Zoom/pan PARKED 2026-06-11 (ZoomableCanvas left in the file, unused):
        // the UIScrollView approach fought Auto Layout so pinch didn't zoom.
        // Re-wire when the PIXEL PEN needs zoom and we can iterate it properly.
        CanvasView(document: document,
                   activeLayerID: activeLayerID,
                   showTransformBox: activeTool == .move,
                   activeTool: activeTool,
                   fillColor: fillColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(Color(white: 0.5).opacity(0.12))
    }
}

// MARK: - Tool strip

/// The always-visible toolbox: a horizontal row of tool icons that scrolls when
/// there are more tools than fit. Tapping a tool makes it the active tool.
struct ToolStrip: View {
    @Binding var activeTool: Tool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: [GridItem(.fixed(44), spacing: 4), GridItem(.fixed(44), spacing: 4)], spacing: 4) {
                ForEach(Tool.allCases) { tool in
                    Button { activeTool = tool } label: {
                        ToolGlyph(tool: tool)
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(activeTool == tool ? Color.accentColor.opacity(0.2)
                                                             : Color.clear)
                            )
                            .foregroundStyle(activeTool == tool ? Color.accentColor : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .help(tool.title)                 // tooltip on Mac / iPad pointer
                    .accessibilityLabel(tool.title)   // VoiceOver everywhere
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}

/// Shows the ACTIVE tool's name on screen — the touch/iPhone substitute for a
/// hover tooltip. Updates the instant a tool is tapped, on every platform, so
/// the less-obvious glyphs are never a guess.
struct ActiveToolLabel: View {
    let tool: Tool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tool.systemImage)
            Text(tool.title).fontWeight(.medium)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(Color(white: 0.5).opacity(0.10))
    }
}

// MARK: - Tool rail (landscape)

/// Vertical version of the tool strip for the wide/landscape layout — sits in the
/// gap the square canvas leaves, hugging the canvas's right edge. Scrolls
/// vertically when there are more tools than fit.
struct ToolRail: View {
    @Binding var activeTool: Tool

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: [GridItem(.fixed(44), spacing: 4), GridItem(.fixed(44), spacing: 4)], spacing: 4) {
                ForEach(Tool.allCases) { tool in
                    Button { activeTool = tool } label: {
                        ToolGlyph(tool: tool)
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(activeTool == tool ? Color.accentColor.opacity(0.2)
                                                             : Color.clear)
                            )
                            .foregroundStyle(activeTool == tool ? Color.accentColor : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .help(tool.title)
                    .accessibilityLabel(tool.title)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
        }
        .frame(width: 104)
    }
}

// MARK: - Tool inspector (shared)

/// The active tool's inspector — Move's controls, or a placeholder for tools not
/// built yet. Reused by BOTH the portrait swipe panel and the landscape column.
struct ToolInspector: View {
    @ObservedObject var document: IconDocument
    let activeTool: Tool
    let activeLayerID: IconLayer.ID?
    @Binding var fillColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tool-name header: the inspector names the active tool, so you never
            // need hover to know which tool you're on (Michael 2026-06-11).
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: activeTool.systemImage)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(activeTool.title).font(.headline)
                    // "Duplicate with a purpose" (Michael 2026-06-11): the active
                    // layer is also highlighted in the list, but spelling it out
                    // here CONFIRMS which layer you're about to act on.
                    if let name = activeLayerName {
                        Text("Layer: \(name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            Divider()
            content
        }
    }

    private var activeLayerName: String? {
        guard let id = activeLayerID else { return nil }
        return document.layers.first(where: { $0.id == id })?.name
    }

    @ViewBuilder
    private var content: some View {
        switch activeTool {
        case .move:
            MoveTransformInspector(document: document, activeLayerID: activeLayerID)
        case .fill:
            PaintBucketInspector(document: document,
                                 activeLayerID: activeLayerID,
                                 fillColor: $fillColor)
        case .symbol:
            SymbolPickerInspector(document: document, activeLayerID: activeLayerID)
        case .glyph:
            FontPickerInspector(document: document, activeLayerID: activeLayerID)
        case .image:
            ImageImportInspector(document: document, activeLayerID: activeLayerID)
        case .pen:
            PenInspector(document: document, activeLayerID: activeLayerID)
        default:
            ToolInspectorPlaceholder(tool: activeTool)
        }
    }
}

// MARK: - Paint Bucket inspector (Tool #2)

/// Paint Bucket v1 (roadmap 2.1): pick a colour, then tap a BACKGROUND layer's
/// canvas to fill it — the user makes their own Light and Dark backgrounds. The
/// "Fill" button applies without a canvas tap (and works on Mac / for VoiceOver).
struct PaintBucketInspector: View {
    @ObservedObject var document: IconDocument
    let activeLayerID: IconLayer.ID?
    @Binding var fillColor: Color

    private var activeIndex: Int? {
        guard let id = activeLayerID else { return nil }
        return document.layers.firstIndex(where: { $0.id == id })
    }

    private var activeIsBackground: Bool {
        guard let i = activeIndex else { return false }
        return document.layers[i].backgroundRole != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ColorPicker("Fill color", selection: $fillColor, supportsOpacity: false)

            if activeIsBackground {
                Button {
                    fillActiveBackground()
                } label: {
                    Label("Fill Layer", systemImage: "drop.fill")
                }
                .buttonStyle(.borderedProminent)
                Text("Or tap the canvas to pour.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Select a background layer (Light or Dark) to fill it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func fillActiveBackground() {
        guard let i = activeIndex else { return }
        document.layers[i].setBackgroundFill(fillColor.hexString())
    }
}

// MARK: - Symbol picker inspector (Tool: Symbol — v1 content path, roadmap 2.2)

/// Pick an SF Symbol and place it on the active CONTENT layer (single-glyph icon is
/// the primary case). Tint is user-chosen; picking replaces the layer's symbol so
/// the user can change their mind. Scale/position via the Move tool.
struct SymbolPickerInspector: View {
    @ObservedObject var document: IconDocument
    let activeLayerID: IconLayer.ID?
    @State private var search = ""
    @State private var tint: Color = .black

    /// A curated starter set of long-standing SF Symbols (safe across OS versions).
    static let symbols: [String] = [
        "star.fill", "heart.fill", "bolt.fill", "flame.fill", "leaf.fill", "drop.fill",
        "moon.fill", "sun.max.fill", "cloud.fill", "sparkles", "wand.and.stars", "crown.fill",
        "camera.fill", "photo.fill", "video.fill", "music.note", "mic.fill", "headphones",
        "paintbrush.fill", "pencil", "hammer.fill", "wrench.and.screwdriver.fill", "lightbulb.fill", "key.fill",
        "house.fill", "cart.fill", "bag.fill", "gift.fill", "bell.fill", "flag.fill",
        "tag.fill", "paperplane.fill", "envelope.fill", "phone.fill", "message.fill", "globe",
        "map.fill", "location.fill", "clock.fill", "calendar", "folder.fill", "doc.fill",
        "gamecontroller.fill", "gearshape.fill", "lock.fill", "wifi", "airplane", "car.fill",
        "bicycle", "figure.walk", "pawprint.fill", "fish.fill", "bird.fill", "hand.thumbsup.fill",
    ]

    private var activeIndex: Int? {
        guard let id = activeLayerID else { return nil }
        return document.layers.firstIndex(where: { $0.id == id })
    }

    private var activeIsContent: Bool {
        guard let i = activeIndex else { return false }
        if case .content = document.layers[i].role { return true }
        return false
    }

    private var currentSymbol: String? {
        guard let i = activeIndex else { return nil }
        return document.layers[i].symbolElementName
    }

    private var filtered: [String] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return q.isEmpty ? Self.symbols : Self.symbols.filter { $0.contains(q) }
    }

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 8)]

    var body: some View {
        if activeIsContent {
            VStack(alignment: .leading, spacing: 12) {
                ColorPicker("Tint", selection: $tint, supportsOpacity: false)
                TextField("Search symbols", text: $search)
                    .textFieldStyle(.roundedBorder)
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(filtered, id: \.self) { name in
                            Button { place(name) } label: {
                                Image(systemName: name)
                                    .font(.system(size: 20))
                                    .frame(width: 44, height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(name == currentSymbol
                                                  ? Color.accentColor.opacity(0.25) : Color.gray.opacity(0.12))
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(name)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            PanelPlaceholder(systemImage: "star",
                             title: "Symbol",
                             subtitle: "Select the Icon layer (a content layer) to place a symbol")
        }
    }

    private func place(_ name: String) {
        guard let i = activeIndex else { return }
        document.layers[i].setSymbol(name, tintHex: tint.hexString() ?? "#000000")
    }
}

// MARK: - Font picker inspector (Tool: "F" — font glyphs, e.g. Wingdings)

/// Browse an installed font's glyph repertoire and place a character on the active
/// CONTENT layer as a styled text element. Distinct from "SF" (SF Symbols). The font
/// LIST renders each name in its own font, reflecting the live style toggles. Outline
/// is stored but its rendering is a follow-up (no stock SwiftUI text-outline).
struct FontPickerInspector: View {
    @ObservedObject var document: IconDocument
    let activeLayerID: IconLayer.ID?

    @State private var family: String = FontPickerInspector.families.first ?? "Helvetica"
    @State private var tint: Color = .black
    @State private var bold = false
    @State private var italic = false
    @State private var underline = false
    @State private var outline = false
    @State private var glyphs: [String] = []

    /// Installed font family names (Core Text — cross-platform), sorted.
    static let families: [String] =
        ((CTFontManagerCopyAvailableFontFamilyNames() as? [String]) ?? []).sorted()

    private var activeIndex: Int? {
        guard let id = activeLayerID else { return nil }
        return document.layers.firstIndex(where: { $0.id == id })
    }
    private var activeIsContent: Bool {
        guard let i = activeIndex else { return false }
        if case .content = document.layers[i].role { return true }
        return false
    }

    private func styled(_ text: Text) -> Text {
        text.bold(bold).italic(italic).underline(underline)
    }

    var body: some View {
        if activeIsContent {
            VStack(alignment: .leading, spacing: 10) {
                // Style toggles
                HStack(spacing: 8) {
                    styleToggle("bold", "Bold", $bold)
                    styleToggle("italic", "Italic", $italic)
                    styleToggle("underline", "Underline", $underline)
                    styleToggle("character.textbox", "Outline", $outline)
                }

                Text("Font").font(.caption).foregroundStyle(.secondary)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Self.families, id: \.self) { fam in
                            Button { family = fam; recomputeGlyphs() } label: {
                                styled(Text(fam).font(.custom(fam, size: 16)))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 4).padding(.horizontal, 6)
                                    .background(RoundedRectangle(cornerRadius: 6)
                                        .fill(fam == family ? Color.accentColor.opacity(0.2) : Color.clear))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 150)

                ColorPicker("Tint", selection: $tint, supportsOpacity: false)

                Text("Glyph").font(.caption).foregroundStyle(.secondary)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 38), spacing: 6)], spacing: 6) {
                        ForEach(glyphs, id: \.self) { g in
                            Button { place(g) } label: {
                                styled(Text(g).font(.custom(family, size: 20)))
                                    .frame(width: 38, height: 38)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Glyph \(g)")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onAppear { if glyphs.isEmpty { recomputeGlyphs() } }
        } else {
            PanelPlaceholder(systemImage: "character.book.closed",
                             title: "Font",
                             subtitle: "Select the Icon layer (a content layer) to place a font glyph")
        }
    }

    @ViewBuilder
    private func styleToggle(_ icon: String, _ label: String, _ flag: Binding<Bool>) -> some View {
        Button { flag.wrappedValue.toggle() } label: {
            Image(systemName: icon)
                .frame(width: 36, height: 30)
                .background(RoundedRectangle(cornerRadius: 6)
                    .fill(flag.wrappedValue ? Color.accentColor.opacity(0.25) : Color.gray.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    /// The chosen family's supported characters (its repertoire), bounded for speed.
    private func recomputeGlyphs() {
        let font = CTFontCreateWithName(family as CFString, 24, nil)
        let set = CTFontCopyCharacterSet(font) as CharacterSet
        var out: [String] = []
        for value in 0x21...0x33FF {
            guard let scalar = Unicode.Scalar(value), set.contains(scalar) else { continue }
            out.append(String(scalar))
            if out.count >= 1000 { break }
        }
        glyphs = out
    }

    private func place(_ glyph: String) {
        guard let i = activeIndex else { return }
        document.layers[i].setText(glyph, fontName: family, tintHex: tint.hexString() ?? "#000000",
                                   bold: bold, italic: italic, underline: underline, outline: outline)
    }
}

// MARK: - Image import inspector (Tool: Image — manual import)

/// Import an image file onto the active CONTENT layer. Re-encoded to PNG and kept at
/// native resolution; the canvas scales it to fit the icon (Move tool re-sizes it).
/// v1 stores the bytes in the manifest; sibling-file storage in the package is a
/// follow-up. (Seatrial: the resolution/scaling behaviour is the part to shake down.)
struct ImageImportInspector: View {
    @ObservedObject var document: IconDocument
    let activeLayerID: IconLayer.ID?
    @State private var importing = false
    @State private var failed = false

    private var activeIndex: Int? {
        guard let id = activeLayerID else { return nil }
        return document.layers.firstIndex(where: { $0.id == id })
    }
    private var activeIsContent: Bool {
        guard let i = activeIndex else { return false }
        if case .content = document.layers[i].role { return true }
        return false
    }

    var body: some View {
        if activeIsContent {
            VStack(alignment: .leading, spacing: 12) {
                Button { importing = true } label: {
                    Label("Import Image…", systemImage: "photo.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                Text("Drops an image onto this layer at native resolution, scaled to fit the icon. Use Move to resize/position it.")
                    .font(.caption).foregroundStyle(.secondary)
                if failed {
                    Text("Couldn't read that image.").font(.caption).foregroundStyle(.red)
                }
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .fileImporter(isPresented: $importing, allowedContentTypes: [.image]) { result in
                failed = false
                guard case .success(let url) = result else { return }
                load(url)
            }
        } else {
            PanelPlaceholder(systemImage: "photo",
                             title: "Image",
                             subtitle: "Select the Icon layer (a content layer) to import an image")
        }
    }

    private func load(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let raw = try? Data(contentsOf: url),
              let png = pngData(fromImageData: raw),
              let i = activeIndex else { failed = true; return }
        document.layers[i].setImage(png)
    }
}

// MARK: - Pixel grid overlay

/// Faint grid at the active pixel layer's resolution — shows the cells you paint into
/// while the (higher-res) image on the layer below shows through, for tracing.
struct PixelGrid: View {
    let resolution: Int

    var body: some View {
        Canvas { ctx, size in
            // Draw EVERY line for the resolution (no thinning) — one cell = one pixel.
            let cw = size.width / CGFloat(resolution)
            let ch = size.height / CGFloat(resolution)
            var path = Path()
            for i in 0...resolution {
                let x = CGFloat(i) * cw
                path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
                let y = CGFloat(i) * ch
                path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
            }
            ctx.stroke(path, with: .color(.gray.opacity(0.7)), lineWidth: 1)
        }
    }
}

// MARK: - Pen inspector (Tool #3 — pixel art)

/// The Pixel Pen's controls: colour, the active layer's resolution (per-layer), a grid
/// toggle, and brush size. Drawing happens on the canvas; this configures the pen.
struct PenInspector: View {
    @EnvironmentObject var pen: PixelPen
    @ObservedObject var document: IconDocument
    let activeLayerID: IconLayer.ID?

    /// Resolution rungs for the graduated slider — 2 is the control.
    private let resolutionRungs = [2, 4, 6, 8, 16, 32, 64, 128, 256, 512, 1024]

    /// Which palette slot is open for recoloring (popover).
    private struct EditSlot: Identifiable { let id: Int }
    @State private var editing: EditSlot?

    private var activeIsContent: Bool {
        guard let id = activeLayerID,
              let i = document.layers.firstIndex(where: { $0.id == id }) else { return false }
        if case .content = document.layers[i].role { return true }
        return false
    }

    /// Bridge a palette slot (hex in the document) to a Color binding for the picker.
    /// Recoloring writes back to the document, updates the active color if it's the
    /// selected slot, and persists the palette as "last used" so new docs inherit it.
    private func slotColorBinding(_ i: Int) -> Binding<Color> {
        Binding(get: { Color(hex: document.palette[i]) ?? .black },
                set: { c in
                    document.palette[i] = c.hexString() ?? "#000000"
                    if i == pen.selectedSlot { pen.color = c }
                    IconDocument.lastUsedPalette = document.palette
                })
    }

    var body: some View {
        if activeIsContent {
            VStack(alignment: .leading, spacing: 14) {
                Text("Colors").font(.subheadline)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(document.palette.indices, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: document.palette[i]) ?? .black)
                            .frame(height: 26)
                            .overlay(RoundedRectangle(cornerRadius: 6)
                                .stroke(i == pen.selectedSlot ? Color.accentColor : Color.gray.opacity(0.4),
                                        lineWidth: i == pen.selectedSlot ? 2.5 : 1))
                            .onTapGesture {
                                pen.selectedSlot = i
                                pen.color = Color(hex: document.palette[i]) ?? .black
                            }
                            .contextMenu { Button("Change color…") { editing = EditSlot(id: i) } }
                    }
                }
                .popover(item: $editing) { slot in
                    ColorPicker("Slot color", selection: slotColorBinding(slot.id), supportsOpacity: false)
                        .padding().frame(minWidth: 220)
                }
                Text("Tap to use · right-click (long-press) to change. Saved with the file; new docs inherit it.")
                    .font(.caption2).foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("This layer's resolution — \(pen.resolution)\(pen.resolution == 2 ? " (control)" : "") px")
                        .font(.subheadline)
                    Slider(value: Binding(
                        get: { Double(resolutionRungs.firstIndex(of: pen.resolution) ?? 4) },
                        set: { pen.resolution = resolutionRungs[min(max(Int($0.rounded()), 0), resolutionRungs.count - 1)] }
                    ), in: 0...Double(resolutionRungs.count - 1), step: 1)
                    Text("Per-layer resolution; the grid matches. Lower = blockier.")
                        .font(.caption2).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Toggle("Show grid", isOn: $pen.showGrid)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Brush  \(pen.brush) cell\(pen.brush == 1 ? "" : "s")").font(.subheadline)
                    Slider(value: Binding(get: { Double(pen.brush) },
                                          set: { pen.brush = Int($0) }), in: 1...8, step: 1)
                }

                Text("Drag on the canvas to drop pixels into the grid cells.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            PanelPlaceholder(systemImage: "pencil.tip", title: "Pen (Pixels)",
                             subtitle: "Select the Icon layer (a content layer) to draw")
        }
    }
}

// MARK: - Bottom swipe panel

/// The three lower-frequency surfaces under the tool strip. A segmented control
/// picks one; on iOS you can also swipe between them.
enum BottomPanel: String, CaseIterable, Identifiable {
    case tool = "Tool"
    case layers = "Layers"
    case history = "History"

    var id: String { rawValue }

    struct PanelView: View {
        @ObservedObject var document: IconDocument
        let activeTool: Tool
        // (PanelView is the bottom swipe panel; it observes the document too.)
        @Binding var activeLayerID: IconLayer.ID?
        @Binding var selection: BottomPanel
        @Binding var fillColor: Color

        var body: some View {
            VStack(spacing: 0) {
                Picker("", selection: $selection) {
                    ForEach(BottomPanel.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(8)

                #if os(iOS)
                TabView(selection: $selection) {
                    toolPage.tag(BottomPanel.tool)
                    layersPage.tag(BottomPanel.layers)
                    historyPage.tag(BottomPanel.history)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                #else
                // macOS has no page style; portrait branch is unused on Mac, but
                // it still must compile — switch on the selection.
                Group {
                    switch selection {
                    case .tool:    toolPage
                    case .layers:  layersPage
                    case .history: historyPage
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                #endif
            }
        }

        private var toolPage: some View {
            ToolInspector(document: document,
                          activeTool: activeTool,
                          activeLayerID: activeLayerID,
                          fillColor: $fillColor)
        }

        private var layersPage: some View {
            LayerPanel(document: document, showsHeader: false, activeLayerID: $activeLayerID)
        }

        private var historyPage: some View {
            PanelPlaceholder(systemImage: "clock.arrow.circlepath",
                             title: "History",
                             subtitle: "Tool-grouped step-back — coming soon")
        }
    }
}

/// Placeholder shown on the Tool page until each tool's real inspector is built.
struct ToolInspectorPlaceholder: View {
    let tool: Tool

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: tool.systemImage)
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("Inspector — coming soon")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// Generic empty-state placeholder for a panel page.
struct PanelPlaceholder: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Move / Transform inspector

/// Tool #1's inspector: scale / rotation / center / reset on the ACTIVE layer's
/// transform. (Drag-to-move lives on the canvas box; handles + flip are later.)
struct MoveTransformInspector: View {
    @ObservedObject var document: IconDocument
    let activeLayerID: IconLayer.ID?

    private var index: Int? {
        guard let id = activeLayerID else { return nil }
        return document.layers.firstIndex(where: { $0.id == id })
    }

    var body: some View {
        if let idx = index {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scale  \(Int(document.layers[idx].transform.scale * 100))%")
                        .font(.subheadline)
                    Slider(value: transformBinding(\.scale, idx), in: 0.1...4.0)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Rotation  \(Int(document.layers[idx].transform.rotationDegrees))°")
                        .font(.subheadline)
                    Slider(value: transformBinding(\.rotationDegrees, idx), in: -180...180)
                }

                HStack {
                    Button("Center") {
                        document.layers[idx].transform.center = CGPoint(x: 0.5, y: 0.5)
                    }
                    Button("Reset") {
                        document.layers[idx].transform = LayerTransform()
                    }
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            PanelPlaceholder(systemImage: "hand.tap",
                             title: "Move / Transform",
                             subtitle: "Tap a layer to select it, then drag it on the canvas")
        }
    }

    private func transformBinding<V>(_ keyPath: WritableKeyPath<LayerTransform, V>,
                                     _ idx: Int) -> Binding<V> {
        Binding(get: { document.layers[idx].transform[keyPath: keyPath] },
                set: { document.layers[idx].transform[keyPath: keyPath] = $0 })
    }
}

// MARK: - Canvas

/// The square artboard. Composites the visible layers bottom-to-top over a
/// transparency checkerboard. (Blank layers render nothing -> checkerboard shows.)
/// When Move is active and a layer is selected, draws a draggable transform box.
struct CanvasView: View {
    @ObservedObject var document: IconDocument
    var activeLayerID: IconLayer.ID? = nil
    var showTransformBox: Bool = false
    var activeTool: Tool = .move
    var fillColor: Color = .white
    @EnvironmentObject var pen: PixelPen

    private var activeIndex: Int? {
        guard let id = activeLayerID else { return nil }
        return document.layers.firstIndex(where: { $0.id == id })
    }

    /// The active content layer's current pixel raster (to seed the pen), if any.
    private var activePixelData: Data? {
        guard let idx = activeIndex else { return nil }
        return document.layers[idx].pixelData
    }

    /// Paint Bucket pour: with Fill active, tapping the canvas fills the active
    /// BACKGROUND layer with the current colour (roadmap 2.1). No-op otherwise.
    private func pourIfFilling() {
        guard activeTool == .fill, let idx = activeIndex,
              document.layers[idx].backgroundRole != nil else { return }
        document.layers[idx].setBackgroundFill(fillColor.hexString())
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                Checkerboard()
                // Non-destructive canvas mask: content past the icon square is GHOSTED
                // (dimmed, unclipped) so you can still see + position it; then drawn CRISP
                // clipped to the square. What shows inside the square = what exports.
                layerStack(side: side)
                    .opacity(0.25)
                layerStack(side: side)
                    .frame(width: side, height: side)
                    .clipped()
                // Live pen stroke (the active layer's in-progress raster), kept crisp.
                if activeTool == .pen, let img = pen.image {
                    Image(decorative: img, scale: 1)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: side, height: side)
                        .allowsHitTesting(false)
                }
                // Pixel grid overlay for the active layer's resolution.
                if activeTool == .pen, pen.showGrid {
                    PixelGrid(resolution: pen.resolution)
                        .frame(width: side, height: side)
                        .allowsHitTesting(false)
                }
                if showTransformBox, let idx = activeIndex {
                    TransformBox(document: document, index: idx, side: side)
                }
            }
            .frame(width: side, height: side)
            .coordinateSpace(name: "canvas")
            .overlay(Rectangle().stroke(Color.secondary.opacity(0.4), lineWidth: 1))
            .contentShape(Rectangle())
            .gesture(
                // One gesture for both Pen (draw) and Fill (pour). minimumDistance 0 so a
                // TAP fires onChanged → a single pixel; a drag paints a trail.
                DragGesture(minimumDistance: 0, coordinateSpace: .named("canvas"))
                    .onChanged { value in
                        guard activeTool == .pen, activeIndex != nil else { return }
                        pen.stroke(toNormalized: CGPoint(x: value.location.x / side,
                                                         y: value.location.y / side))
                    }
                    .onEnded { _ in
                        switch activeTool {
                        case .pen:
                            pen.endStroke()
                            if let i = activeIndex, let data = pen.currentPNG() {
                                document.layers[i].setPixels(data)
                            }
                        case .fill:
                            pourIfFilling()
                        default:
                            break
                        }
                    },
                including: (activeTool == .pen || activeTool == .fill) ? .all : .subviews
            )
            .onAppear { if activeTool == .pen { pen.load(activePixelData) } }
            .onChange(of: activeTool) { if activeTool == .pen { pen.load(activePixelData) } }
            .onChange(of: activeLayerID) { if activeTool == .pen { pen.load(activePixelData) } }
            .onChange(of: pen.resolution) {
                guard activeTool == .pen else { return }
                pen.changeResolution()   // resample, don't erase
                if let i = activeIndex, let data = pen.currentPNG() {
                    document.layers[i].setPixels(data)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // center in the area
        }
    }

    /// What a layer draws on the canvas. A filled background renders its colour;
    /// a content layer renders its elements at the layer's transform. (Most
    /// element kinds wait for their tools; `symbol` renders now so the TEST-ONLY
    /// shakedown star is visible for the Move/Transform tool.)
    /// All visible layers composited — used twice (ghosted bleed + clipped crisp icon).
    @ViewBuilder
    private func layerStack(side: CGFloat) -> some View {
        ZStack {
            ForEach(document.layers) { layer in
                if layer.isVisible { layerContent(layer, side: side) }
            }
        }
    }

    @ViewBuilder
    private func layerContent(_ layer: IconLayer, side: CGFloat) -> some View {
        switch layer.role {
        case .background(_, let fillHex):
            if let hex = fillHex, let color = Color(hex: hex) {
                color
            }
        case .content:
            ForEach(layer.elements) { element in
                elementView(element, transform: layer.transform, side: side)
            }
        }
    }

    @ViewBuilder
    private func elementView(_ element: LayerElement,
                             transform t: LayerTransform,
                             side: CGFloat) -> some View {
        switch element.content {
        case .symbol(let symbol):
            Image(systemName: symbol.systemName)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color(hex: symbol.tintHex) ?? .primary)
                .frame(width: side * t.scale, height: side * t.scale)
                .rotationEffect(.degrees(t.rotationDegrees))
                .position(x: t.center.x * side, y: t.center.y * side)
        case .text(let text):
            Text(text.string)
                .font(.custom(text.fontName, size: side * text.sizeFraction * t.scale))
                .bold(text.bold)
                .italic(text.italic)
                .underline(text.underline)
                .foregroundStyle(Color(hex: text.colorHex) ?? .primary)
                .rotationEffect(.degrees(t.rotationDegrees))
                .position(x: t.center.x * side, y: t.center.y * side)
        case .image(let imageContent):
            if let platformImage = PlatformImage(data: imageContent.pngData) {
                Image(platformImage: platformImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: side * t.scale, height: side * t.scale)
                    .rotationEffect(.degrees(t.rotationDegrees))
                    .position(x: t.center.x * side, y: t.center.y * side)
            }
        case .pixels(let pixels):
            if let platformImage = PlatformImage(data: pixels.pngData) {
                Image(platformImage: platformImage)
                    .interpolation(.none)   // crisp blocks when a low-res layer scales up
                    .resizable()
                    .frame(width: side, height: side)
            }
        }
    }

}

/// The draggable transform box for the active layer (Move tool). Reflects the
/// layer's transform (center / scale / rotation). Drag GRABS and moves RELATIVE
/// to the start, so a tap doesn't jump the layer — only a real drag moves it
/// (Michael 2026-06-11: "it moves when touched").
struct TransformBox: View {
    @ObservedObject var document: IconDocument
    let index: Int
    let side: CGFloat
    @State private var startCenter: CGPoint?

    /// Unit offsets of the four corners from the box center.
    private let corners: [CGSize] = [
        CGSize(width: -1, height: -1), CGSize(width: 1, height: -1),
        CGSize(width: -1, height: 1),  CGSize(width: 1, height: 1),
    ]

    var body: some View {
        // Guard: the active layer can be deleted while this box is still mounted,
        // leaving `index` pointing past the end of the array for one update pass.
        if index >= 0, index < document.layers.count {
            let t = document.layers[index].transform
            let boxSide = max(24, t.scale * side)
            let center = CGPoint(x: t.center.x * side, y: t.center.y * side)

            // The movable box.
            Rectangle()
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .background(Color.accentColor.opacity(0.06))
                .frame(width: boxSide, height: boxSide)
                .rotationEffect(.degrees(t.rotationDegrees))
                .position(center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("canvas"))
                        .onChanged { value in
                            guard index < document.layers.count else { return }
                            let start = startCenter ?? document.layers[index].transform.center
                            if startCenter == nil { startCenter = start }
                            let nx = min(max(start.x + value.translation.width / side, 0), 1)
                            let ny = min(max(start.y + value.translation.height / side, 0), 1)
                            document.layers[index].transform.center = CGPoint(x: nx, y: ny)
                        }
                        .onEnded { _ in startCenter = nil }
                )

            // Corner grabbers — drag to scale (aspect-locked, around the center).
            ForEach(Array(corners.enumerated()), id: \.offset) { _, off in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: 14, height: 14)
                    .position(x: center.x + off.width * boxSide / 2,
                              y: center.y + off.height * boxSide / 2)
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .named("canvas"))
                            .onChanged { value in
                                guard index < document.layers.count else { return }
                                let half = max(abs(value.location.x - center.x),
                                               abs(value.location.y - center.y))
                                let newScale = min(max((half * 2) / side, 0.1), 4.0)
                                document.layers[index].transform.scale = newScale
                            }
                    )
            }
        }
    }
}

/// Standard image-editor transparency checkerboard.
struct Checkerboard: View {
    var squareSize: CGFloat = 14

    var body: some View {
        Canvas { context, size in
            let cols = Int(ceil(size.width / squareSize))
            let rows = Int(ceil(size.height / squareSize))
            for row in 0..<max(rows, 1) {
                for col in 0..<max(cols, 1) where (row + col) % 2 == 0 {
                    let rect = CGRect(x: CGFloat(col) * squareSize,
                                      y: CGFloat(row) * squareSize,
                                      width: squareSize, height: squareSize)
                    context.fill(Path(rect), with: .color(.gray.opacity(0.28)))
                }
            }
        }
        .background(Color(white: 0.97))
    }
}

// MARK: - Layer panel

/// The layer list. Shown TOP-of-stack first (the array is bottom-to-top, so the
/// display is reversed). Tap a row to make that layer ACTIVE (highlighted). Each
/// row: kind badge + editable name + eyeball; reorder is always-on (edit mode);
/// rename is via the row's context menu. `showsHeader` is false inside the
/// portrait swipe panel (the segmented control already labels it "Layers").
struct LayerPanel: View {
    @ObservedObject var document: IconDocument
    var showsHeader: Bool = true
    @Binding var activeLayerID: IconLayer.ID?
    @State private var renamingID: IconLayer.ID?
    @State private var draftName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row: title (when shown) + the always-present "+" to add a layer
            // (L3 — top-right add). In the portrait swipe panel the segmented control
            // already says "Layers", so the title is hidden but the "+" stays.
            HStack {
                if showsHeader { Text("Layers").font(.headline) }
                Spacer()
                Button { addLayer() } label: {
                    Image(systemName: "plus").font(.headline)
                }
                .buttonStyle(.plain)
                .help("Add a layer")
                .accessibilityLabel("Add a layer")
            }
            .padding(.horizontal)
            .padding(.vertical, showsHeader ? 10 : 6)
            Divider()
            List {
                ForEach(Array(document.layers.reversed())) { layer in
                    LayerRow(
                        layer: layer,
                        isActive: layer.id == activeLayerID,
                        onActivate: { activeLayerID = layer.id },
                        onToggleVisibility: { toggleVisibility(layer.id) },
                        onRename: { beginRename(layer) },
                        onDuplicate: { duplicate(layer.id) },
                        onDelete: { delete(layer.id) }
                    )
                    .listRowBackground(layer.id == activeLayerID
                                       ? Color.accentColor.opacity(0.15) : nil)
                }
                .onMove(perform: move)
                .onDelete(perform: deleteAt)
            }
            .listStyle(.plain)
            #if os(iOS)
            .environment(\.editMode, .constant(.active)) // always-on reorder handles (iOS only)
            #endif
        }
        .alert("Rename Layer", isPresented: isRenaming) {
            TextField("Name", text: $draftName)
            Button("Cancel", role: .cancel) { renamingID = nil }
            Button("Rename") { commitRename() }
        }
    }

    private var isRenaming: Binding<Bool> {
        Binding(get: { renamingID != nil },
                set: { if !$0 { renamingID = nil } })
    }

    private func beginRename(_ layer: IconLayer) {
        draftName = layer.name
        renamingID = layer.id
    }

    private func commitRename() {
        defer { renamingID = nil }
        guard let id = renamingID,
              let index = document.layers.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { document.layers[index].name = trimmed }
    }

    private func toggleVisibility(_ id: IconLayer.ID) {
        if let index = document.layers.firstIndex(where: { $0.id == id }) {
            document.layers[index].isVisible.toggle()
        }
    }

    /// L3 — add a new blank content layer on TOP of the stack, and select it.
    private func addLayer() {
        let layer = IconLayer(name: "Layer \(document.layers.count + 1)", role: .content)
        document.layers.append(layer)          // end of array = top of the visual stack
        activeLayerID = layer.id
    }

    /// L4.1 — exact copy (fill/elements, transform, opacity, visibility), named
    /// "<name> copy," new UUID, inserted directly ABOVE the original, selected.
    private func duplicate(_ id: IconLayer.ID) {
        guard let i = document.layers.firstIndex(where: { $0.id == id }) else { return }
        var copy = document.layers[i]
        copy.id = UUID()
        copy.name = document.layers[i].name + " copy"
        document.layers.insert(copy, at: i + 1)   // i+1 = one step toward the top
        activeLayerID = copy.id
    }

    /// L4/L5 — delete a layer (context menu).
    private func delete(_ id: IconLayer.ID) {
        document.layers.removeAll { $0.id == id }
        if activeLayerID == id { activeLayerID = nil }
    }

    /// L5 — swipe-to-delete. Offsets index into the reversed (top-first) display,
    /// so map them back to layer ids before removing.
    private func deleteAt(_ offsets: IndexSet) {
        let topFirst = Array(document.layers.reversed())
        let ids = offsets.map { topFirst[$0].id }
        document.layers.removeAll { ids.contains($0.id) }
        if let active = activeLayerID, ids.contains(active) { activeLayerID = nil }
    }

    /// The list shows the stack reversed (top-first), so reorder in that reversed
    /// space and write the un-reversed result back to the bottom-to-top array.
    private func move(from source: IndexSet, to destination: Int) {
        var topFirst = Array(document.layers.reversed())
        topFirst.move(fromOffsets: source, toOffset: destination)
        document.layers = topFirst.reversed()
    }
}

struct LayerRow: View {
    let layer: IconLayer
    let isActive: Bool
    let onActivate: () -> Void
    let onToggleVisibility: () -> Void
    let onRename: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Tapping the badge/name area selects (activates) the layer.
            Button(action: onActivate) {
                HStack(spacing: 10) {
                    Image(systemName: layer.displaySymbolName)
                        .frame(width: 18)
                        .foregroundStyle(.secondary)
                    Text(layer.name)
                        .foregroundStyle(layer.isVisible ? Color.primary : Color.secondary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onToggleVisibility) {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    .foregroundStyle(layer.isVisible ? Color.primary : Color.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button(action: onRename) { Label("Rename", systemImage: "pencil") }
            Button(action: onDuplicate) { Label("Duplicate", systemImage: "plus.square.on.square") }
            Divider()
            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
        }
    }
}

// MARK: - Zoom / pan (Procreate-style: 1 finger = tool, 2 = pan, pinch = zoom)

/// Wraps the canvas so pinch zooms and two-finger drag pans, while a single
/// finger still reaches the active tool. iOS uses a UIScrollView (pan set to a
/// 2-finger minimum); other platforms just show the content for now.
struct ZoomableCanvas<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        #if os(iOS)
        ZoomableScrollView { content }
        #else
        content
        #endif
    }
}

#if os(iOS)
struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    @ViewBuilder var content: Content

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.delegate = context.coordinator
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 8
        scroll.bouncesZoom = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.delaysContentTouches = false
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.backgroundColor = .clear
        scroll.panGestureRecognizer.minimumNumberOfTouches = 2 // 1 finger -> tool

        let hosted = context.coordinator.hosting.view!
        hosted.backgroundColor = .clear
        hosted.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(hosted)
        NSLayoutConstraint.activate([
            hosted.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            hosted.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            hosted.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            hosted.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            hosted.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            hosted.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
        ])
        return scroll
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hosting.rootView = content
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(hosting: UIHostingController(rootView: content))
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let hosting: UIHostingController<Content>
        init(hosting: UIHostingController<Content>) {
            self.hosting = hosting
            hosting.view.backgroundColor = .clear
        }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { hosting.view }
    }
}
#endif

// MARK: - Helpers

extension Color {
    /// "#RRGGBB" (or "RRGGBB") -> Color. Returns nil on a malformed string.
    init?(hex: String) {
        var string = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if string.hasPrefix("#") { string.removeFirst() }
        guard string.count == 6, let value = UInt32(string, radix: 16) else { return nil }
        self = Color(.sRGB,
                     red: Double((value >> 16) & 0xFF) / 255,
                     green: Double((value >> 8) & 0xFF) / 255,
                     blue: Double(value & 0xFF) / 255)
    }

    /// sRGB "#RRGGBB" for persisting a chosen colour (alpha dropped — backgrounds
    /// are opaque). Returns nil if the platform colour can't be resolved.
    func hexString() -> String? {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        #elseif canImport(AppKit)
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let r = c.redComponent, g = c.greenComponent, b = c.blueComponent
        #endif
        return String(format: "#%02X%02X%02X",
                      Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    /// Resolve to a CGColor for Core Graphics drawing (the Pixel Pen).
    var platformCGColor: CGColor {
        #if canImport(UIKit)
        return UIColor(self).cgColor
        #else
        return NSColor(self).cgColor
        #endif
    }
}

// MARK: - Pixel Pen (Tool #3) — raster drawing into a 1024 master bitmap

/// Owns the pen's mutable raster (a 1024×1024 bitmap) plus colour + size. The canvas
/// strokes into it on drag and commits the PNG to the active layer on release; it is
/// seeded from the layer's existing pixels so drawing accumulates rather than wipes.
@MainActor
final class PixelPen: ObservableObject {
    /// The active paint color (the chosen palette slot). The palette itself lives in the
    /// document (saved per-project); the pen just holds the current color + which slot.
    @Published var color: Color = .black
    @Published var selectedSlot = 0
    /// The active pixel layer's resolution — per-layer (128/256/512/1024…). The pen's
    /// bitmap IS this many pixels square; nearest-neighbor upscaling keeps it blocky.
    @Published var resolution: Int = 128
    /// Brush size in CELLS (1 = one pixel/cell, 2 = a 2×2 block, …) — same unit as the grid.
    @Published var brush: Int = 1
    @Published var showGrid = true
    @Published private(set) var image: CGImage?

    private var ctx: CGContext?
    private var lastPoint: CGPoint?

    private func makeContext(_ dim: Int) -> CGContext? {
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let c = CGContext(data: nil, width: dim, height: dim, bitsPerComponent: 8,
                          bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        c?.setShouldAntialias(false)   // hard pixel edges (blocky)
        c?.setLineCap(.round)
        c?.setLineJoin(.round)
        return c
    }

    /// Seed from a layer's existing raster (adopting ITS resolution — per-layer), or
    /// start a fresh blank buffer at the picker's `resolution`.
    func load(_ data: Data?) {
        if let data,
           let src = CGImageSourceCreateWithData(data as CFData, nil),
           let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) {
            resolution = cg.width                       // layer keeps its own resolution
            ctx = makeContext(cg.width)
            ctx?.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.width))
        } else {
            ctx = makeContext(resolution)
        }
        lastPoint = nil
        image = ctx?.makeImage()
    }

    /// Fill the grid cell(s) under a normalized canvas point (0…1, top-left) — whole
    /// pixels at the layer's resolution; a brush of N fills an N×N cell block. Snapped
    /// to the grid, so the brush and grid share the same unit. CG is bottom-left → flip y.
    func stroke(toNormalized n: CGPoint) {
        if ctx == nil { ctx = makeContext(resolution) }
        guard let ctx else { return }
        let dim = resolution
        let col = min(max(Int(n.x * CGFloat(dim)), 0), dim - 1)
        let row = min(max(Int(n.y * CGFloat(dim)), 0), dim - 1)
        let half = brush / 2
        ctx.setFillColor(color.platformCGColor)
        for dc in -half..<(brush - half) {
            for dr in -half..<(brush - half) {
                let c = col + dc, r = row + dr
                guard c >= 0, c < dim, r >= 0, r < dim else { continue }
                ctx.fill(CGRect(x: c, y: dim - 1 - r, width: 1, height: 1))   // one cell = one pixel
            }
        }
        image = ctx.makeImage()
    }

    func endStroke() { lastPoint = nil }

    /// Resample the current art into the (already-updated) resolution instead of
    /// clearing it — so changing the grid size KEEPS the pixels (nearest-neighbor,
    /// stays blocky) rather than erasing.
    func changeResolution() {
        let old = ctx?.makeImage()
        let c = makeContext(resolution)
        c?.interpolationQuality = .none
        if let old { c?.draw(old, in: CGRect(x: 0, y: 0, width: resolution, height: resolution)) }
        ctx = c
        lastPoint = nil
        image = ctx?.makeImage()
    }

    func currentPNG() -> Data? {
        guard let cg = ctx?.makeImage() else { return nil }
        return pngData(from: cg)
    }
}

// MARK: - Flattened render + export (roadmap 2.3)

/// The visible layers composited with NO editor chrome (no checkerboard / box) —
/// what Export and Share rasterize. Transparent where no opaque background shows.
struct IconCompositeView: View {
    let document: IconDocument
    let side: CGFloat

    var body: some View {
        ZStack {
            ForEach(document.layers) { layer in
                if layer.isVisible { composited(layer) }
            }
        }
        .frame(width: side, height: side)
        .clipped()
    }

    @ViewBuilder
    private func composited(_ layer: IconLayer) -> some View {
        switch layer.role {
        case .background(_, let fillHex):
            if let hex = fillHex, let color = Color(hex: hex) { color }
        case .content:
            ForEach(layer.elements) { element in
                elementView(element, transform: layer.transform)
            }
        }
    }

    @ViewBuilder
    private func elementView(_ element: LayerElement, transform t: LayerTransform) -> some View {
        switch element.content {
        case .symbol(let symbol):
            Image(systemName: symbol.systemName)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color(hex: symbol.tintHex) ?? .primary)
                .frame(width: side * t.scale, height: side * t.scale)
                .rotationEffect(.degrees(t.rotationDegrees))
                .position(x: t.center.x * side, y: t.center.y * side)
        case .text(let text):
            Text(text.string)
                .font(.custom(text.fontName, size: side * text.sizeFraction * t.scale))
                .bold(text.bold)
                .italic(text.italic)
                .underline(text.underline)
                .foregroundStyle(Color(hex: text.colorHex) ?? .primary)
                .rotationEffect(.degrees(t.rotationDegrees))
                .position(x: t.center.x * side, y: t.center.y * side)
        case .image(let imageContent):
            if let platformImage = PlatformImage(data: imageContent.pngData) {
                Image(platformImage: platformImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: side * t.scale, height: side * t.scale)
                    .rotationEffect(.degrees(t.rotationDegrees))
                    .position(x: t.center.x * side, y: t.center.y * side)
            }
        case .pixels(let pixels):
            if let platformImage = PlatformImage(data: pixels.pngData) {
                Image(platformImage: platformImage)
                    .interpolation(.none)   // crisp blocks when a low-res layer scales up
                    .resizable()
                    .frame(width: side, height: side)
            }
        }
    }
}

/// CGImage -> PNG bytes, cross-platform via ImageIO (no UIKit/AppKit needed).
func pngData(from cgImage: CGImage) -> Data? {
    let data = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
        return nil
    }
    CGImageDestinationAddImage(dest, cgImage, nil)
    guard CGImageDestinationFinalize(dest) else { return nil }
    return data as Data
}

/// Re-encode any imported image data (PNG/JPEG/HEIC/…) to PNG bytes (model rule:
/// PNG only — alpha + lossless, never JPG).
func pngData(fromImageData data: Data) -> Data? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
    return pngData(from: cg)
}

/// Cross-platform image type + a SwiftUI Image bridge, for rendering imported PNGs.
#if canImport(UIKit)
typealias PlatformImage = UIImage
extension Image { init(platformImage: UIImage) { self.init(uiImage: platformImage) } }
#elseif canImport(AppKit)
typealias PlatformImage = NSImage
extension Image { init(platformImage: NSImage) { self.init(nsImage: platformImage) } }
#endif

/// Export deliverable (roadmap 2.3): a FOLDER of named PNG sizes, no Contents.json.
/// Write-only; the user drags the PNGs into Xcode's AppIcon wells themselves.
struct IconExportBundle: FileDocument {
    static var readableContentTypes: [UTType] { [.folder] }
    static var writableContentTypes: [UTType] { [.folder] }

    var files: [String: Data]

    init(files: [String: Data]) { self.files = files }

    init(configuration: ReadConfiguration) throws { files = [:] } // export-only

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        var wrappers: [String: FileWrapper] = [:]
        for (name, data) in files {
            let wrapper = FileWrapper(regularFileWithContents: data)
            wrapper.preferredFilename = name
            wrappers[name] = wrapper
        }
        return FileWrapper(directoryWithFileWrappers: wrappers)
    }
}

#if canImport(UIKit)
/// Hosts the system share sheet (roadmap 2.5) for the rendered PNG file URL.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif

#Preview {
    ContentView(document: .newDefault())
}
