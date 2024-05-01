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
            CalendarsView()
                .navigationTitle(.localizable.calendars)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gear")
                        }
                    }
                }
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
