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
        } else {
            EventListView(eventListType: .followed)
                .navigationTitle(.localizable.yourNetwork)
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
