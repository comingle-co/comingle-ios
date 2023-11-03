//
//  LoggedInView.swift
//  Confstr
//
//  Created by Terry Yiu on 6/18/23.
//

import SwiftUI

struct LoggedInView: View {

    @ObservedObject var appState: AppState

    var body: some View {
        NavigationStack {
            ConferencesView(appState: appState, conferences: ConferencesView_Previews.conferences)
                .navigationTitle("Conferences")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink(destination: SettingsView(appState: appState)) {
                            Image(systemName: "gear")
                        }
                    }
                }
        }
        .task {
        }
    }
}

struct LoggedInView_Previews: PreviewProvider {
    static var appState = AppState()

    static var previews: some View {
        LoggedInView(appState: appState)
    }
}
