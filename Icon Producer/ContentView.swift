//
//  ContentView.swift
//  Icon Producer
//
//  Created by Michael Fluharty on 6/9/26.
//
//  Editor SHELL: a square canvas + the layer list, driven by the IconDocument
//  model. No tools/inspectors/persistence yet. A brand-new icon opens with three
//  BLANK layers (Light Background, Dark Background, Icon), so the canvas shows the
//  transparency checkerboard until the user fills/draws.
//
//  LAYOUT (Michael 2026-06-11): adapts to orientation by geometry, not size class
//  (iPhone landscape still reports "compact" width, so size class would miss it).
//   • PORTRAIT (taller than wide — the common iPhone case): canvas = TOP half,
//     layers = BOTTOM half. The canvas gets the full width instead of being
//     squished into a side column.
//   • LANDSCAPE / WIDE (Mac, iPad): the original side-by-side, left as-is.
//
//  LAYER ROWS (Michael 2026-06-11): no "blank" label (the badge already shows an
//  empty layer). Names are renamable (context-menu → Rename). Layers are moveable
//  (drag to reorder). The eyeball (visibility) and a grab bar (the reorder handle)
//  sit on the trailing edge where "blank" used to be.
//

import SwiftUI

struct ContentView: View {
    @State private var document = IconDocument.newDefault()

    var body: some View {
        GeometryReader { geo in
            if geo.size.height > geo.size.width {
                // Portrait: canvas top half, layers bottom half.
                VStack(spacing: 0) {
                    canvasArea
                        .frame(height: geo.size.height / 2)
                    Divider()
                    LayerPanel(document: document)
                        .frame(height: geo.size.height / 2)
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
/// via the row's context menu so it never fights the drag handle.
struct LayerPanel: View {
    let document: IconDocument
    @State private var renamingID: IconLayer.ID?
    @State private var draftName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Layers")
                .font(.headline)
                .padding(.horizontal)
                .padding(.vertical, 10)
            Divider()
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
