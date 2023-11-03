//
//  ConfstrApp.swift
//  Confstr
//
//  Created by Terry Yiu on 5/9/23.
//

import SwiftUI

@main
struct ConfstrApp: App {
    private let appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
        }
    }
}
