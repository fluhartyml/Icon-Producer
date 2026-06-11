//
//  ContentView.swift
//  Icon Producer
//
//  Created by Michael Fluharty on 6/9/26.
//
//  Editor SHELL increment: a square canvas + the layer list, driven by the
//  IconDocument model. No tools/inspectors/persistence yet — this just renders
//  the layer stack so there is something real on screen. A brand-new icon opens
//  with three BLANK layers (Light Background, Dark Background, Icon), so the
//  canvas shows the transparency checkerboard until the user fills/draws.
//

import SwiftUI

struct ContentView: View {
    @State private var document = IconDocument.newDefault()
    @State private var selectedLayerID: IconLayer.ID?

    var body: some View {
        HStack(spacing: 0) {
            CanvasView(document: document)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .background(Color(white: 0.5).opacity(0.12))

            Divider()

            LayerPanel(document: document, selectedLayerID: $selectedLayerID)
                .frame(width: 280)
        }
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
/// display is reversed). Each row: eyeball (visibility) + kind badge + name.
struct LayerPanel: View {
    let document: IconDocument
    @Binding var selectedLayerID: IconLayer.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Layers")
                .font(.headline)
                .padding(.horizontal)
                .padding(.vertical, 10)
            Divider()
            List(selection: $selectedLayerID) {
                ForEach(Array(document.layers.reversed())) { layer in
                    LayerRow(layer: layer) { toggleVisibility(layer.id) }
                        .tag(layer.id)
                }
            }
            .listStyle(.plain)
        }
    }

    private func toggleVisibility(_ id: IconLayer.ID) {
        if let index = document.layers.firstIndex(where: { $0.id == id }) {
            document.layers[index].isVisible.toggle()
        }
    }
}

struct LayerRow: View {
    let layer: IconLayer
    let onToggleVisibility: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggleVisibility) {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    .foregroundStyle(layer.isVisible ? Color.primary : Color.secondary)
            }
            .buttonStyle(.plain)

            Image(systemName: layer.displaySymbolName)
                .frame(width: 18)
                .foregroundStyle(.secondary)

            Text(layer.name)
                .foregroundStyle(layer.isVisible ? Color.primary : Color.secondary)

            Spacer()

            if layer.isBlank {
                Text("blank")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
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
