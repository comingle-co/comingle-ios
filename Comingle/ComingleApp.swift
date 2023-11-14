//
//  ComingleApp.swift
//  Comingle
//
//  Created by Terry Yiu on 5/9/23.
//

import SwiftUI

@main
struct ComingleApp: App {
    private let appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
        }
    }
}
