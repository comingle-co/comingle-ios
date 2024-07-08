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

    @EnvironmentObject private var appState: AppState

    var body: some View {
        if appState.appSettings?.activeProfile?.publicKeyHex == nil {
            LoginView()
                .environmentObject(appState)
        } else {
            CalendarEventListView(showAllEvents: false)
                .environmentObject(appState)
                .navigationTitle(.localizable.yourNetwork)
        }
    }
}

struct HomeView_Previews: PreviewProvider {

    static var previews: some View {
        HomeView()
    }
}
