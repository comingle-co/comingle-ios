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

    @EnvironmentObject var appState: AppState

    var body: some View {
        if appState.appSettings?.activeProfile?.publicKeyHex == nil {
            LoginView()
                .environmentObject(appState)
        } else {
            CalendarEventListView(calendarEventListType: .followed)
                .navigationTitle(.localizable.yourNetwork)
                .environmentObject(appState)
        }
    }
}

struct HomeView_Previews: PreviewProvider {

    @State static var appState = AppState()

    static var previews: some View {
        HomeView()
            .environmentObject(appState)
    }
}
