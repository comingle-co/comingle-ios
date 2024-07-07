//
//  HomeView.swift
//  Comingle
//
//  Created by Terry Yiu on 6/22/24.
//

import Kingfisher
import NostrSDK
import SwiftUI

struct HomeView: View {

    @Binding var appSettings: AppSettings

    @EnvironmentObject private var appState: AppState

    var body: some View {
        switch appState.loginMode {
        case .none:
            LoginView(appSettings: $appSettings)
                .environmentObject(appState)
        default:
            CalendarEventListView(showAllEvents: false)
                .environmentObject(appState)
                .navigationTitle(.localizable.yourNetwork)
        }
    }
}

struct HomeView_Previews: PreviewProvider {

    @State static var appSettings = AppSettings()

    static var previews: some View {
        HomeView(appSettings: $appSettings)
    }
}
