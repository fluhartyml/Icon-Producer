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
        }
    }
}
