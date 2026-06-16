//
//  Icon_ProducerApp.swift
//  Icon Producer
//
//  Created by Michael Fluharty on 6/9/26.
//

import SwiftUI

@main
struct Icon_ProducerApp: App {
    var body: some Scene {
        // Document-based (roadmap 2.4.1): each icon is a saved package the user owns
        // in iCloud Drive / Files. New documents open with three blank layers.
        DocumentGroup(newDocument: { IconDocument.newDefault() }) { configuration in
            ContentView(document: configuration.document)
                // Self-driven autosave — the app has no UndoManager (undo/redo is the
                // future History system's job), so SwiftUI's undo-based autosave never
                // fires. This writes the package directly as edits settle.
                .autosave(document: configuration.document,
                          fileURL: configuration.fileURL,
                          isEditable: configuration.isEditable)
        }
    }
}
