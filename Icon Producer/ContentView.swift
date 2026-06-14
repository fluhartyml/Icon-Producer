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
            HStack(spacing: 4) {
                ForEach(Tool.allCases) { tool in
                    Button { activeTool = tool } label: {
                        Image(systemName: tool.systemImage)
                            .font(.system(size: 18))
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
            VStack(spacing: 4) {
                ForEach(Tool.allCases) { tool in
                    Button { activeTool = tool } label: {
                        Image(systemName: tool.systemImage)
                            .font(.system(size: 18))
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
        }
        .frame(width: 56)
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
            ColorPicker("Fill colour", selection: $fillColor, supportsOpacity: false)

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
                    Slider(value: transformBinding(\.scale, idx), in: 0.1...1.0)
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

    private var activeIndex: Int? {
        guard let id = activeLayerID else { return nil }
        return document.layers.firstIndex(where: { $0.id == id })
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
                ForEach(document.layers) { layer in
                    if layer.isVisible {
                        layerContent(layer, side: side)
                    }
                }
                if showTransformBox, let idx = activeIndex {
                    TransformBox(document: document, index: idx, side: side)
                }
            }
            .frame(width: side, height: side)
            .coordinateSpace(name: "canvas")
            .overlay(Rectangle().stroke(Color.secondary.opacity(0.4), lineWidth: 1))
            .contentShape(Rectangle())
            .onTapGesture { pourIfFilling() }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // center in the area
        }
    }

    /// What a layer draws on the canvas. A filled background renders its colour;
    /// a content layer renders its elements at the layer's transform. (Most
    /// element kinds wait for their tools; `symbol` renders now so the TEST-ONLY
    /// shakedown star is visible for the Move/Transform tool.)
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
        default:
            EmptyView() // pixels / image / text render once their tools exist
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

    var body: some View {
        let t = document.layers[index].transform
        let boxSide = max(24, t.scale * side)
        return Rectangle()
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            .background(Color.accentColor.opacity(0.06))
            .frame(width: boxSide, height: boxSide)
            .rotationEffect(.degrees(t.rotationDegrees))
            .position(x: t.center.x * side, y: t.center.y * side)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("canvas"))
                    .onChanged { value in
                        let start = startCenter ?? document.layers[index].transform.center
                        if startCenter == nil { startCenter = start }
                        let nx = min(max(start.x + value.translation.width / side, 0), 1)
                        let ny = min(max(start.y + value.translation.height / side, 0), 1)
                        document.layers[index].transform.center = CGPoint(x: nx, y: ny)
                    }
                    .onEnded { _ in startCenter = nil }
            )
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
            if showsHeader {
                Text("Layers")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                Divider()
            }
            List {
                ForEach(Array(document.layers.reversed())) { layer in
                    LayerRow(
                        layer: layer,
                        isActive: layer.id == activeLayerID,
                        onActivate: { activeLayerID = layer.id },
                        onToggleVisibility: { toggleVisibility(layer.id) },
                        onRename: { beginRename(layer) }
                    )
                    .listRowBackground(layer.id == activeLayerID
                                       ? Color.accentColor.opacity(0.15) : nil)
                }
                .onMove(perform: move)
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(.active)) // always-on reorder handles
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
            Button(action: onRename) {
                Label("Rename", systemImage: "pencil")
            }
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
}

#Preview {
    ContentView(document: .newDefault())
}
