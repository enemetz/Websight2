//
//  Websight_2App.swift
//  Websight-2
//
//  Created by Evan Nemetz on 2/27/26.
//

import SwiftUI
import SwiftData

@main
struct Websight_2App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }.modelContainer(for: History.self)
    }
}
