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

struct ContentView: View {
    @State private var document = IconDocument.newDefault()
    @State private var activeTool: Tool = .move
    @State private var activeLayerID: IconLayer.ID?
    @State private var bottomPanel: BottomPanel = .layers

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
                                          selection: $bottomPanel)
                }
            } else {
                // Landscape / wide (Mac, iPad): original side-by-side, unchanged.
                HStack(spacing: 0) {
                    canvasArea
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Divider()
                    LayerPanel(document: document, activeLayerID: $activeLayerID)
                        .frame(width: 280)
                }
            }
        }
    }

    private var canvasArea: some View {
        CanvasView(document: document,
                   activeLayerID: activeLayerID,
                   showTransformBox: activeTool == .move)
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

// MARK: - Bottom swipe panel

/// The three lower-frequency surfaces under the tool strip. A segmented control
/// picks one; on iOS you can also swipe between them.
enum BottomPanel: String, CaseIterable, Identifiable {
    case tool = "Tool"
    case layers = "Layers"
    case history = "History"

    var id: String { rawValue }

    struct PanelView: View {
        let document: IconDocument
        let activeTool: Tool
        @Binding var activeLayerID: IconLayer.ID?
        @Binding var selection: BottomPanel

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

        @ViewBuilder
        private var toolPage: some View {
            if activeTool == .move {
                MoveTransformInspector(document: document, activeLayerID: activeLayerID)
            } else {
                ToolInspectorPlaceholder(tool: activeTool)
            }
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
            Text(tool.title)
                .font(.headline)
            Text("Tool inspector — coming soon")
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
    let document: IconDocument
    let activeLayerID: IconLayer.ID?

    private var index: Int? {
        guard let id = activeLayerID else { return nil }
        return document.layers.firstIndex(where: { $0.id == id })
    }

    var body: some View {
        if let idx = index {
            VStack(alignment: .leading, spacing: 18) {
                Text(document.layers[idx].name).font(.headline)

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
    let document: IconDocument
    var activeLayerID: IconLayer.ID? = nil
    var showTransformBox: Bool = false

    private var activeIndex: Int? {
        guard let id = activeLayerID else { return nil }
        return document.layers.firstIndex(where: { $0.id == id })
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                Checkerboard()
                ForEach(document.layers) { layer in
                    if layer.isVisible {
                        layerContent(layer)
                    }
                }
                if showTransformBox, let idx = activeIndex {
                    transformBox(side: side, index: idx)
                }
            }
            .frame(width: side, height: side)
            .coordinateSpace(name: "canvas")
            .overlay(Rectangle().stroke(Color.secondary.opacity(0.4), lineWidth: 1))
            .frame(maxWidth: .infinity, maxHeight: .infinity) // center in the area
        }
    }

    /// What a layer draws on the canvas. For this shell, only a filled background
    /// renders a colour; content layers (and their elements) are blank for now.
    @ViewBuilder
    private func layerContent(_ layer: IconLayer) -> some View {
        switch layer.role {
        case .background(_, let fillHex):
            if let hex = fillHex, let color = Color(hex: hex) {
                color
            }
        case .content:
            EmptyView() // composite elements in a later increment
        }
    }

    /// The draggable transform box for the active layer (Move tool). Reflects the
    /// layer's transform (center / scale / rotation); dragging updates the center.
    private func transformBox(side: CGFloat, index idx: Int) -> some View {
        let t = document.layers[idx].transform
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
                        let nx = min(max(value.location.x / side, 0), 1)
                        let ny = min(max(value.location.y / side, 0), 1)
                        document.layers[idx].transform.center = CGPoint(x: nx, y: ny)
                    }
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
    let document: IconDocument
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
}

#Preview {
    ContentView()
}
