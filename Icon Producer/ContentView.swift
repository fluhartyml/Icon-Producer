//
//  ContentView.swift
//  Icon Producer
//
//  Created by Michael Fluharty on 6/9/26.
//
//  Editor SHELL. A brand-new icon opens with three BLANK layers (Light
//  Background, Dark Background, Icon), so the canvas shows the transparency
//  checkerboard until the user fills/draws. No tool BEHAVIOUR yet — tools select
//  and show a placeholder inspector.
//
//  LAYOUT (Michael 2026-06-11): adapts by geometry, not size class (iPhone
//  landscape is still "compact" width). See the DeveloperNotes "UI LAYOUT".
//   • PORTRAIT (taller than wide — iPhone AND iPad portrait):
//        canvas (top half)
//        TOOL STRIP   — always visible, horizontally scrollable (overflow)
//        SWIPE PANEL  — segmented + swipe between Tool / Layers / History
//   • LANDSCAPE / WIDE (Mac, iPad/iPhone landscape): the original side-by-side
//        canvas + layers, left as-is. (The wide arrangement that shows tools +
//        inspector + layers all at once is a later increment.)
//

import SwiftUI

struct ContentView: View {
    @State private var document = IconDocument.newDefault()
    @State private var activeTool: Tool = .move
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
                    Divider()
                    BottomPanel.PanelView(document: document,
                                          activeTool: activeTool,
                                          selection: $bottomPanel)
                }
            } else {
                // Landscape / wide (Mac, iPad): original side-by-side, unchanged.
                HStack(spacing: 0) {
                    canvasArea
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Divider()
                    LayerPanel(document: document)
                        .frame(width: 280)
                }
            }
        }
    }

    private var canvasArea: some View {
        CanvasView(document: document)
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
                    .help(tool.title)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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
        let document: IconDocument
        let activeTool: Tool
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

        private var toolPage: some View {
            ToolInspectorPlaceholder(tool: activeTool)
        }

        private var layersPage: some View {
            LayerPanel(document: document, showsHeader: false)
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

// MARK: - Canvas

/// The square artboard. Composites the visible layers bottom-to-top over a
/// transparency checkerboard. (Blank layers render nothing -> checkerboard shows.)
struct CanvasView: View {
    let document: IconDocument

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
            }
            .frame(width: side, height: side)
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
/// display is reversed). Each row: kind badge + editable name + (eyeball / grab
/// bar) on the trailing edge. Reorder is always-on (edit mode active); rename is
/// via the row's context menu so it never fights the drag handle. `showsHeader`
/// is false inside the portrait swipe panel (the segmented control already
/// labels it "Layers").
struct LayerPanel: View {
    let document: IconDocument
    var showsHeader: Bool = true
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
                        onToggleVisibility: { toggleVisibility(layer.id) },
                        onRename: { beginRename(layer) }
                    )
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
    let onToggleVisibility: () -> Void
    let onRename: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: layer.displaySymbolName)
                .frame(width: 18)
                .foregroundStyle(.secondary)

            Text(layer.name)
                .foregroundStyle(layer.isVisible ? Color.primary : Color.secondary)

            Spacer()

            Button(action: onToggleVisibility) {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    .foregroundStyle(layer.isVisible ? Color.primary : Color.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
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
