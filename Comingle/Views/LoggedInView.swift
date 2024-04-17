//
//  LoggedInView.swift
//  Comingle
//
//  Created by Terry Yiu on 6/18/23.
//

import SwiftUI

struct LoggedInView: View {

    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            ConferencesView(conferences: ConferencesView_Previews.conferences)
                .navigationTitle(.localizable.conferences)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink(destination: SettingsView()) {
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
        LoggedInView()
            .environmentObject(appState)
    }
}
