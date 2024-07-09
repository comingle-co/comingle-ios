//
//  MyProfileView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/7/24.
//

import Kingfisher
import NostrSDK
import SwiftUI

struct MyProfileView: View {

    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack {
            if let publicKeyHex = appState.publicKey?.hex {
                ProfileSmallView(publicKeyHex: publicKeyHex)
                CalendarEventListView(calendarEventListType: .profile)
            } else {
                LoginView()
            }
        }
    }
}

struct MyProfileView_Previews: PreviewProvider {

    @State static var appState = AppState()

    static var previews: some View {
        MyProfileView()
            .environmentObject(appState)
    }
}
